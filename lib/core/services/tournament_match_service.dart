import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/services/log_service.dart';
import 'package:backgammon_score_tracker/core/services/realtime_game_service.dart';
import 'package:backgammon_score_tracker/core/services/tournament_service.dart';

class TournamentMatchService {
  TournamentMatchService({
    FirebaseFirestore? firestore,
    RealtimeGameService? realtimeGameService,
    TournamentService? tournamentService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _realtimeGameService = realtimeGameService ?? RealtimeGameService(),
        _tournamentService = tournamentService ?? TournamentService();

  final FirebaseFirestore _firestore;
  final RealtimeGameService _realtimeGameService;
  final TournamentService _tournamentService;
  final LogService _logService = LogService();

  CollectionReference<Map<String, dynamic>> get _tournamentMatches =>
      _firestore.collection('tournament_matches');

  String _docId(String tournamentId, String matchId) =>
      '${tournamentId}_$matchId';

  /// Start a tournament match: create or resume the tracking document and
  /// open a live game room linked to it.
  Future<String> startTournamentMatch({
    required String tournamentId,
    required String matchId,
    required String player1Id,
    required String player2Id,
    required String player1Name,
    required String player2Name,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Oturum acilmamis');
      if (currentUser.uid != player1Id && currentUser.uid != player2Id) {
        throw Exception('Bu maca katilma yetkiniz yok');
      }

      final docId = _docId(tournamentId, matchId);
      final docRef = _tournamentMatches.doc(docId);
      String? roomId;
      bool shouldNotifyOpponent = false;

      await _firestore.runTransaction((txn) async {
        final existing = await txn.get(docRef);

        if (existing.exists) {
          final data = existing.data()!;
          final activeRoomId = data['activeRoomId'] as String?;
          final status = data['status'] as String?;
          if (activeRoomId != null &&
              activeRoomId.isNotEmpty &&
              status != 'completed') {
            roomId = activeRoomId;
            return;
          }
        }

        // Fetch tournament settings for scoring config
        final tournamentDoc = await txn
            .get(_firestore.collection('tournaments').doc(tournamentId));
        final settings =
            (tournamentDoc.data()?['settings'] as Map<String, dynamic>?) ?? {};
        final scoringMode = (settings['scoringMode'] as String?) ??
            TournamentService.scoringModeSimple;
        final targetScore = (settings['targetScore'] as num?)?.toInt() ?? 5;

        if (!existing.exists) {
          txn.set(docRef, {
            'tournamentId': tournamentId,
            'matchId': matchId,
            'player1Id': player1Id,
            'player2Id': player2Id,
            'player1Name': player1Name,
            'player2Name': player2Name,
            'targetScore': targetScore,
            'scoringMode': scoringMode,
            'player1Score': 0,
            'player2Score': 0,
            'games': <Map<String, dynamic>>[],
            'status': 'active',
            'winnerId': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          txn.update(docRef, {'status': 'active', 'winnerId': null});
        }
      });

      final hadExistingRoom = roomId != null && roomId!.isNotEmpty;
      roomId ??= await _realtimeGameService.createRoom(
        creatorUid: currentUser.uid,
        creatorName: currentUser.uid == player1Id ? player1Name : player2Name,
        tournamentId: tournamentId,
        matchId: matchId,
      );
      if (!hadExistingRoom) {
        shouldNotifyOpponent = true;
      }

      final roomDoc =
          await _firestore.collection('live_games').doc(roomId!).get();
      final roomExists = roomDoc.exists;
      if (!roomExists) {
        roomId = await _realtimeGameService.createRoom(
          creatorUid: currentUser.uid,
          creatorName:
              currentUser.uid == player1Id ? player1Name : player2Name,
          tournamentId: tournamentId,
          matchId: matchId,
        );
        shouldNotifyOpponent = true;
      }

      await docRef.set({
        'activeRoomId': roomId,
        'activeRoomUpdatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      }, SetOptions(merge: true));
      // Send notification to opponent
      final opponentId =
          currentUser.uid == player1Id ? player2Id : player1Id;
      final opponentName =
          currentUser.uid == player1Id ? player1Name : player2Name;
      if (shouldNotifyOpponent) {
        await _sendTournamentMatchNotification(
          toUserId: opponentId,
          fromUserName:
              currentUser.uid == player1Id ? player1Name : player2Name,
          roomId: roomId!,
          tournamentId: tournamentId,
        );
      }

      _logService.info(
        'Tournament match started: $docId, room: $roomId, opponent: $opponentName',
        tag: 'TournamentMatch',
      );

      return roomId!;
    } catch (e) {
      _logService.error('Failed to start tournament match',
          tag: 'TournamentMatch', error: e);
      rethrow;
    }
  }

  /// Record a single game result within a tournament match and check whether
  /// the match target score has been reached.
  Future<Map<String, dynamic>> recordGameResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    required WinType winType,
    required String roomId,
  }) async {
    try {
      final docId = _docId(tournamentId, matchId);
      final docRef = _tournamentMatches.doc(docId);

      return await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Turnuva maci bulunamadi');
        }

        final data = snapshot.data()!;
        if (data['status'] == 'completed') {
          return data;
        }

        final scoringMode = (data['scoringMode'] as String?) ??
            TournamentService.scoringModeSimple;
        final targetScore = (data['targetScore'] as num?)?.toInt() ?? 5;
        final player1Id = data['player1Id'] as String;

        final points = _calculatePoints(winType, scoringMode);
        final isPlayer1Winner = winnerId == player1Id;

        var p1Score = (data['player1Score'] as num?)?.toInt() ?? 0;
        var p2Score = (data['player2Score'] as num?)?.toInt() ?? 0;

        if (isPlayer1Winner) {
          p1Score += points;
        } else {
          p2Score += points;
        }

        final games = List<Map<String, dynamic>>.from(
            (data['games'] as List<dynamic>?) ?? []);
        games.add({
          'roomId': roomId,
          'winnerId': winnerId,
          'winType': winType.name,
          'points': points,
          'timestamp': DateTime.now().toIso8601String(),
        });

        final matchCompleted = p1Score >= targetScore || p2Score >= targetScore;
        final matchWinnerId = matchCompleted
            ? (p1Score >= targetScore ? player1Id : data['player2Id'] as String)
            : null;

        txn.update(docRef, {
          'player1Score': p1Score,
          'player2Score': p2Score,
          'games': games,
          if (matchCompleted) 'status': 'completed',
          if (matchWinnerId != null) 'winnerId': matchWinnerId,
        });

        // If match is complete, update the tournament bracket
        if (matchCompleted && matchWinnerId != null) {
          // We run this outside the transaction because it modifies
          // a different document.
          Future.microtask(() async {
            try {
              await _tournamentService.recordMatchResult(
                tournamentId,
                matchId,
                matchWinnerId,
                p1Score,
                p2Score,
              );
            } catch (e) {
              _logService.error(
                'Failed to propagate match result to tournament bracket',
                tag: 'TournamentMatch',
                error: e,
              );
            }
          });
        }

        return {
          ...data,
          'player1Score': p1Score,
          'player2Score': p2Score,
          'games': games,
          'status': matchCompleted ? 'completed' : 'active',
          'winnerId': matchWinnerId,
        };
      });
    } catch (e) {
      _logService.error('Failed to record game result',
          tag: 'TournamentMatch', error: e);
      rethrow;
    }
  }

  /// Stream the current state of a tournament match (scores, games played).
  Stream<Map<String, dynamic>?> getMatchProgress(
      String tournamentId, String matchId) {
    final docId = _docId(tournamentId, matchId);
    return _tournamentMatches.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  /// Fetch once (non-stream).
  Future<Map<String, dynamic>?> getMatchProgressOnce(
      String tournamentId, String matchId) async {
    final docId = _docId(tournamentId, matchId);
    final snapshot = await _tournamentMatches.doc(docId).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  int _calculatePoints(WinType winType, String scoringMode) {
    if (scoringMode == TournamentService.scoringModeBackgammon) {
      switch (winType) {
        case WinType.normal:
          return 1;
        case WinType.mars:
          return 2;
        case WinType.kapiMarsi:
          return 3;
      }
    }
    return 1;
  }

  Future<void> _sendTournamentMatchNotification({
    required String toUserId,
    required String fromUserName,
    required String roomId,
    required String tournamentId,
  }) async {
    try {
      final toUserDoc =
          await _firestore.collection('users').doc(toUserId).get();
      if (!toUserDoc.exists) return;

      final toUserData = toUserDoc.data()!;
      if (toUserData['socialNotifications'] != true) return;

      await _firestore.collection('notifications').add({
        'userId': toUserId,
        'title': 'Turnuva Maci Daveti',
        'body': '$fromUserName turnuva macina baslamak istiyor',
        'type': 'match_challenge',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'payload': 'tournament_match_invite:$roomId',
          'source': 'tournament_match',
          'fromUserName': fromUserName,
          'type': 'tournament_match_invite',
          'roomId': roomId,
          'tournamentId': tournamentId,
        },
      });
    } catch (e) {
      _logService.error('Failed to send tournament match notification',
          tag: 'TournamentMatch', error: e);
    }
  }
}
