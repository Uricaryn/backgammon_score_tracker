import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/models/game_session.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/core/services/backgammon_engine_service.dart';

class RealtimeGameService {
  RealtimeGameService({
    FirebaseFirestore? firestore,
    BackgammonEngineService? engine,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _engine = engine ?? const BackgammonEngineService();

  final FirebaseFirestore _firestore;
  final BackgammonEngineService _engine;
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('live_games');

  static const String _roomCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateRoomCode([int length = 6]) {
    return List.generate(
      length,
      (_) => _roomCharset[_random.nextInt(_roomCharset.length)],
    ).join();
  }

  Future<String> createRoom({
    required String creatorUid,
    required String creatorName,
    String? tournamentId,
    String? matchId,
  }) async {
    for (int i = 0; i < 10; i++) {
      final roomCode = _generateRoomCode();
      final doc = _games.doc(roomCode);
      final existing = await doc.get();
      if (existing.exists) {
        continue;
      }
      final session = GameSession(
        id: roomCode,
        playerWhiteId: creatorUid,
        playerBlackId: '',
        playerWhiteName: creatorName,
        playerBlackName: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: GameState.initial().copyWith(status: GameStatus.waiting),
        tournamentId: tournamentId,
        matchId: matchId,
      );
      await doc.set(session.toMap());
      return roomCode;
    }
    throw Exception('Oda kodu olusturulamadi. Tekrar deneyin.');
  }

  Future<void> joinRoom({
    required String roomId,
    required String playerUid,
    required String playerName,
  }) async {
    final normalizedRoomId = roomId.trim().toUpperCase();
    final docRef = _games.doc(normalizedRoomId);
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Oda bulunamadi.');
      }
      final data = snapshot.data()!;
      final session = GameSession.fromMap(data);
      if (session.playerBlackId.isNotEmpty && session.playerBlackId != playerUid) {
        throw Exception('Oda dolu.');
      }
      final updated = session.copyWith(
        playerBlackId: playerUid,
        playerBlackName: playerName,
        updatedAt: DateTime.now(),
        state: session.state.copyWith(status: GameStatus.openingRoll),
      );
      txn.update(docRef, updated.toMap());
    });
  }

  Stream<GameSession?> watchRoom(String roomId) {
    return _games.doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return GameSession.fromMap(snapshot.data()!);
    });
  }

  /// Marks [playerUid] as having left [roomId].
  /// When both players have left, the room document is deleted from Firestore.
  /// Safe to call from `dispose` — errors are swallowed so they don't bubble up.
  Future<void> leaveRoom({
    required String roomId,
    required String playerUid,
  }) async {
    try {
      final docRef = _games.doc(roomId);
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) return;
        final data = snapshot.data()!;
        final left = List<String>.from(
          (data['leftPlayers'] as List<dynamic>?) ?? <dynamic>[],
        );
        if (left.contains(playerUid)) return; // already registered
        left.add(playerUid);
        // Both participants have now left — clean up the document.
        if (left.length >= 2) {
          txn.delete(docRef);
        } else {
          txn.update(docRef, {
            'leftPlayers': left,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (_) {
      // Best-effort: silently ignore errors (e.g. doc already deleted).
    }
  }

  Future<void> updateState({
    required String roomId,
    required GameState state,
  }) async {
    await _games.doc(roomId).update({
      'state': state.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Records the opening die for [playerUid] and, when both players have
  /// rolled, resolves the starting turn inside a Firestore transaction to
  /// prevent concurrent-write races.
  Future<void> rollOpeningDie({
    required String roomId,
    required String playerUid,
  }) async {
    final die = _engine.rollSingleDie(_random);
    final docRef = _games.doc(roomId);
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Oda bulunamadi.');
      }
      final session = GameSession.fromMap(snapshot.data()!);
      final state = session.state;

      if (state.status != GameStatus.openingRoll) return;

      final isWhite = session.playerWhiteId == playerUid;
      final isBlack = session.playerBlackId == playerUid;
      if (!isWhite && !isBlack) throw Exception('Oyuncu bu odada degil.');

      // Guard against double-rolling.
      if (isWhite && state.openingRollWhite != null) return;
      if (isBlack && state.openingRollBlack != null) return;

      final color = isWhite ? PlayerColor.white : PlayerColor.black;
      final newState = _engine.resolveOpeningDie(state, color, die);
      txn.update(
        docRef,
        {
          'state': newState.toMap(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  Future<void> applyMove({
    required String roomId,
    required Move move,
    required String playerUid,
  }) async {
    final docRef = _games.doc(roomId);
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Oda bulunamadi.');
      }
      final session = GameSession.fromMap(snapshot.data()!);
      final state = session.state;
      final isWhiteTurn = state.currentTurn == PlayerColor.white;
      final activeUid = isWhiteTurn ? session.playerWhiteId : session.playerBlackId;
      if (activeUid != playerUid) {
        throw Exception('Sirasi gelen oyuncu degilsiniz.');
      }
      final nextState = _engine.applyMove(state, move);
      final clearedOpening = nextState.openingShowWhite != null
          ? nextState.copyWith(clearOpeningBanner: true)
          : nextState;
      final updated = session.copyWith(
        state: clearedOpening,
        updatedAt: DateTime.now(),
      );
      txn.update(docRef, updated.toMap());
    });
  }

  Future<void> undoTurn({
    required String roomId,
    required String playerUid,
  }) async {
    final docRef = _games.doc(roomId);
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Oda bulunamadi.');
      }
      final session = GameSession.fromMap(snapshot.data()!);
      final state = session.state;
      final isWhiteTurn = state.currentTurn == PlayerColor.white;
      final activeUid = isWhiteTurn ? session.playerWhiteId : session.playerBlackId;
      if (activeUid != playerUid) {
        throw Exception('Sirasi gelen oyuncu degilsiniz.');
      }
      final nextState = _engine.undoTurn(state);
      final updated = session.copyWith(
        state: nextState,
        updatedAt: DateTime.now(),
      );
      txn.update(docRef, updated.toMap());
    });
  }
}
