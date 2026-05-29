import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:backgammon_score_tracker/core/models/game_session.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/core/services/backgammon_engine_service.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/match_summary_adapter.dart';
import 'package:backgammon_score_tracker/core/services/realtime_game_service.dart';
import 'package:backgammon_score_tracker/core/services/tournament_match_service.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/presentation/widgets/opening_roll_panel.dart';
import 'package:backgammon_score_tracker/presentation/widgets/opening_result_banner.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/live_game_table.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/live_game_chat_panel.dart';

class LiveGameScreen extends StatefulWidget {
  const LiveGameScreen({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen> {
  final _service = RealtimeGameService();
  final _engine = const BackgammonEngineService();
  final _firebaseService = FirebaseService();
  final _summaryAdapter = const MatchSummaryAdapter();
  final _tournamentMatchService = TournamentMatchService();

  bool _savedFinishedMatch = false;
  bool _shownEndDialog = false;
  Map<String, dynamic>? _tournamentMatchResult;
  bool _leftRoom = false;
  bool _skipLeaveOnDispose = false;
  GameSession? _session;
  StreamSubscription<GameSession?>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _rejoinOnOpen();
    _sessionSubscription = _service.watchRoom(widget.roomId).listen(
      (session) {
        if (!mounted) return;

        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return;
        }

        _saveSummaryIfFinished(session);
        _maybeShowEndDialog(context, session);
        setState(() => _session = session);
      },
    );
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _registerLeave();
    super.dispose();
  }

  Future<void> _rejoinOnOpen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _service.rejoinRoom(
        roomId: widget.roomId,
        playerUid: user.uid,
      );
    } catch (_) {
      // Room may not exist yet or user is joining fresh.
    }
  }

  void _registerLeave() {
    if (_leftRoom || _skipLeaveOnDispose) return;
    _leftRoom = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _service.leaveRoom(roomId: widget.roomId, playerUid: user.uid);
    }
  }

  Future<void> _deleteGame(BuildContext ctx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oyunu Sil'),
        content: const Text(
          'Bu canli oyun kalici olarak silinecek. Rakibiniz de oyuna '
          'devam edemez.\n\nEmin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    try {
      _skipLeaveOnDispose = true;
      _leftRoom = true;
      await _service.deleteUnfinishedGame(
        roomId: widget.roomId,
        playerUid: user.uid,
      );
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop();
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Oyun silindi')),
      );
    } catch (e) {
      _skipLeaveOnDispose = false;
      _leftRoom = false;
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  /// Shows a confirmation dialog and, if confirmed, pops the screen.
  Future<void> _leaveGame(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oyundan Çık'),
        content: const Text(
          'Masadan ayrılmak istediğinize emin misiniz?\n\n'
          'Oyun kaydedilir; Online Tavla ekranından veya bildirimden '
          'kaldığınız yerden devam edebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctx.mounted) {
      Navigator.of(ctx).pop();
    }
  }

  PlayerColor _opponent(PlayerColor color) =>
      color == PlayerColor.white ? PlayerColor.black : PlayerColor.white;

  Future<void> _openingRoll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _service.rollOpeningDie(
      roomId: widget.roomId,
      playerUid: user.uid,
    );
  }

  Future<void> _roll(GameSession session) async {
    final roll = _engine.rollDice();
    final stateWithDice = session.state.copyWith(
      remainingDice: roll.toMoves(),
      clearTurnUndo: true,
    );
    final legal = _engine.legalMoves(stateWithDice);
    if (legal.isNotEmpty) {
      final next = _engine.startTurn(session.state, roll);
      await _service.updateState(roomId: widget.roomId, state: next);
      return;
    }

    // Zarlar oynanamasa bile kısa süre göster, sonra turu geçir.
    await _service.updateState(roomId: widget.roomId, state: stateWithDice);
    const noMovePreviewDuration = Duration(milliseconds: 1800);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hamle yok, tur geciyor'),
          duration: noMovePreviewDuration,
        ),
      );
    }
    await Future.delayed(noMovePreviewDuration);
    final passed = stateWithDice.copyWith(
      currentTurn: _opponent(stateWithDice.currentTurn),
      remainingDice: const [],
      clearTurnUndo: true,
    );
    await _service.updateState(roomId: widget.roomId, state: passed);
  }

  Future<void> _applyMove(Move move) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _service.applyMove(
      roomId: widget.roomId,
      move: move,
      playerUid: user.uid,
    );
  }

  bool _canUndoTurn(GameState s) {
    final ud = s.turnUndoDice;
    if (ud == null || s.status != GameStatus.active) return false;
    final cur = s.remainingDice;
    if (ud.length != cur.length) return true;
    for (var i = 0; i < ud.length; i++) {
      if (ud[i] != cur[i]) return true;
    }
    return false;
  }

  Future<void> _undoTurn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _service.undoTurn(
        roomId: widget.roomId,
        playerUid: user.uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _saveSummaryIfFinished(GameSession session) async {
    if (_savedFinishedMatch || session.state.status != GameStatus.finished) {
      return;
    }
    _savedFinishedMatch = true;

    final summary = _summaryAdapter.toLegacyScoreMap(session);
    await _firebaseService.saveGame(
      player1: summary['player1'] as String,
      player2: summary['player2'] as String,
      player1Score: summary['player1Score'] as int,
      player2Score: summary['player2Score'] as int,
    );

    if (session.tournamentId != null && session.matchId != null) {
      final winner = session.state.winner;
      if (winner == null) return;
      final winnerId = winner == PlayerColor.white
          ? session.playerWhiteId
          : session.playerBlackId;
      final winType = session.state.winType ?? WinType.normal;
      try {
        final result = await _tournamentMatchService.recordGameResult(
          tournamentId: session.tournamentId!,
          matchId: session.matchId!,
          winnerId: winnerId,
          winType: winType,
          roomId: widget.roomId,
        );
        if (mounted) {
          setState(() => _tournamentMatchResult = result);
        }
      } catch (_) {}
    }
  }

  void _maybeShowEndDialog(BuildContext ctx, GameSession session) {
    if (session.state.status != GameStatus.finished || _shownEndDialog) return;
    _shownEndDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showEndDialog(ctx, session);
    });
  }

  void _showEndDialog(BuildContext ctx, GameSession session) {
    final winnerName = session.state.winner == PlayerColor.white
        ? session.playerWhiteName
        : session.playerBlackName;
    final user = FirebaseAuth.instance.currentUser;
    final myColor = user?.uid == session.playerWhiteId
        ? PlayerColor.white
        : PlayerColor.black;
    final isWinner = session.state.winner == myColor;
    final isTournament =
        session.tournamentId != null && session.matchId != null;

    HapticFeedback.heavyImpact();

    final winType = session.state.winType;
    String winTypeLabel = '';
    if (winType == WinType.mars) {
      winTypeLabel = ' (Mars)';
    } else if (winType == WinType.kapiMarsi) {
      winTypeLabel = ' (Kapi Marsi)';
    }

    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
          size: 56,
          color: isWinner ? Colors.amber : Colors.blueGrey,
        )
            .animate()
            .scale(
              duration: 600.ms,
              begin: const Offset(0.0, 0.0),
              end: const Offset(1.0, 1.0),
              curve: Curves.elasticOut,
            )
            .then()
            .shimmer(duration: 1200.ms, color: Colors.amber.withValues(alpha: 0.4)),
        title: Text(
          isWinner ? 'Tebrikler!' : 'Oyun Bitti',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$winnerName kazandi!$winTypeLabel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(ctx)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
              child: Text(
                'Beyaz: ${session.state.borneOff[PlayerColor.white] ?? 0}/15 tas cikardi\n'
                'Siyah: ${session.state.borneOff[PlayerColor.black] ?? 0}/15 tas cikardi',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            if (isTournament && _tournamentMatchResult != null) ...[
              const SizedBox(height: 12),
              _TournamentMatchProgress(data: _tournamentMatchResult!),
            ],
          ],
        ),
        actions: [
          if (isTournament) ...[
            if (_tournamentMatchResult?['status'] == 'completed')
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).popUntil(
                    (route) => route.settings.name == AppRouter.tournaments ||
                        route.settings.name == AppRouter.home ||
                        route.isFirst,
                  );
                },
                child: const Text('Turnuvaya Don'),
              )
            else
              FilledButton(
                onPressed: () => _startNextTournamentGame(ctx, session),
                child: const Text('Sonraki Oyun'),
              ),
          ] else
            FilledButton(
              onPressed: () {
                Navigator.of(ctx)
                  ..pop()
                  ..pop()
                  ..pop();
              },
              child: const Text('Ana Sayfaya Don'),
            ),
        ],
      ),
    );
  }

  Future<void> _startNextTournamentGame(
      BuildContext ctx, GameSession session) async {
    if (session.tournamentId == null || session.matchId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final roomId = await _service.createRoom(
        creatorUid: user.uid,
        creatorName: user.uid == session.playerWhiteId
            ? session.playerWhiteName
            : session.playerBlackName,
        tournamentId: session.tournamentId,
        matchId: session.matchId,
      );

      if (!ctx.mounted) return;

      Navigator.of(ctx)
        ..pop() // close dialog
        ..pushReplacementNamed(
          AppRouter.liveGame,
          arguments: {'roomId': roomId},
        );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Yeni oyun olusturulamadi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveGame(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF142e18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B4332),
          automaticallyImplyLeading: false,
          title: const Text('Canli Oyun'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Center(
                    child: Text(
                      'Oda: ${widget.roomId.toUpperCase()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Oda kodunu kopyala',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.roomId.toUpperCase()),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Oda kodu kopyalandi'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Oyun secenekleri',
                    onSelected: (value) {
                      switch (value) {
                        case 'leave':
                          _leaveGame(context);
                          break;
                        case 'delete':
                          _deleteGame(context);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'leave',
                        child: ListTile(
                          leading: Icon(Icons.exit_to_app),
                          title: Text('Masadan ayril'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red.shade700,
                          ),
                          title: Text(
                            'Oyunu sil',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _session == null
            ? const Center(child: CircularProgressIndicator())
            : _buildGameBody(_session!),
      ),
    );
  }

  Widget _buildGameBody(GameSession session) {
    final user = FirebaseAuth.instance.currentUser;
    final isParticipant = user != null &&
        (user.uid == session.playerWhiteId || user.uid == session.playerBlackId);
    final myColor = user?.uid == session.playerWhiteId
        ? PlayerColor.white
        : PlayerColor.black;

    final isOpeningRoll = session.state.status == GameStatus.openingRoll;
    final canOpeningRoll = isParticipant &&
        isOpeningRoll &&
        (myColor == PlayerColor.white
            ? session.state.openingRollWhite == null
            : session.state.openingRollBlack == null);

    final isMyTurn = isParticipant &&
        !isOpeningRoll &&
        session.state.currentTurn == myColor &&
        session.state.status == GameStatus.active;

    final legalMoves = (isMyTurn && isParticipant)
        ? _engine.legalMoves(session.state)
        : <Move>[];

    final canUndo =
        isMyTurn && isParticipant && _canUndoTurn(session.state);

    return _GameBody(
      roomId: widget.roomId,
      session: session,
      myColor: myColor,
      isParticipant: isParticipant,
      isMyTurn: isMyTurn,
      legalMoves: legalMoves,
      onRoll: () => _roll(session),
      onMove: _applyMove,
      isOpeningRoll: isOpeningRoll,
      canOpeningRoll: canOpeningRoll,
      onOpeningRoll: _openingRoll,
      canUndo: canUndo,
      onUndo: _undoTurn,
    );
  }
}

// ── Game body ──────────────────────────────────────────────────────────────

class _GameBody extends StatelessWidget {
  const _GameBody({
    required this.roomId,
    required this.session,
    required this.myColor,
    required this.isParticipant,
    required this.isMyTurn,
    required this.legalMoves,
    required this.onRoll,
    required this.onMove,
    required this.isOpeningRoll,
    required this.canOpeningRoll,
    required this.onOpeningRoll,
    required this.canUndo,
    required this.onUndo,
  });

  final String roomId;
  final GameSession session;
  final PlayerColor myColor;
  final bool isParticipant;
  final bool isMyTurn;
  final List<Move> legalMoves;
  final VoidCallback onRoll;
  final ValueChanged<Move> onMove;
  final bool isOpeningRoll;
  final bool canOpeningRoll;
  final VoidCallback onOpeningRoll;
  final bool canUndo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final gs = session.state;
    final turnName = gs.currentTurn == PlayerColor.white
        ? session.playerWhiteName
        : session.playerBlackName;
    final myName = myColor == PlayerColor.white
        ? session.playerWhiteName
        : session.playerBlackName;
    final opponentName = myColor == PlayerColor.white
        ? session.playerBlackName
        : session.playerWhiteName;

    final bar = gs.bar[myColor] ?? 0;
    final showBarWarning = isMyTurn && bar > 0;
    final bearOffCount = legalMoves.where((m) => m.bearOff).length;

    final chatHeight =
        (MediaQuery.sizeOf(context).height * 0.28).clamp(200.0, 260.0);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerBar(
            myName: myName,
            opponentName: opponentName,
            myColor: myColor,
            session: session,
            isMyTurn: isMyTurn,
            isParticipant: isParticipant,
          ),
          const SizedBox(height: 2),
          if (gs.status == GameStatus.active &&
              gs.openingShowWhite != null &&
              gs.openingShowBlack != null &&
              gs.openingShowFirst != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: OpeningResultBanner(
                whiteDie: gs.openingShowWhite!,
                blackDie: gs.openingShowBlack!,
                firstPlayer: gs.openingShowFirst!,
                firstPlayerName: gs.openingShowFirst == PlayerColor.white
                    ? session.playerWhiteName
                    : session.playerBlackName,
              ),
            ),
          Expanded(
            child: LiveGameTable(
              state: gs,
              legalMoves: legalMoves,
              myColor: myColor,
              interactive: isParticipant,
              remainingDice: gs.remainingDice,
              canRoll: gs.remainingDice.isEmpty &&
                  gs.status == GameStatus.active &&
                  isMyTurn &&
                  isParticipant,
              onRoll: onRoll,
              onMove: onMove,
              showDice: !isOpeningRoll,
              headerPanel: isOpeningRoll
                  ? OpeningRollPanel(
                      openingRollWhite: gs.openingRollWhite,
                      openingRollBlack: gs.openingRollBlack,
                      myColor: myColor,
                      canRoll: canOpeningRoll,
                      onRoll: onOpeningRoll,
                    )
                  : null,
              canUndo: canUndo,
              onUndo: onUndo,
              statusMessage: _statusMessage(
                session: session,
                isParticipant: isParticipant,
                isMyTurn: isMyTurn,
                showBarWarning: showBarWarning,
                barCount: bar,
                bearOffCount: bearOffCount,
                turnName: turnName,
              ),
              statusIcon: _statusIcon(
                session: session,
                isParticipant: isParticipant,
                isMyTurn: isMyTurn,
                showBarWarning: showBarWarning,
                bearOffCount: bearOffCount,
              ),
              statusColor: _statusColor(
                context: context,
                session: session,
                isParticipant: isParticipant,
                isMyTurn: isMyTurn,
                showBarWarning: showBarWarning,
                bearOffCount: bearOffCount,
              ),
              whiteBorneOff: gs.borneOff[PlayerColor.white] ?? 0,
              blackBorneOff: gs.borneOff[PlayerColor.black] ?? 0,
            ),
          ),
          SizedBox(
            height: chatHeight,
            child: LiveGameChatPanel(
              roomId: roomId,
              session: session,
              canSend: isParticipant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player bar ──────────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.myName,
    required this.opponentName,
    required this.myColor,
    required this.session,
    required this.isMyTurn,
    required this.isParticipant,
  });

  final String myName;
  final String opponentName;
  final PlayerColor myColor;
  final GameSession session;
  final bool isMyTurn;
  final bool isParticipant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWhite = myColor == PlayerColor.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isMyTurn
              ? [
                  cs.primaryContainer.withValues(alpha: 0.4),
                  cs.surfaceContainerHighest.withValues(alpha: 0.5),
                ]
              : [
                  cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ],
        ),
        border: Border.all(
          color: isMyTurn
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.3),
          width: isMyTurn ? 1.5 : 1,
        ),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _playerChip(
            name: opponentName,
            isWhite: !isWhite,
            active: !isMyTurn,
            cs: cs,
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  !isParticipant
                      ? 'Bu macin oyuncusu degilsin'
                      : session.state.status == GameStatus.waiting
                          ? 'Rakip bekleniyor'
                          : (isMyTurn ? 'Senin siran' : 'Rakip oynuyor'),
                  key: ValueKey(
                      '${session.state.status.name}_${isMyTurn}_$isParticipant'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: !isParticipant
                        ? cs.error
                        : (isMyTurn ? cs.primary : cs.onSurfaceVariant),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          _playerChip(
            name: myName,
            isWhite: isWhite,
            active: isMyTurn,
            cs: cs,
          ),
        ],
      ),
    );
  }

  Widget _playerChip({
    required String name,
    required bool isWhite,
    required bool active,
    required ColorScheme cs,
  }) {
    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: active ? Border.all(color: cs.primary, width: 1.5) : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isWhite
                    ? [Colors.white, const Color(0xFFD0C8C0)]
                    : [const Color(0xFF444444), Colors.black],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isWhite ? const Color(0xFFD4AF37) : Colors.white38,
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 2),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name.length > 10 ? '${name.substring(0, 10)}...' : name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (active) {
      chip = chip
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.03,
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }

    return chip;
  }
}

