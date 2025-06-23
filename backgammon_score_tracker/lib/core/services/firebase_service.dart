import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı işlemleri
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        try {
          // Ensure user document exists
          await createUserDocument(userCredential.user!);
        } catch (e) {
          debugPrint('Error creating user document: $e');
          // Continue even if document creation fails
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = ErrorService.authUserNotFound;
          break;
        case 'wrong-password':
          errorMessage = ErrorService.authWrongPassword;
          break;
        case 'invalid-email':
          errorMessage = ErrorService.authInvalidEmail;
          break;
        case 'user-disabled':
          errorMessage = ErrorService.authUserDisabled;
          break;
        case 'too-many-requests':
          errorMessage = ErrorService.authTooManyRequests;
          break;
        case 'network-request-failed':
          errorMessage = ErrorService.authNetworkRequestFailed;
          break;
        case 'operation-not-allowed':
          errorMessage = ErrorService.authOperationNotAllowed;
          break;
        default:
          errorMessage = ErrorService.authFailed;
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('Sign in error: $e');
      throw Exception(ErrorService.generalError);
    }
  }

  Future<void> createUserDocument(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
          'themeMode': 'system',
        });
        debugPrint('User document created for ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error creating user document: $e');
      throw Exception(ErrorService.firestorePermissionDenied);
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      debugPrint('Creating user...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('User created: ${userCredential.user?.uid}');

      if (userCredential.user == null) {
        throw Exception(ErrorService.authFailed);
      }

      debugPrint('Sending email verification...');
      await userCredential.user!.sendEmailVerification();
      debugPrint('Email verification sent');

      debugPrint('Creating user document...');
      await createUserDocument(userCredential.user!);
      debugPrint('User document created');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = ErrorService.authEmailAlreadyInUse;
          break;
        case 'invalid-email':
          errorMessage = ErrorService.authInvalidEmail;
          break;
        case 'operation-not-allowed':
          errorMessage = ErrorService.authOperationNotAllowed;
          break;
        case 'weak-password':
          errorMessage = ErrorService.authWeakPassword;
          break;
        default:
          errorMessage = ErrorService.authFailed;
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('General Error: $e');
      throw Exception(ErrorService.generalError);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception(ErrorService.generalError);
    }
  }

  // Oyun işlemleri
  Future<void> _ensureUserDocument(String userId, String email) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userId).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': false,
          'themeMode': 'system',
        });
      }
    } catch (e) {
      debugPrint('Error ensuring user document: $e');
      throw Exception(ErrorService.firestorePermissionDenied);
    }
  }

  Future<void> savePlayer(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Ensure user document exists
      await _ensureUserDocument(user.uid, user.email ?? '');

      // Create player document
      await _firestore.collection('players').add({
        'name': name,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = ErrorService.firestorePermissionDenied;
          break;
        case 'unavailable':
          errorMessage = ErrorService.firestoreUnavailable;
          break;
        default:
          errorMessage = ErrorService.generalError;
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(ErrorService.generalError);
    }
  }

  Future<void> saveGame({
    required String player1,
    required String player2,
    required int player1Score,
    required int player2Score,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Ensure user document exists
      await _ensureUserDocument(user.uid, user.email ?? '');

      await _firestore.collection('games').add({
        'player1': player1,
        'player2': player2,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = ErrorService.firestorePermissionDenied;
          break;
        case 'unavailable':
          errorMessage = ErrorService.firestoreUnavailable;
          break;
        default:
          errorMessage = ErrorService.gameSaveFailed;
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(ErrorService.generalError);
    }
  }

  Stream<QuerySnapshot> getGames() {
    try {
      return _firestore
          .collection('games')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      throw Exception('Oyunlar getirilirken bir hata oluştu: $e');
    }
  }

  // İstatistik işlemleri
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final games = await _firestore
          .collection('games')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .get();

      int totalGames = games.docs.length;
      int wins = 0;
      Map<String, int> opponentGames = {};
      int highestScore = 0;

      for (var doc in games.docs) {
        final data = doc.data();
        final player1Score = data['player1Score'] as int;
        final player2Score = data['player2Score'] as int;
        final player1 = data['player1'] as String;
        final player2 = data['player2'] as String;

        // Kazanma sayısını hesapla
        if (player1Score > player2Score) {
          wins++;
        }

        // Rakip oyun sayılarını hesapla
        opponentGames[player2] = (opponentGames[player2] ?? 0) + 1;

        // En yüksek skoru güncelle
        final gameScore = player1Score + player2Score;
        if (gameScore > highestScore) {
          highestScore = gameScore;
        }
      }

      // En çok oynanan rakibi bul
      String mostPlayedOpponent = '';
      int maxGames = 0;
      opponentGames.forEach((opponent, games) {
        if (games > maxGames) {
          maxGames = games;
          mostPlayedOpponent = opponent;
        }
      });

      return {
        'totalGames': totalGames,
        'winRate':
            totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0',
        'mostPlayedOpponent': mostPlayedOpponent,
        'highestScore': highestScore,
      };
    } catch (e) {
      throw Exception('İstatistikler getirilirken bir hata oluştu: $e');
    }
  }
}
