import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/error/error_service.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/notification_service.dart';
import 'package:backgammon_score_tracker/core/models/notification_model.dart';

class FriendshipService {
  static final FriendshipService _instance = FriendshipService._internal();
  factory FriendshipService() => _instance;
  FriendshipService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService();

  // Friend request statuses
  static const String requestPending = 'pending';
  static const String requestAccepted = 'accepted';
  static const String requestDeclined = 'declined';

  // Friendship statuses
  static const String friendshipActive = 'active';
  static const String friendshipBlocked = 'blocked';

  /// Kullanıcı arama - username veya email ile
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      if (query.trim().isEmpty || query.length < 2) {
        return [];
      }

      _logService.info('Searching users with query: $query', tag: 'Friendship');

      // Username ile arama
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: query.toLowerCase() + 'z')
          .limit(10)
          .get();

      // Email ile arama (tam eşleşme)
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: query.toLowerCase())
          .limit(5)
          .get();

      // Sonuçları birleştir ve dedup et
      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> results = [];

      for (final doc in [...usernameQuery.docs, ...emailQuery.docs]) {
        if (doc.id == currentUser.uid || seenIds.contains(doc.id)) continue;

        seenIds.add(doc.id);
        final data = doc.data();

        // Privacy kontrolü
        if (data['allowFriendSearch'] == false) continue;

        results.add({
          'id': doc.id,
          'email': data['email'] ?? '',
          'username': data['username'] ?? 'Bilinmeyen Kullanıcı',
          'displayName': data['displayName'],
          'photoURL': data['photoURL'],
          'isActive': data['isActive'] ?? false,
        });
      }

      _logService.info('Found ${results.length} users for query: $query',
          tag: 'Friendship');
      return results;
    } catch (e) {
      _logService.error('User search failed', tag: 'Friendship', error: e);
      throw Exception('Kullanıcı arama başarısız: $e');
    }
  }

  /// Arkadaşlık isteği gönder
  Future<void> sendFriendRequest(String toUserId, {String? message}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      if (currentUser.uid == toUserId) {
        throw Exception('Kendinize arkadaşlık isteği gönderemezsiniz');
      }

      _logService.info('Sending friend request to: $toUserId',
          tag: 'Friendship');

      // Zaten arkadaş mı kontrol et
      final existingFriendship =
          await _getFriendship(currentUser.uid, toUserId);
      if (existingFriendship != null) {
        throw Exception('Bu kullanıcı zaten arkadaşınız');
      }

      // Bekleyen istek var mı kontrol et
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: requestPending)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Bu kullanıcıya zaten arkadaşlık isteği gönderilmiş');
      }

      // Karşılıklı istek var mı kontrol et (otomatik kabul)
      final reverseRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: toUserId)
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: requestPending)
          .get();

      if (reverseRequest.docs.isNotEmpty) {
        // Karşılıklı istek var - otomatik kabul et
        await _acceptFriendRequest(reverseRequest.docs.first.id);
        return;
      }

      // Yeni istek oluştur
      await _firestore.collection('friend_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': toUserId,
        'status': requestPending,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Alıcıya bildirim gönder
      await _sendFriendRequestNotification(toUserId, currentUser.uid);

      _logService.info('Friend request sent successfully', tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to send friend request',
          tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// Arkadaşlık isteğini kabul et
  Future<void> acceptFriendRequest(String requestId) async {
    await _acceptFriendRequest(requestId);
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      _logService.info('Accepting friend request: $requestId',
          tag: 'Friendship');

      // İsteği kontrol et
      final requestDoc =
          await _firestore.collection('friend_requests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Arkadaşlık isteği bulunamadı');
      }

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'] as String;
      final toUserId = requestData['toUserId'] as String;

      if (toUserId != currentUser.uid) {
        throw Exception('Bu isteği kabul etme yetkiniz yok');
      }

      if (requestData['status'] != requestPending) {
        throw Exception('Bu istek zaten işlenmiş');
      }

      // Batch işlem başlat
      final batch = _firestore.batch();

      // İsteği kabul edildi olarak güncelle
      batch.update(requestDoc.reference, {
        'status': requestAccepted,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Arkadaşlık oluştur
      final friendshipId = _generateFriendshipId(fromUserId, toUserId);
      final friendshipRef =
          _firestore.collection('friendships').doc(friendshipId);

      batch.set(friendshipRef, {
        'userId1': fromUserId,
        'userId2': toUserId,
        'status': friendshipActive,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Kabul eden kişiye bildirim gönder
      await _sendFriendAcceptedNotification(fromUserId, currentUser.uid);

      _logService.info('Friend request accepted successfully',
          tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to accept friend request',
          tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// Arkadaşlık isteğini reddet
  Future<void> declineFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      _logService.info('Declining friend request: $requestId',
          tag: 'Friendship');

      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': requestDeclined,
        'declinedAt': FieldValue.serverTimestamp(),
      });

      _logService.info('Friend request declined successfully',
          tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to decline friend request',
          tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// Arkadaşlığı sonlandır
  Future<void> removeFriend(String friendUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      _logService.info('Removing friend: $friendUserId', tag: 'Friendship');

      final friendshipId = _generateFriendshipId(currentUser.uid, friendUserId);
      await _firestore.collection('friendships').doc(friendshipId).delete();

      _logService.info('Friend removed successfully', tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to remove friend', tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// Gelen arkadaşlık istekleri
  Stream<List<Map<String, dynamic>>> getIncomingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> requests = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Client-side status kontrolü
        if (data['status'] != requestPending) continue;

        final fromUserId = data['fromUserId'] as String;

        // Gönderen kullanıcı bilgilerini al
        final userDoc =
            await _firestore.collection('users').doc(fromUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          requests.add({
            'id': doc.id,
            'fromUserId': fromUserId,
            'fromUserName': userData['username'] ?? 'Bilinmeyen Kullanıcı',
            'fromUserEmail': userData['email'] ?? '',
            'message': data['message'],
            'createdAt': data['createdAt'],
          });
        }
      }

      return requests;
    });
  }

  /// Gönderilen arkadaşlık istekleri
  Stream<List<Map<String, dynamic>>> getOutgoingFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> requests = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Client-side status kontrolü
        if (data['status'] != requestPending) continue;

        final toUserId = data['toUserId'] as String;

        // Alıcı kullanıcı bilgilerini al
        final userDoc =
            await _firestore.collection('users').doc(toUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          requests.add({
            'id': doc.id,
            'toUserId': toUserId,
            'toUserName': userData['username'] ?? 'Bilinmeyen Kullanıcı',
            'toUserEmail': userData['email'] ?? '',
            'message': data['message'],
            'createdAt': data['createdAt'],
          });
        }
      }

      return requests;
    });
  }

  /// Arkadaş listesi
  Stream<List<Map<String, dynamic>>> getFriends() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Sadece userId alanlarıyla query yap, status filtresini client-side yap
    final stream1 = _firestore
        .collection('friendships')
        .where('userId1', isEqualTo: currentUser.uid)
        .snapshots();

    final stream2 = _firestore
        .collection('friendships')
        .where('userId2', isEqualTo: currentUser.uid)
        .snapshots();

    return stream1.asyncExpand((snapshot1) {
      return stream2.asyncMap((snapshot2) async {
        final List<Map<String, dynamic>> friends = [];

        // İlk query'den gelen arkadaşlıkları işle (kullanıcı userId1)
        for (final doc in snapshot1.docs) {
          final data = doc.data();

          // Client-side status kontrolü
          if (data['status'] != friendshipActive) continue;

          final friendUserId = data['userId2'] as String;

          final userDoc =
              await _firestore.collection('users').doc(friendUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            friends.add({
              'friendshipId': doc.id,
              'userId': friendUserId,
              'username': userData['username'] ?? 'Bilinmeyen Kullanıcı',
              'email': userData['email'] ?? '',
              'displayName': userData['displayName'],
              'photoURL': userData['photoURL'],
              'isActive': userData['isActive'] ?? false,
              'createdAt': data['createdAt'],
            });
          }
        }

        // İkinci query'den gelen arkadaşlıkları işle (kullanıcı userId2)
        for (final doc in snapshot2.docs) {
          final data = doc.data();

          // Client-side status kontrolü
          if (data['status'] != friendshipActive) continue;

          final friendUserId = data['userId1'] as String;

          final userDoc =
              await _firestore.collection('users').doc(friendUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            friends.add({
              'friendshipId': doc.id,
              'userId': friendUserId,
              'username': userData['username'] ?? 'Bilinmeyen Kullanıcı',
              'email': userData['email'] ?? '',
              'displayName': userData['displayName'],
              'photoURL': userData['photoURL'],
              'isActive': userData['isActive'] ?? false,
              'createdAt': data['createdAt'],
            });
          }
        }

        // Alfabetik sırala ve duplicate'leri kaldır
        final uniqueFriends = <String, Map<String, dynamic>>{};
        for (final friend in friends) {
          uniqueFriends[friend['userId']] = friend;
        }

        final sortedFriends = uniqueFriends.values.toList();
        sortedFriends.sort((a, b) => (a['username'] as String)
            .toLowerCase()
            .compareTo((b['username'] as String).toLowerCase()));

        return sortedFriends;
      });
    });
  }

  /// İki kullanıcının arkadaş olup olmadığını kontrol et
  Future<bool> areFriends(String userId1, String userId2) async {
    final friendship = await _getFriendship(userId1, userId2);
    return friendship != null && friendship['status'] == friendshipActive;
  }

  /// Arkadaşın maçlarını getir
  Future<List<Map<String, dynamic>>> getFriendGames(String friendUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Arkadaş olup olmadığını kontrol et
      final isFriend = await areFriends(currentUser.uid, friendUserId);
      if (!isFriend) {
        throw Exception('Bu kullanıcı arkadaşınız değil');
      }

      // Arkadaşın profil görünürlük ayarını kontrol et
      final friendDoc =
          await _firestore.collection('users').doc(friendUserId).get();
      if (friendDoc.exists) {
        final friendData = friendDoc.data()!;
        if (friendData['profileVisibility'] == false) {
          throw Exception(
              'Bu arkadaşınız profil görünürlüğünü kapattığı için maçlarını görüntüleyemezsiniz');
        }
      }

      final snapshot = await _firestore
          .collection('games')
          .where('userId', isEqualTo: friendUserId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      _logService.error('Failed to get friend games',
          tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// İki kullanıcı arasındaki arkadaşlığı getir
  Future<Map<String, dynamic>?> _getFriendship(
      String userId1, String userId2) async {
    try {
      // Önce userId1'in userId2 ile arkadaşlığını kontrol et
      final query1 = await _firestore
          .collection('friendships')
          .where('userId1', isEqualTo: userId1)
          .where('userId2', isEqualTo: userId2)
          .limit(1)
          .get();

      if (query1.docs.isNotEmpty) {
        return query1.docs.first.data();
      }

      // Sonra userId2'nin userId1 ile arkadaşlığını kontrol et
      final query2 = await _firestore
          .collection('friendships')
          .where('userId1', isEqualTo: userId2)
          .where('userId2', isEqualTo: userId1)
          .limit(1)
          .get();

      if (query2.docs.isNotEmpty) {
        return query2.docs.first.data();
      }

      return null;
    } catch (e) {
      _logService.error('Failed to get friendship',
          tag: 'Friendship', error: e);
      return null;
    }
  }

  /// Tutarlı arkadaşlık ID'si oluştur
  String _generateFriendshipId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Arkadaşlık isteği bildirimi gönder
  Future<void> _sendFriendRequestNotification(
      String toUserId, String fromUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Sadece Firebase'e kaydet, local notification gösterme
      // Çünkü local notification gönderen kişiye gösterilir, alıcıya değil

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

      // Sadece Firebase'e bildirim kaydı yap (alıcı için)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': toUserId, // Alıcının ID'si
        'title': 'Yeni Arkadaşlık İsteği',
        'body': '$fromUserName size arkadaşlık isteği gönderdi',
        'type': 'social',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': 'friend_request:$fromUserId',
          'source': 'friend_request',
          'fromUserId': fromUserId,
          'fromUserName': fromUserName,
        },
      });

      _logService.info('Friend request notification saved to Firebase',
          tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to send friend request notification',
          tag: 'Friendship', error: e);
    }
  }

  /// Arkadaşlık kabul edildi bildirimi gönder
  Future<void> _sendFriendAcceptedNotification(
      String toUserId, String fromUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Sadece Firebase'e kaydet, local notification gösterme
      // Çünkü local notification kabul eden kişiye gösterilir, istek gönderen kişiye değil

      // Kabul eden kullanıcı bilgilerini al
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

      // Sadece Firebase'e bildirim kaydı yap (istek gönderen kişi için)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': toUserId, // İstek gönderen kişinin ID'si
        'title': 'Arkadaşlık İsteği Kabul Edildi',
        'body': '$fromUserName arkadaşlık isteğinizi kabul etti',
        'type': 'social',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': 'friend_accepted:$fromUserId',
          'source': 'friend_accepted',
          'fromUserId': fromUserId,
          'fromUserName': fromUserName,
        },
      });

      _logService.info('Friend accepted notification saved to Firebase',
          tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to send friend accepted notification',
          tag: 'Friendship', error: e);
    }
  }

  /// Arkadaşlık isteğini iptal et
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      await _firestore.collection('friend_requests').doc(requestId).delete();
      _logService.info('Friend request cancelled: $requestId',
          tag: 'Friendship');
    } catch (e) {
      _logService.error('Failed to cancel friend request',
          tag: 'Friendship', error: e);
      rethrow;
    }
  }

  /// Kullanıcı ile arkadaşlık durumunu kontrol et
  Future<String> getFriendshipStatus(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception(ErrorService.authUserNotFound);
      }

      // Zaten arkadaş mı kontrol et
      final friendship = await _getFriendship(currentUser.uid, targetUserId);
      if (friendship != null && friendship['status'] == friendshipActive) {
        return 'friends';
      }

      // Giden istek var mı kontrol et
      final outgoingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: requestPending)
          .get();

      if (outgoingRequest.docs.isNotEmpty) {
        return 'request_sent';
      }

      // Gelen istek var mı kontrol et
      final incomingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: targetUserId)
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: requestPending)
          .get();

      if (incomingRequest.docs.isNotEmpty) {
        return 'request_received';
      }

      return 'none';
    } catch (e) {
      _logService.error('Failed to get friendship status',
          tag: 'Friendship', error: e);
      return 'none';
    }
  }
}