class _TournamentMatchProgress extends StatelessWidget {
  const _TournamentMatchProgress({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p1Score = (data['player1Score'] as num?)?.toInt() ?? 0;
    final p2Score = (data['player2Score'] as num?)?.toInt() ?? 0;
    final target = (data['targetScore'] as num?)?.toInt() ?? 5;
    final p1Name = (data['player1Name'] as String?) ?? 'Oyuncu 1';
    final p2Name = (data['player2Name'] as String?) ?? 'Oyuncu 2';
    final isCompleted = data['status'] == 'completed';
    final gamesPlayed =
        ((data['games'] as List<dynamic>?)?.length ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.3),
            cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_outlined,
                  size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Turnuva Maci',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p1Name.length > 12
                    ? '${p1Name.substring(0, 12)}...'
                    : p1Name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$p1Score - $p2Score',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              Text(
                p2Name.length > 12
                    ? '${p2Name.substring(0, 12)}...'
                    : p2Name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isCompleted
                ? 'Mac Tamamlandi! ($gamesPlayed oyun oynandi)'
                : 'Hedef: $target puan | $gamesPlayed oyun oynandi',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }
}

String _statusMessage({
  required GameSession session,
  required bool isParticipant,
  required bool isMyTurn,
  required bool showBarWarning,
  required int barCount,
  required int bearOffCount,
  required String turnName,
}) {
  final gs = session.state;
  if (!isParticipant) return 'Bu odaya ait bir oyuncu degilsiniz.';
  if (gs.status == GameStatus.finished) {
    final winnerName = gs.winner == PlayerColor.white
        ? session.playerWhiteName
        : session.playerBlackName;
    return '$winnerName kazandi!';
  }
  if (gs.status == GameStatus.waiting) return 'Rakip bekleniyor...';
  if (showBarWarning) {
    return "Bar'da $barCount tas — once bar'dan cik";
  }
  if (isMyTurn && bearOffCount > 0) {
    return 'Tas cikar: sagdaki OFF bolgesine dokun';
  }
  if (isMyTurn && gs.remainingDice.isNotEmpty) {
    return 'Hamle yap veya tum zarlari kullan';
  }
  return '$turnName oynuyor...';
}

IconData _statusIcon({
  required GameSession session,
  required bool isParticipant,
  required bool isMyTurn,
  required bool showBarWarning,
  required int bearOffCount,
}) {
  final gs = session.state;
  if (!isParticipant) return Icons.block;
  if (gs.status == GameStatus.finished) return Icons.emoji_events;
  if (gs.status == GameStatus.waiting) return Icons.person_search;
  if (showBarWarning) return Icons.warning_amber;
  if (isMyTurn && bearOffCount > 0) return Icons.arrow_upward;
  if (isMyTurn && gs.remainingDice.isNotEmpty) return Icons.touch_app;
  return Icons.hourglass_bottom;
}

Color _statusColor({
  required BuildContext context,
  required GameSession session,
  required bool isParticipant,
  required bool isMyTurn,
  required bool showBarWarning,
  required int bearOffCount,
}) {
  final cs = Theme.of(context).colorScheme;
  final gs = session.state;
  if (!isParticipant) return cs.error;
  if (gs.status == GameStatus.finished) return Colors.amber;
  if (showBarWarning) return cs.error;
  if (isMyTurn && bearOffCount > 0) return Colors.greenAccent;
  return Colors.white70;
}
