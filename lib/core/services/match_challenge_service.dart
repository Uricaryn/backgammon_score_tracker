import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/friendship_service.dart';

class MatchChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();
  final FriendshipService _friendshipService = FriendshipService();

  // Challenge durumları
  static const String challengePending = 'pending';
  static const String challengeAccepted = 'accepted';
  static const String challengeDeclined = 'declined';
  static const String challengeExpired = 'expired';
  static const String challengeCancelled = 'cancelled';

  /// Arkadaşa maç daveti gönder
  Future<void> sendMatchChallenge(String friendUserId,
      {String? message}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Arkadaş olup olmadığını kontrol et
      final isFriend =
          await _friendshipService.areFriends(currentUser.uid, friendUserId);
      if (!isFriend) {
        throw Exception('Bu kullanıcı arkadaşınız değil');
      }

      // Aynı kullanıcıya bekleyen challenge var mı kontrol et
      final existingChallenge = await _firestore
          .collection('match_challenges')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: friendUserId)
          .where('status', isEqualTo: challengePending)
          .get();

      if (existingChallenge.docs.isNotEmpty) {
        throw Exception(
            'Bu arkadaşınıza zaten bekleyen bir maç daveti gönderilmiş');
      }

      // Yeni challenge oluştur
      await _firestore.collection('match_challenges').add({
        'fromUserId': currentUser.uid,
        'toUserId': friendUserId,
        'status': challengePending,
        'message': message ?? 'Hadi bir maç yapalım!',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(), // 24 saat sonra expire
      });

      // Alıcıya bildirim gönder
      await _sendChallengeNotification(
          friendUserId, currentUser.uid, 'challenge_sent');

      _logService.info('Match challenge sent to: $friendUserId',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to send match challenge',
          tag: 'MatchChallenge', error: e);
      rethrow;
    }
  }

  /// Maç davetini kabul et
  Future<void> acceptChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Challenge'ı kontrol et
      final challengeDoc = await _firestore
          .collection('match_challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) {
        throw Exception('Maç daveti bulunamadı');
      }

      final challengeData = challengeDoc.data()!;

      if (challengeData['toUserId'] != currentUser.uid) {
        throw Exception('Bu daveti kabul etme yetkiniz yok');
      }

      if (challengeData['status'] != challengePending) {
        throw Exception('Bu davet zaten işlenmiş');
      }

      // Challenge'ı kabul edildi olarak güncelle
      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': challengeAccepted,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Gönderen kişiye bildirim
      await _sendChallengeNotification(
          challengeData['fromUserId'], currentUser.uid, 'challenge_accepted');

      _logService.info('Match challenge accepted: $challengeId',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to accept challenge',
          tag: 'MatchChallenge', error: e);
      rethrow;
    }
  }

  /// Maç davetini reddet
  Future<void> declineChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': challengeDeclined,
        'declinedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Match challenge declined: $challengeId',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to decline challenge',
          tag: 'MatchChallenge', error: e);
      rethrow;
    }
  }

  /// Maç davetini iptal et
  Future<void> cancelChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': challengeCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Match challenge cancelled: $challengeId',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to cancel challenge',
          tag: 'MatchChallenge', error: e);
      rethrow;
    }
  }

  /// Gelen challenge'ları getir
  Stream<List<Map<String, dynamic>>> getIncomingChallenges() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('match_challenges')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: challengePending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final challenges = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Gönderen kullanıcı bilgilerini al
        final fromUserDoc =
            await _firestore.collection('users').doc(data['fromUserId']).get();

        if (fromUserDoc.exists) {
          final fromUserData = fromUserDoc.data()!;
          challenges.add({
            'id': doc.id,
            'fromUserId': data['fromUserId'],
            'fromUserName': fromUserData['username'] ?? 'Bilinmeyen',
            'fromUserEmail': fromUserData['email'] ?? '',
            'message': data['message'] ?? '',
            'createdAt': data['createdAt'],
            'status': data['status'],
          });
        }
      }

      return challenges;
    });
  }

  /// Giden challenge'ları getir
  Stream<List<Map<String, dynamic>>> getOutgoingChallenges() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('match_challenges')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: challengePending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final challenges = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Alıcı kullanıcı bilgilerini al
        final toUserDoc =
            await _firestore.collection('users').doc(data['toUserId']).get();

        if (toUserDoc.exists) {
          final toUserData = toUserDoc.data()!;
          challenges.add({
            'id': doc.id,
            'toUserId': data['toUserId'],
            'toUserName': toUserData['username'] ?? 'Bilinmeyen',
            'toUserEmail': toUserData['email'] ?? '',
            'message': data['message'] ?? '',
            'createdAt': data['createdAt'],
            'status': data['status'],
          });
        }
      }

      return challenges;
    });
  }

  /// Challenge bildirimi gönder
  Future<void> _sendChallengeNotification(
      String toUserId, String fromUserId, String type) async {
    try {
      // Gönderen kullanıcı bilgilerini al
      final fromUserDoc =
          await _firestore.collection('users').doc(fromUserId).get();
      if (!fromUserDoc.exists) return;

      final fromUserData = fromUserDoc.data()!;
      final fromUserName = fromUserData['username'] ?? 'Bilinmeyen Kullanıcı';

      // Alıcının bildirim tercihlerini kontrol et
      final toUserDoc =
          await _firestore.collection('users').doc(toUserId).get();
      if (!toUserDoc.exists) return;

      final toUserData = toUserDoc.data()!;
      if (toUserData['socialNotifications'] != true) return;

      String title;
      String body;
      String payload;

      switch (type) {
        case 'challenge_sent':
          title = 'Yeni Maç Daveti';
          body = '$fromUserName size maç daveti gönderdi';
          payload = 'match_challenge:$fromUserId';
          break;
        case 'challenge_accepted':
          title = 'Maç Daveti Kabul Edildi';
          body = '$fromUserName maç davetinizi kabul etti';
          payload = 'challenge_accepted:$fromUserId';
          break;
        default:
          return;
      }

      // Firebase'e bildirim kaydı yap
      await _firestore.collection('notifications').add({
        'userId': toUserId,
        'title': title,
        'body': body,
        'type': 'match_challenge',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': payload,
          'source': 'match_challenge',
          'fromUserId': fromUserId,
          'fromUserName': fromUserName,
          'type': type,
        },
      });

      _logService.info('Challenge notification saved to Firebase',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to send challenge notification',
          tag: 'MatchChallenge', error: e);
    }
  }

  /// Expired challenge'ları temizle
  Future<void> cleanupExpiredChallenges() async {
    try {
      final twentyFourHoursAgo =
          DateTime.now().subtract(const Duration(hours: 24));

      final expiredChallenges = await _firestore
          .collection('match_challenges')
          .where('status', isEqualTo: challengePending)
          .where('createdAt',
              isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredChallenges.docs) {
        batch.update(doc.reference, {
          'status': challengeExpired,
          'expiredAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _logService.info(
          'Cleaned up ${expiredChallenges.docs.length} expired challenges',
          tag: 'MatchChallenge');
    } catch (e) {
      _logService.error('Failed to cleanup expired challenges',
          tag: 'MatchChallenge', error: e);
    }
  }
}
