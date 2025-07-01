import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_messaging_service.dart';
import 'package:backgammon_score_tracker/core/services/guest_data_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final NotificationService _notificationService = NotificationService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final GuestDataService _guestDataService = GuestDataService();
  final LogService _logService = LogService();

  // Kullanıcı işlemleri
  Future<UserCredential> signIn(String email, String password) async {
    try {
      _logService.info('Kullanıcı girişi başlatıldı: $email', tag: 'Auth');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        try {
          // Ensure user document exists
          await createUserDocument(userCredential.user!);
          _logService.info(
              'Kullanıcı girişi başarılı: ${userCredential.user!.uid}',
              tag: 'Auth');
        } catch (e) {
          _logService.warning('Kullanıcı dokümanı oluşturulamadı: $e',
              tag: 'Auth');
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
      _logService.error('Kullanıcı girişi başarısız: ${e.code}',
          tag: 'Auth', error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('Beklenmeyen giriş hatası', tag: 'Auth', error: e);
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
          // Bildirim tercihleri - sadece sosyal bildirimler aktif
          'notificationEnabled': true,
          'newGameNotifications': false,
          'statisticsNotifications': false,
          'reminderNotifications': false,
          'socialNotifications': true,
        });

        // Bildirim servislerini başlat
        await _initializeNotificationServices();
      }
    } catch (e) {
      throw Exception(ErrorService.firestorePermissionDenied);
    }
  }

  Future<void> _initializeNotificationServices() async {
    try {
      await _notificationService.initialize();
      await _messagingService.initialize();
      await _notificationService.createNotificationChannels();
    } catch (e) {
      // Bildirim servisleri başarısız olsa bile uygulama çalışmaya devam etsin
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception(ErrorService.authFailed);
      }

      await userCredential.user!.sendEmailVerification();

      await createUserDocument(userCredential.user!);

      return userCredential;
    } on FirebaseAuthException catch (e) {
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
      throw Exception(ErrorService.generalError);
    }
  }

  Future<void> signOut() async {
    try {
      _logService.info('Signing out user', tag: 'Auth');
      await _googleSignIn.signOut();
      await _auth.signOut();
      _logService.info('Sign out successful', tag: 'Auth');
    } catch (e) {
      _logService.error('Sign out failed: $e', tag: 'Auth', error: e);
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
          // Bildirim tercihleri - sadece sosyal bildirimler aktif
          'notificationEnabled': true,
          'newGameNotifications': false,
          'statisticsNotifications': false,
          'reminderNotifications': false,
          'socialNotifications': true,
        });
      }
    } catch (e) {
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
        _logService.error('Oyun kaydedilemedi: Kullanıcı oturumu yok',
            tag: 'Game');
        throw Exception(ErrorService.authUserNotFound);
      }

      _logService.info(
          'Oyun kaydediliyor: $player1 vs $player2 ($player1Score-$player2Score)',
          tag: 'Game');

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

      _logService.info('Oyun başarıyla kaydedildi', tag: 'Game');
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
      _logService.error('Oyun kaydetme hatası: ${e.code}',
          tag: 'Game', error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('Beklenmeyen oyun kaydetme hatası',
          tag: 'Game', error: e);
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

  // Bildirim işlemleri
  Future<List<NotificationModel>> getNotifications() async {
    return await _messagingService.getNotifications();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _messagingService.markNotificationAsRead(notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _messagingService.deleteNotification(notificationId);
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    return await _messagingService.getNotificationPreferences();
  }

  Future<void> updateNotificationPreferences(
      NotificationPreferences preferences) async {
    await _messagingService.updateNotificationPreferences(preferences);
  }

  // Sadece sosyal bildirimler
  Future<void> sendSocialNotification() async {
    try {
      final preferences = await _messagingService.getNotificationPreferences();
      if (!preferences.enabled || !preferences.socialNotifications) {
        return;
      }

      // Sosyal bildirimler - uygulama ile ilgili hatırlatıcı ve bilgilendirici
      final socialMessages = [
        {
          'title': 'Tavla Zamanı! 🎲',
          'body': 'Arkadaşlarınızla yeni bir maç yapmaya ne dersiniz?',
        },
        {
          'title': 'İstatistiklerinizi Görün 📊',
          'body':
              'Bu haftaki performansınızı kontrol etmek için istatistiklerinize göz atın.',
        },
        {
          'title': 'Yeni Oyuncu Ekleyin 👥',
          'body':
              'Daha fazla arkadaşınızı ekleyerek daha eğlenceli maçlar yapabilirsiniz.',
        },
        {
          'title': 'Uzun Zamandır Oynamıyorsunuz ⏰',
          'body':
              'Son maçınızdan bu yana uzun zaman geçti. Yeni bir maç yapmaya ne dersiniz?',
        },
        {
          'title': 'Başarılarınızı Paylaşın 🏆',
          'body':
              'Yeni rekorlarınızı ve başarılarınızı arkadaşlarınızla paylaşın.',
        },
      ];

      // Rastgele bir sosyal mesaj seç
      final randomMessage =
          socialMessages[DateTime.now().millisecond % socialMessages.length];

      await _notificationService.showNotification(
        title: randomMessage['title']!,
        body: randomMessage['body']!,
        type: NotificationType.social,
      );

      // Firestore'a bildirim kaydet
      await _firestore.collection('notifications').add({
        'userId': _auth.currentUser?.uid,
        'title': randomMessage['title']!,
        'body': randomMessage['body']!,
        'type': NotificationType.social.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'messageType': 'social',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      _logService.info('Sosyal bildirim gönderildi: ${randomMessage['title']}',
          tag: 'Notification');
    } catch (e) {
      _logService.error('Sosyal bildirim gönderilemedi',
          tag: 'Notification', error: e);
    }
  }

  // Sosyal bildirimleri manuel olarak tetikle
  Future<void> triggerSocialNotification() async {
    await sendSocialNotification();
  }

  // Misafir kullanıcı girişi
  Future<UserCredential> signInAnonymously() async {
    try {
      _logService.info('Misafir kullanıcı girişi başlatıldı', tag: 'Auth');

      // Firebase Auth durumunu kontrol et
      final currentUser = _auth.currentUser;
      _logService.info('Mevcut kullanıcı: ${currentUser?.uid ?? 'Yok'}',
          tag: 'Auth');

      final userCredential = await _auth.signInAnonymously();

      _logService.info('Firebase Auth yanıtı alındı', tag: 'Auth');

      if (userCredential.user != null) {
        _logService.info('Kullanıcı oluşturuldu: ${userCredential.user!.uid}',
            tag: 'Auth');

        try {
          // Misafir kullanıcı dokümanı oluştur
          await createGuestUserDocument(userCredential.user!);
          _logService.info(
              'Misafir kullanıcı girişi başarılı: ${userCredential.user!.uid}',
              tag: 'Auth');
        } catch (e) {
          _logService.warning('Misafir kullanıcı dokümanı oluşturulamadı: $e',
              tag: 'Auth');
          // Devam et, doküman oluşturulamasa bile
        }
      } else {
        _logService.error('Kullanıcı oluşturulamadı', tag: 'Auth');
        throw Exception('Kullanıcı oluşturulamadı');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'operation-not-allowed':
          errorMessage =
              'Misafir kullanıcı girişi etkinleştirilmemiş. Firebase Console\'da Anonymous Authentication\'ı etkinleştirin.';
          break;
        case 'network-request-failed':
          errorMessage = ErrorService.authNetworkRequestFailed;
          break;
        case 'too-many-requests':
          errorMessage = ErrorService.authTooManyRequests;
          break;
        default:
          errorMessage =
              'Misafir kullanıcı girişi başarısız: ${e.code} - ${e.message}';
      }
      _logService.error(
          'Misafir kullanıcı girişi başarısız: ${e.code} - ${e.message}',
          tag: 'Auth',
          error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('Beklenmeyen misafir giriş hatası',
          tag: 'Auth', error: e);
      throw Exception('Beklenmeyen hata: $e');
    }
  }

  // Misafir kullanıcı dokümanı oluştur
  Future<void> createGuestUserDocument(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'isGuest': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': false,
          'themeMode': 'system',
          // Bildirim tercihleri - misafir kullanıcılar için kapalı
          'notificationEnabled': false,
          'newGameNotifications': false,
          'statisticsNotifications': false,
          'reminderNotifications': false,
          'socialNotifications': false,
        });
      }
    } catch (e) {
      throw Exception(ErrorService.firestorePermissionDenied);
    }
  }

  // Kullanıcının misafir olup olmadığını kontrol et
  bool isGuestUser(User? user) {
    return user?.isAnonymous ?? false;
  }

  // Kullanıcının misafir olup olmadığını kontrol et (mevcut kullanıcı için)
  bool isCurrentUserGuest() {
    final user = _auth.currentUser;
    return isGuestUser(user);
  }

  // Google Sign-In methods
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _logService.info('Attempting Google sign in', tag: 'Auth');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _logService.info('Google sign in cancelled by user', tag: 'Auth');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      _logService.info('Google sign in successful: ${userCredential.user?.uid}',
          tag: 'Auth');

      // Create or update user document
      await createOrUpdateUserDocument(userCredential.user!);

      return userCredential;
    } catch (e) {
      _logService.error('Google sign in failed: $e', tag: 'Auth', error: e);
      throw Exception('Google authentication failed: ${e.toString()}');
    }
  }

  // Create or update user document for Google Sign-In
  Future<void> createOrUpdateUserDocument(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        // New user - create document
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
          'isGuest': false,
          'themeMode': 'system',
          'notificationEnabled': true,
          'newGameNotifications': false,
          'statisticsNotifications': false,
          'reminderNotifications': false,
          'socialNotifications': true,
        });

        // Initialize notification services
        await _initializeNotificationServices();

        // Misafir verileri varsa Firebase'e aktar
        await _migrateGuestDataIfExists();
      } else {
        // Existing user - update last login
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
          'isGuest': false,
        });
      }
    } catch (e) {
      throw Exception(ErrorService.firestorePermissionDenied);
    }
  }

  // Misafir verileri varsa Firebase'e aktar
  Future<void> _migrateGuestDataIfExists() async {
    try {
      final hasGuestData = await _guestDataService.hasGuestData();
      final isAlreadyMigrated = await _guestDataService.isGuestDataMigrated();

      if (hasGuestData && !isAlreadyMigrated) {
        _logService.info('Misafir veriler bulundu, Firebase\'e aktarılıyor...',
            tag: 'Auth');
        await _guestDataService.migrateGuestDataToFirebase();
        _logService.info('Misafir veriler başarıyla Firebase\'e aktarıldı',
            tag: 'Auth');
      }
    } catch (e) {
      _logService.error('Misafir veriler aktarılamadı: $e',
          tag: 'Auth', error: e);
      // Misafir veriler aktarılamasa bile uygulama çalışmaya devam etsin
    }
  }
}
