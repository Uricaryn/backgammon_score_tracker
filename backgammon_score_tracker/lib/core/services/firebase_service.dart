import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı işlemleri
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Giriş yapılırken bir hata oluştu: $e');
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      debugPrint('Kullanıcı oluşturuluyor...');
      // Kullanıcı oluştur
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('Kullanıcı oluşturuldu: ${userCredential.user?.uid}');

      if (userCredential.user == null) {
        throw Exception('Kullanıcı oluşturulamadı');
      }

      debugPrint('E-posta doğrulama maili gönderiliyor...');
      // E-posta doğrulama maili gönder
      await userCredential.user!.sendEmailVerification();
      debugPrint('E-posta doğrulama maili gönderildi');

      debugPrint('Firestore\'a kullanıcı bilgileri kaydediliyor...');
      // Kullanıcı bilgilerini Firestore'a kaydet
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isEmailVerified': false,
      });
      debugPrint('Firestore\'a kullanıcı bilgileri kaydedildi');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Hatası: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Bu e-posta adresi zaten kullanımda';
          break;
        case 'invalid-email':
          message = 'Geçersiz e-posta adresi';
          break;
        case 'operation-not-allowed':
          message = 'E-posta/şifre girişi etkin değil';
          break;
        case 'weak-password':
          message = 'Şifre çok zayıf';
          break;
        default:
          message = 'Kayıt olurken bir hata oluştu: ${e.message}';
      }
      throw Exception(message);
    } on FirebaseException catch (e) {
      debugPrint('Firebase Hatası: ${e.code} - ${e.message}');
      throw Exception('Firebase hatası: ${e.message}');
    } catch (e) {
      debugPrint('Genel Hata: $e');
      throw Exception('Kayıt olurken bir hata oluştu: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Çıkış yapılırken bir hata oluştu: $e');
    }
  }

  // Oyun işlemleri
  Future<void> saveGame({
    required String player1,
    required String player2,
    required int player1Score,
    required int player2Score,
  }) async {
    try {
      await _firestore.collection('games').add({
        'player1': player1,
        'player2': player2,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });
    } catch (e) {
      throw Exception('Oyun kaydedilirken bir hata oluştu: $e');
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
