import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/models/active_live_game_summary.dart';
import 'package:backgammon_score_tracker/core/models/game_session.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/live_game_message.dart';
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
        participantIds: [creatorUid],
        awayPlayers: [],
      );
      await doc.set(session.toMap());
      return roomCode;
    }
    throw Exception('Oda kodu olusturulamadi. Tekrar deneyin.');
  }

  /// Join as black (new) or resume if already a participant.
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
      final session = GameSession.fromMap(snapshot.data()!);

      if (session.playerWhiteId == playerUid ||
          session.playerBlackId == playerUid) {
        final away = List<String>.from(session.awayPlayers)..remove(playerUid);
        txn.update(docRef, {
          'awayPlayers': away,
          'leftPlayers': FieldValue.delete(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      if (session.playerBlackId.isNotEmpty) {
        throw Exception('Oda dolu.');
      }

      final participants = List<String>.from(session.participantIds);
      if (!participants.contains(playerUid)) {
        participants.add(playerUid);
      }

      final updated = session.copyWith(
        playerBlackId: playerUid,
        playerBlackName: playerName,
        updatedAt: DateTime.now(),
        participantIds: participants,
        awayPlayers: [],
        state: session.state.status == GameStatus.waiting
            ? session.state.copyWith(status: GameStatus.openingRoll)
            : session.state,
      );
      txn.update(docRef, updated.toMap());
    });
  }

  /// Clears away flag when returning to an in-progress room (no state reset).
  Future<void> rejoinRoom({
    required String roomId,
    required String playerUid,
  }) async {
    final docRef = _games.doc(roomId.trim().toUpperCase());
    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Oda bulunamadi.');
      }
      final session = GameSession.fromMap(snapshot.data()!);
      if (session.playerWhiteId != playerUid &&
          session.playerBlackId != playerUid) {
        throw Exception('Bu odada oyuncu degilsiniz.');
      }
      final away = List<String>.from(session.awayPlayers)..remove(playerUid);
      txn.update(docRef, {
        'awayPlayers': away,
        'leftPlayers': FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Notification / lobby entry: rejoin if participant, else join open slot.
  Future<void> resumeRoom({
    required String roomId,
    required String playerUid,
    required String playerName,
  }) async {
    final docRef = _games.doc(roomId.trim().toUpperCase());
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Oda bulunamadi.');
    }
    final session = GameSession.fromMap(snap.data()!);
    if (session.playerWhiteId == playerUid ||
        session.playerBlackId == playerUid) {
      await rejoinRoom(roomId: roomId, playerUid: playerUid);
      return;
    }
    await joinRoom(
      roomId: roomId,
      playerUid: playerUid,
      playerName: playerName,
    );
  }

  Stream<GameSession?> watchRoom(String roomId) {
    return _games.doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return GameSession.fromMap(snapshot.data()!);
    });
  }

  Stream<List<ActiveLiveGameSummary>> watchActiveGamesForUser(String userId) {
    QuerySnapshot<Map<String, dynamic>>? whiteSnap;
    QuerySnapshot<Map<String, dynamic>>? blackSnap;

    return Stream<List<ActiveLiveGameSummary>>.multi((controller) {
      void publish() {
        if (whiteSnap == null || blackSnap == null) return;
        controller.add(
          _summariesFromSnapshots(userId, whiteSnap!, blackSnap!),
        );
      }

      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
        _games
            .where('playerWhiteId', isEqualTo: userId)
            .snapshots()
            .listen((s) {
          whiteSnap = s;
          publish();
        }),
        _games
            .where('playerBlackId', isEqualTo: userId)
            .snapshots()
            .listen((s) {
          blackSnap = s;
          publish();
        }),
      ];

      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  List<ActiveLiveGameSummary> _summariesFromSnapshots(
    String userId,
    QuerySnapshot<Map<String, dynamic>> whiteSnap,
    QuerySnapshot<Map<String, dynamic>> blackSnap,
  ) {
    final byRoom = <String, ActiveLiveGameSummary>{};

    void addDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final session = GameSession.fromMap(doc.data());
      if (session.state.status == GameStatus.finished) return;

      final isWhite = session.playerWhiteId == userId;
      final opponentName = isWhite
          ? (session.playerBlackName.isNotEmpty
              ? session.playerBlackName
              : 'Rakip bekleniyor')
          : session.playerWhiteName;
      final opponentId =
          isWhite ? session.playerBlackId : session.playerWhiteId;
      final opponentAway =
          opponentId.isNotEmpty && session.awayPlayers.contains(opponentId);

      byRoom[doc.id] = ActiveLiveGameSummary(
        roomId: doc.id,
        opponentName: opponentName,
        status: session.state.status,
        updatedAt: session.updatedAt,
        isOpponentAway: opponentAway,
      );
    }

    for (final doc in whiteSnap.docs) {
      addDoc(doc);
    }
    for (final doc in blackSnap.docs) {
      addDoc(doc);
    }

    final list = byRoom.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  CollectionReference<Map<String, dynamic>> _messages(String roomId) =>
      _games.doc(roomId).collection('messages');

  Stream<List<LiveGameMessage>> watchChatMessages(String roomId) {
    return _messages(roomId)
        .orderBy('timestamp', descending: false)
        .limit(80)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LiveGameMessage.fromFirestore(d.id, d.data()))
            .toList());
  }

  Future<void> sendChatMessage({
    required String roomId,
    required String userId,
    required String username,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return;
    await _messages(roomId).add({
      'userId': userId,
      'username': username,
      'message': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently removes an in-progress room (participant only).
  Future<void> deleteUnfinishedGame({
    required String roomId,
    required String playerUid,
  }) async {
    final normalized = roomId.trim().toUpperCase();
    final docRef = _games.doc(normalized);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Oda bulunamadi.');
    }
    final session = GameSession.fromMap(snap.data()!);
    if (session.playerWhiteId != playerUid &&
        session.playerBlackId != playerUid) {
      throw Exception('Bu oyunu silme yetkiniz yok.');
    }
    if (session.state.status == GameStatus.finished) {
      throw Exception('Bitmis oyunlar buradan silinemez.');
    }

    final opponentUid = playerUid == session.playerWhiteId
        ? session.playerBlackId
        : session.playerWhiteId;
    final deleterName = playerUid == session.playerWhiteId
        ? session.playerWhiteName
        : session.playerBlackName;

    final batch = _firestore.batch();
    final msgSnap = await _messages(normalized).limit(100).get();
    for (final doc in msgSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(docRef);
    await batch.commit();

    if (session.tournamentId != null &&
        session.matchId != null &&
        session.tournamentId!.isNotEmpty &&
        session.matchId!.isNotEmpty) {
      final matchDocId = '${session.tournamentId}_${session.matchId}';
      try {
        await _firestore.collection('tournament_matches').doc(matchDocId).update({
          'activeRoomId': FieldValue.delete(),
          'activeRoomUpdatedAt': FieldValue.delete(),
        });
      } catch (_) {}
    }

    if (opponentUid.isNotEmpty) {
      try {
        await _firestore.collection('notifications').add({
          'userId': opponentUid,
          'title': 'Oyun silindi',
          'body': '$deleterName canli oyunu sildi.',
          'type': 'live_game',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'type': 'live_game_deleted',
            'roomId': normalized,
            'payload': 'live_game_deleted:$normalized',
          },
        });
      } catch (_) {}
    }
  }

  /// Marks player as away; room stays until game is finished.
  Future<void> leaveRoom({
    required String roomId,
    required String playerUid,
  }) async {
    try {
      final docRef = _games.doc(roomId);
      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(docRef);
        if (!snapshot.exists) return;
        final session = GameSession.fromMap(snapshot.data()!);

        final away = List<String>.from(session.awayPlayers);
        if (away.contains(playerUid)) return;
        away.add(playerUid);

        if (session.state.status == GameStatus.finished && away.length >= 2) {
          txn.delete(docRef);
          return;
        }

        txn.update(docRef, {
          'awayPlayers': away,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        final opponentUid = playerUid == session.playerWhiteId
            ? session.playerBlackId
            : session.playerWhiteId;
        if (opponentUid.isNotEmpty &&
            session.state.status != GameStatus.finished) {
          final leaverName = playerUid == session.playerWhiteId
              ? session.playerWhiteName
              : session.playerBlackName;
          txn.set(
            _firestore.collection('notifications').doc(),
            {
              'userId': opponentUid,
              'title': 'Canli oyun bekliyor',
              'body':
                  '$leaverName masadan ayrildi. Bildirime basarak oyuna donebilirsiniz.',
              'type': 'live_game',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
              'data': {
                'type': 'live_game_resume',
                'roomId': roomId,
                'payload': 'live_game_resume:$roomId',
              },
            },
          );
        }
      });
    } catch (_) {
      // Best-effort.
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
      final activeUid =
          isWhiteTurn ? session.playerWhiteId : session.playerBlackId;
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
      final activeUid =
          isWhiteTurn ? session.playerWhiteId : session.playerBlackId;
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
