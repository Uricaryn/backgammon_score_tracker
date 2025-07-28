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

          // Hoşgeldin bildirimi göster
          await _showWelcomeNotification(userCredential.user!);
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

      // FCM token'ı kaydet
      final fcmToken = _messagingService.fcmToken;
      if (fcmToken != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'isActive': true,
            'notificationEnabled': true,
            'socialNotifications': true,
          });
          _logService.info('FCM token saved during initialization',
              tag: 'Auth');
        }
      }
    } catch (e) {
      // Bildirim servisleri başarısız olsa bile uygulama çalışmaya devam etsin
      _logService.warning('Notification services initialization failed: $e',
          tag: 'Auth');
    }
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      final currentUser = _auth.currentUser;
      UserCredential userCredential;
      bool wasAnonymous = false;

      _logService.info(
          'SignUp başlatıldı. Mevcut kullanıcı: ${currentUser?.uid ?? 'Yok'}',
          tag: 'Auth');
      _logService.info(
          'Kullanıcı anonymous mu: ${currentUser?.isAnonymous ?? false}',
          tag: 'Auth');

      if (currentUser != null && currentUser.isAnonymous) {
        // Anonymous kullanıcıyı e-posta/şifre ile linkle
        wasAnonymous = true;
        _logService.info(
            'Anonymous kullanıcı tespit edildi, credential ile linkleme yapılacak',
            tag: 'Auth');

        // Önce misafir verisi var mı kontrol et
        final hasGuestData = await _guestDataService.hasGuestData();
        _logService.info('Misafir verisi var mı: $hasGuestData', tag: 'Auth');

        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        userCredential = await currentUser.linkWithCredential(credential);
        _logService.info('Anonymous kullanıcı credential ile linklendi',
            tag: 'Auth');
      } else {
        _logService.info('Yeni kullanıcı oluşturulacak', tag: 'Auth');
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (userCredential.user == null) {
        throw Exception(ErrorService.authFailed);
      }

      _logService.info('Kullanıcı oluşturuldu: ${userCredential.user!.uid}',
          tag: 'Auth');
      _logService.info('wasAnonymous değeri: $wasAnonymous', tag: 'Auth');

      await userCredential.user!.sendEmailVerification();
      await createUserDocument(userCredential.user!);

      // Eğer anonymous kullanıcıdan geçiş yapıldıysa veri aktarımı yap
      if (wasAnonymous) {
        _logService.info(
            'Anonymous kullanıcıdan geçiş tespit edildi, veri aktarımı başlatılıyor...',
            tag: 'Auth');
        await _migrateAnonymousDataToFirebase();
        _logService.info('Veri aktarımı tamamlandı', tag: 'Auth');
      } else {
        _logService.info(
            'Anonymous kullanıcıdan geçiş değil, veri aktarımı yapılmayacak',
            tag: 'Auth');
      }

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
      _logService.error('SignUp FirebaseAuthException: ${e.code}',
          tag: 'Auth', error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('SignUp genel hata', tag: 'Auth', error: e);
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

      // Anonymous kullanıcılar için GuestDataService kullan
      if (user.isAnonymous) {
        await _guestDataService.saveGuestPlayer(name);
        return;
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

      // Anonymous kullanıcılar için GuestDataService kullan
      if (user.isAnonymous) {
        await _guestDataService.saveGuestGame(
          player1: player1,
          player2: player2,
          player1Score: player1Score,
          player2Score: player2Score,
        );
        return;
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
      final user = _auth.currentUser;
      if (user?.isAnonymous == true) {
        // Anonymous kullanıcılar için boş stream döndür
        // Çünkü GuestDataService'den veri çekilecek
        return Stream.empty();
      }

      return _firestore
          .collection('games')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      throw Exception('Oyunlar getirilirken bir hata oluştu: $e');
    }
  }

  Stream<QuerySnapshot> getPlayers() {
    try {
      final user = _auth.currentUser;
      if (user?.isAnonymous == true) {
        // Anonymous kullanıcılar için boş stream döndür
        // Çünkü GuestDataService'den veri çekilecek
        return Stream.empty();
      }

      return _firestore
          .collection('players')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      throw Exception('Oyuncular getirilirken bir hata oluştu: $e');
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

      // Önce Google Sign-In'i temizle ki misafir girişi temiz olsun
      await _googleSignIn.signOut();

      // Firebase Auth durumunu kontrol et
      final currentUser = _auth.currentUser;
      _logService.info('Mevcut kullanıcı: ${currentUser?.uid ?? 'Yok'}',
          tag: 'Auth');

      final userCredential = await _auth.signInAnonymously();

      _logService.info('Firebase Auth yanıtı alındı', tag: 'Auth');

      if (userCredential.user != null) {
        _logService.info('Kullanıcı oluşturuldu: ${userCredential.user!.uid}',
            tag: 'Auth');
        _logService.info(
            'Misafir kullanıcı girişi başarılı: ${userCredential.user!.uid}',
            tag: 'Auth');
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

  // Google ile yeni kullanıcı kaydı
  Future<UserCredential?> signUpWithGoogle() async {
    try {
      _logService.info('Google Sign-Up başlatıldı', tag: 'Auth');
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logService.info('Google sign up cancelled by user', tag: 'Auth');
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Google hesabı ile kayıt başarısız.');
      }
      // Firestore'da kullanıcı dokümanı var mı kontrol et
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await _auth.signOut();
        throw Exception(
            'Bu Google hesabı ile zaten kayıt yapılmış. Lütfen giriş yapın.');
      }
      // Yeni kullanıcı dokümanı oluştur
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
      await _initializeNotificationServices();
      return userCredential;
    } catch (e) {
      _logService.error('Google sign up failed: \\${e}', tag: 'Auth', error: e);
      throw Exception('Google sign up failed: \\${e.toString()}');
    }
  }

  // Google Sign-In methods
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _logService.info('Google Sign-In başlatıldı', tag: 'Auth');
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logService.info('Google sign in cancelled by user', tag: 'Auth');
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final currentUser = _auth.currentUser;
      UserCredential userCredential;
      bool wasAnonymous = false;

      _logService.info('Mevcut kullanıcı: \\${currentUser?.uid ?? 'Yok'}',
          tag: 'Auth');
      _logService.info(
          'Kullanıcı anonymous mu: \\${currentUser?.isAnonymous ?? false}',
          tag: 'Auth');

      if (currentUser != null && currentUser.isAnonymous) {
        // Anonymous kullanıcıyı Google hesabı ile linkle
        wasAnonymous = true;
        _logService.info(
            'Anonymous kullanıcı tespit edildi, Google credential ile linkleme yapılacak',
            tag: 'Auth');
        userCredential = await currentUser.linkWithCredential(credential);
        _logService.info('Anonymous kullanıcı Google credential ile linklendi',
            tag: 'Auth');
      } else {
        _logService.info('Yeni Google kullanıcısı oluşturulacak', tag: 'Auth');
        userCredential = await _auth.signInWithCredential(credential);
      }
      _logService.info(
          'Google sign in successful: \\${userCredential.user?.uid}',
          tag: 'Auth');
      _logService.info('wasAnonymous değeri: \\${wasAnonymous}', tag: 'Auth');

      // Firestore'da kullanıcı dokümanı var mı kontrol et
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception(
            'Bu Google hesabı ile daha önce kayıt yapılmamış. Lütfen önce kayıt olun.');
      }

      // Eğer anonymous kullanıcıdan geçiş yapıldıysa veri aktarımı yap
      if (wasAnonymous) {
        _logService.info(
            'Anonymous kullanıcıdan Google geçişi tespit edildi, veri aktarımı başlatılıyor...',
            tag: 'Auth');
        await _migrateAnonymousDataToFirebase();
        _logService.info('Google veri aktarımı tamamlandı', tag: 'Auth');
      } else {
        _logService.info(
            'Anonymous kullanıcıdan Google geçişi değil, veri aktarımı yapılmayacak',
            tag: 'Auth');
      }

      // Hoşgeldin bildirimi göster
      await _showWelcomeNotification(userCredential.user!);

      return userCredential;
    } catch (e) {
      _logService.error('Google sign in failed: \\${e}', tag: 'Auth', error: e);
      throw Exception('Google authentication failed: \\${e.toString()}');
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

  // Anonymous kullanıcı verilerini Firebase'e aktar
  Future<void> _migrateAnonymousDataToFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logService.error(
            'Veri aktarımı başarısız: Kullanıcı oturumu bulunamadı',
            tag: 'Auth');
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      _logService.info('Veri aktarımı başlatılıyor... Kullanıcı: ${user.uid}',
          tag: 'Auth');

      final hasGuestData = await _guestDataService.hasGuestData();
      final isAlreadyMigrated = await _guestDataService.isGuestDataMigrated();

      _logService.info('Misafir verisi var mı: $hasGuestData', tag: 'Auth');
      _logService.info('Zaten aktarılmış mı: $isAlreadyMigrated', tag: 'Auth');

      if (hasGuestData && !isAlreadyMigrated) {
        _logService.info(
            'Anonymous kullanıcı verileri bulundu, Firebase\'e aktarılıyor...',
            tag: 'Auth');

        // Misafir verilerini getir ve logla
        final guestGames = await _guestDataService.getGuestGames();
        final guestPlayers = await _guestDataService.getGuestPlayers();

        _logService.info('Aktarılacak oyun sayısı: ${guestGames.length}',
            tag: 'Auth');
        _logService.info('Aktarılacak oyuncu sayısı: ${guestPlayers.length}',
            tag: 'Auth');

        await _guestDataService.migrateGuestDataToFirebase();
        _logService.info(
            'Anonymous kullanıcı verileri başarıyla Firebase\'e aktarıldı',
            tag: 'Auth');
      } else {
        if (!hasGuestData) {
          _logService.info('Misafir verisi bulunamadı, aktarım yapılmayacak',
              tag: 'Auth');
        } else if (isAlreadyMigrated) {
          _logService.info(
              'Veriler zaten aktarılmış, tekrar aktarım yapılmayacak',
              tag: 'Auth');
        }
      }
    } catch (e) {
      _logService.error('Anonymous kullanıcı verileri aktarılamadı: $e',
          tag: 'Auth', error: e);
      // Veriler aktarılamasa bile uygulama çalışmaya devam etsin
      // Ancak hatayı fırlat ki kullanıcı bilgilendirilebilsin
      throw Exception('Veri aktarımı başarısız: $e');
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

  // Kullanıcı hesabını ve tüm verilerini sil
  Future<void> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      _logService.info('Kullanıcı hesabı silme işlemi başlatıldı: ${user.uid}',
          tag: 'Auth');

      // 1. Kullanıcıya bağlı tüm oyunları sil
      _logService.info('Kullanıcı oyunları siliniyor...', tag: 'Auth');
      final gamesQuery = await _firestore
          .collection('games')
          .where('userId', isEqualTo: user.uid)
          .get();

      final gamesBatch = _firestore.batch();
      for (final doc in gamesQuery.docs) {
        gamesBatch.delete(doc.reference);
      }
      await gamesBatch.commit();
      _logService.info('${gamesQuery.docs.length} oyun silindi', tag: 'Auth');

      // 2. Kullanıcıya bağlı tüm oyuncuları sil
      _logService.info('Kullanıcı oyuncuları siliniyor...', tag: 'Auth');
      final playersQuery = await _firestore
          .collection('players')
          .where('userId', isEqualTo: user.uid)
          .get();

      final playersBatch = _firestore.batch();
      for (final doc in playersQuery.docs) {
        playersBatch.delete(doc.reference);
      }
      await playersBatch.commit();
      _logService.info('${playersQuery.docs.length} oyuncu silindi',
          tag: 'Auth');

      // 3. Kullanıcıya bağlı tüm bildirimleri sil
      _logService.info('Kullanıcı bildirimleri siliniyor...', tag: 'Auth');
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      final notificationsBatch = _firestore.batch();
      for (final doc in notificationsQuery.docs) {
        notificationsBatch.delete(doc.reference);
      }
      await notificationsBatch.commit();
      _logService.info('${notificationsQuery.docs.length} bildirim silindi',
          tag: 'Auth');

      // 4. Kullanıcı dokümanını sil
      _logService.info('Kullanıcı dokümanı siliniyor...', tag: 'Auth');
      await _firestore.collection('users').doc(user.uid).delete();

      // 5. Firebase Auth'dan kullanıcıyı sil
      _logService.info('Firebase Auth kullanıcısı siliniyor...', tag: 'Auth');
      await user.delete();

      // 6. Google Sign-In'i temizle
      await _googleSignIn.signOut();

      _logService.info('Kullanıcı hesabı ve tüm verileri başarıyla silindi',
          tag: 'Auth');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage =
              'Hesap silmek için son zamanlarda tekrar giriş yapmanız gerekiyor.';
          break;
        case 'user-not-found':
          errorMessage = 'Kullanıcı bulunamadı.';
          break;
        case 'permission-denied':
          errorMessage = 'Bu işlem için yetkiniz yok.';
          break;
        default:
          errorMessage = 'Hesap silme işlemi başarısız: ${e.code}';
      }
      _logService.error('Hesap silme FirebaseAuthException: ${e.code}',
          tag: 'Auth', error: e);
      throw Exception(errorMessage);
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = 'Veri silme işlemi için yetkiniz yok.';
          break;
        case 'unavailable':
          errorMessage = 'Sunucu şu anda kullanılamıyor.';
          break;
        default:
          errorMessage = 'Veri silme işlemi başarısız: ${e.code}';
      }
      _logService.error('Hesap silme FirebaseException: ${e.code}',
          tag: 'Auth', error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('Hesap silme genel hata', tag: 'Auth', error: e);
      throw Exception(
          'Hesap silme işlemi sırasında beklenmeyen bir hata oluştu');
    }
  }

  // Kullanıcının hesap silme işlemi için yeniden kimlik doğrulaması gerekip gerekmediğini kontrol et
  Future<bool> requiresRecentLoginForDelete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Son giriş zamanını kontrol et (24 saat)
      final lastSignInTime = user.metadata.lastSignInTime;
      if (lastSignInTime == null) return true;

      final now = DateTime.now();
      final difference = now.difference(lastSignInTime);

      // 24 saatten fazla geçmişse yeniden kimlik doğrulaması gerekir
      return difference.inHours >= 24;
    } catch (e) {
      _logService.error('Yeniden kimlik doğrulama kontrolü hatası',
          tag: 'Auth', error: e);
      return true; // Hata durumunda güvenlik için true döndür
    }
  }

  // Misafir kullanıcı hesabını sil
  Future<void> deleteGuestAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      if (!user.isAnonymous) {
        throw Exception('Bu işlem sadece misafir kullanıcılar için geçerlidir');
      }

      _logService.info(
          'Misafir kullanıcı hesabı silme işlemi başlatıldı: ${user.uid}',
          tag: 'Auth');

      // 1. Misafir verilerini temizle
      _logService.info('Misafir verileri temizleniyor...', tag: 'Auth');
      await _guestDataService.clearGuestData();
      _logService.info('Misafir verileri temizlendi', tag: 'Auth');

      // 2. Firebase Auth'dan misafir kullanıcıyı sil
      _logService.info('Firebase Auth misafir kullanıcısı siliniyor...',
          tag: 'Auth');
      await user.delete();

      // 3. Google Sign-In'i temizle
      await _googleSignIn.signOut();

      _logService.info('Misafir kullanıcı hesabı başarıyla silindi',
          tag: 'Auth');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage =
              'Hesap silmek için son zamanlarda tekrar giriş yapmanız gerekiyor.';
          break;
        case 'user-not-found':
          errorMessage = 'Kullanıcı bulunamadı.';
          break;
        case 'permission-denied':
          errorMessage = 'Bu işlem için yetkiniz yok.';
          break;
        default:
          errorMessage = 'Misafir hesap silme işlemi başarısız: ${e.code}';
      }
      _logService.error('Misafir hesap silme FirebaseAuthException: ${e.code}',
          tag: 'Auth', error: e);
      throw Exception(errorMessage);
    } catch (e) {
      _logService.error('Misafir hesap silme genel hata',
          tag: 'Auth', error: e);
      throw Exception(
          'Misafir hesap silme işlemi sırasında beklenmeyen bir hata oluştu');
    }
  }

  // Hoşgeldin bildirimi göster
  Future<void> _showWelcomeNotification(User user) async {
    try {
      // Misafir kullanıcılara hoşgeldin bildirimi gösterme
      if (user.isAnonymous) return;

      // Kullanıcı bilgilerini al
      String? userName;
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userName =
              userData['displayName'] ?? userData['email']?.split('@')[0];
        }
      } catch (e) {
        _logService.warning('Kullanıcı bilgileri alınamadı: $e', tag: 'Auth');
      }

      // Hoşgeldin bildirimi göster
      await _notificationService.showWelcomeNotification(userName: userName);
      _logService.info('Hoşgeldin bildirimi gösterildi', tag: 'Auth');
    } catch (e) {
      _logService.warning('Hoşgeldin bildirimi gösterilirken hata: $e',
          tag: 'Auth');
    }
  }
}
