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

    // As requested: social/unknown types should not navigate.
    if (type == 'social') return false;

    if ((type == 'live_game_invite' || type == 'tournament_match_invite') &&
        roomId != null &&
        roomId.isNotEmpty) {
      await _joinRoomIfPossible(roomId);
      return _navigateToLiveGame(roomId);
    }

    return false;
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
            maybeType == 'tournament_match_invite') &&
        maybeRoomId.isNotEmpty) {
      return maybeRoomId;
    }
    return null;
  }

  Future<void> _joinRoomIfPossible(String roomId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _realtimeGameService.joinRoom(
        roomId: roomId,
        playerUid: user.uid,
        playerName: user.displayName ?? user.email ?? 'Oyuncu',
      );
    } catch (e) {
      // Best effort join: navigation still proceeds to allow retry in UI flow.
      debugPrint('Notification joinRoom failed: $e');
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
