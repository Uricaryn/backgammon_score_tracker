import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/services/realtime_game_service.dart';

class NotificationNavigationService {
  NotificationNavigationService({
    RealtimeGameService? realtimeGameService,
    FirebaseAuth? auth,
  })  : _realtimeGameService = realtimeGameService ?? RealtimeGameService(),
        _auth = auth ?? FirebaseAuth.instance;

  final RealtimeGameService _realtimeGameService;
  final FirebaseAuth _auth;

  Future<bool> handleTap(Map<String, dynamic>? data) async {
    final normalized = data ?? <String, dynamic>{};
    final type = (normalized['type'] as String?)?.trim();
    final payload = (normalized['payload'] as String?)?.trim();

    String? roomId = (normalized['roomId'] as String?)?.trim();
    roomId ??= _roomIdFromPayload(payload);

    if (type == 'social') return false;

    if (_isLiveGameNavigation(type, payload) &&
        roomId != null &&
        roomId.isNotEmpty) {
      await _resumeRoomIfPossible(roomId);
      return _navigateToLiveGame(roomId);
    }

    return false;
  }

  bool _isLiveGameNavigation(String? type, String? payload) {
    if (type == 'live_game_invite' ||
        type == 'live_game_resume' ||
        type == 'tournament_match_invite') {
      return true;
    }
    return payload != null &&
        (payload.startsWith('live_game_invite:') ||
            payload.startsWith('live_game_resume:') ||
            payload.startsWith('tournament_match_invite:'));
  }

  String? _roomIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty || !payload.contains(':')) {
      return null;
    }
    final parts = payload.split(':');
    if (parts.length < 2) return null;
    final maybeType = parts.first.trim();
    final maybeRoomId = parts.sublist(1).join(':').trim();
    if ((maybeType == 'live_game_invite' ||
            maybeType == 'live_game_resume' ||
            maybeType == 'tournament_match_invite') &&
        maybeRoomId.isNotEmpty) {
      return maybeRoomId;
    }
    return null;
  }

  Future<void> _resumeRoomIfPossible(String roomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _realtimeGameService.resumeRoom(
        roomId: roomId,
        playerUid: user.uid,
        playerName: user.displayName ?? user.email ?? 'Oyuncu',
      );
    } catch (e) {
      debugPrint('Notification resumeRoom failed: $e');
    }
  }

  bool _navigateToLiveGame(String roomId) {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamed(
      AppRouter.liveGame,
      arguments: {'roomId': roomId},
    );
    return true;
  }
}
