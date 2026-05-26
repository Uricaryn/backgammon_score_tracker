import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:backgammon_score_tracker/presentation/widgets/game_dice_panel.dart';
import 'package:backgammon_score_tracker/presentation/widgets/opening_roll_panel.dart';
import 'package:backgammon_score_tracker/presentation/widgets/opening_result_banner.dart';
import 'package:backgammon_score_tracker/presentation/widgets/interactive_backgammon_board.dart';

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

  @override
  void dispose() {
    _registerLeave();
    super.dispose();
  }

  void _registerLeave() {
    if (_leftRoom) return;
    _leftRoom = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _service.leaveRoom(roomId: widget.roomId, playerUid: user.uid);
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
          'Odadan ayrılmak istediğinize emin misiniz?\n\n'
          'Her iki oyuncu da ayrıldığında oda otomatik olarak silinir.',
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
        appBar: AppBar(
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
                  IconButton(
                    tooltip: 'Oyunu Sonlandır',
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    onPressed: () => _leaveGame(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: StreamBuilder<GameSession?>(
          stream: _service.watchRoom(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final session = snapshot.data;
            if (session == null) {
              // Room was deleted (both players left) — navigate back automatically.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
              return const Center(child: CircularProgressIndicator());
            }

          _saveSummaryIfFinished(session);
          _maybeShowEndDialog(context, session);

          final user = FirebaseAuth.instance.currentUser;
          final isParticipant = user != null &&
              (user.uid == session.playerWhiteId || user.uid == session.playerBlackId);
          final myColor = user?.uid == session.playerWhiteId
              ? PlayerColor.white
              : PlayerColor.black;

          final isOpeningRoll =
              session.state.status == GameStatus.openingRoll;
          final canOpeningRoll = isParticipant &&
              isOpeningRoll &&
              (myColor == PlayerColor.white
                  ? session.state.openingRollWhite == null
                  : session.state.openingRollBlack == null);

          final isMyTurn = isParticipant &&
              !isOpeningRoll &&
              session.state.currentTurn == myColor &&
              session.state.status == GameStatus.active;

          final legalMoves =
              (isMyTurn && isParticipant) ? _engine.legalMoves(session.state) : <Move>[];

          final canUndo = isMyTurn &&
              isParticipant &&
              _canUndoTurn(session.state);

          return _GameBody(
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
        },
        ),
      ),
    );
  }
}

// ── Game body ──────────────────────────────────────────────────────────────

class _GameBody extends StatelessWidget {
  const _GameBody({
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: isOpeningRoll
                ? OpeningRollPanel(
                    openingRollWhite: gs.openingRollWhite,
                    openingRollBlack: gs.openingRollBlack,
                    myColor: myColor,
                    canRoll: canOpeningRoll,
                    onRoll: onOpeningRoll,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GameDicePanel(
                          remainingDice: gs.remainingDice,
                          canRoll: gs.remainingDice.isEmpty &&
                              gs.status == GameStatus.active &&
                              isMyTurn &&
                              isParticipant,
                          onRoll: onRoll,
                        ),
                      ),
                      if (canUndo) ...[
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'Bu turdaki tum hamleleri geri al',
                          onPressed: onUndo,
                          icon: const Icon(Icons.undo, size: 22),
                        ),
                      ],
                    ],
                  ),
          ),
          Expanded(
            child: Center(
              child: InteractiveBackgammonBoard(
                state: gs,
                legalMoves: legalMoves,
                onMoveSelected: onMove,
                myColor: myColor,
                interactive: isParticipant,
              ),
            ),
          ),
          _StatusBar(
            turnName: turnName,
            isMyTurn: isMyTurn,
            showBarWarning: showBarWarning,
            barCount: bar,
            bearOffCount: bearOffCount,
            session: session,
            isParticipant: isParticipant,
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

// ── Status bar ──────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.turnName,
    required this.isMyTurn,
    required this.showBarWarning,
    required this.barCount,
    required this.bearOffCount,
    required this.session,
    required this.isParticipant,
  });

  final String turnName;
  final bool isMyTurn;
  final bool showBarWarning;
  final int barCount;
  final int bearOffCount;
  final GameSession session;
  final bool isParticipant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gs = session.state;

    String message;
    Color msgColor;
    IconData icon;

    if (!isParticipant) {
      message = 'Bu odaya ait bir oyuncu degilsiniz.';
      msgColor = cs.error;
      icon = Icons.block;
    } else if (gs.status == GameStatus.finished) {
      final winnerName = gs.winner == PlayerColor.white
          ? session.playerWhiteName
          : session.playerBlackName;
      message = '$winnerName kazandi!';
      msgColor = Colors.amber;
      icon = Icons.emoji_events;
    } else if (gs.status == GameStatus.waiting) {
      message = 'Rakip bekleniyor...';
      msgColor = cs.onSurfaceVariant;
      icon = Icons.person_search;
    } else if (showBarWarning) {
      message = "Bar'da $barCount tasin var — once bar'dan cik!";
      msgColor = cs.error;
      icon = Icons.warning_amber;
    } else if (isMyTurn && bearOffCount > 0) {
      message = 'Tasini cikarabilirsin! Sagdaki OFF bolgesine dokun.';
      msgColor = Colors.green;
      icon = Icons.arrow_upward;
    } else if (isMyTurn && gs.remainingDice.isNotEmpty) {
      message = 'Tahta uzerinde hamle yap veya tum zarlari kullan.';
      msgColor = cs.onSurfaceVariant;
      icon = Icons.touch_app;
    } else {
      message = '$turnName oynuyor...';
      msgColor = cs.onSurfaceVariant;
      icon = Icons.hourglass_bottom;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.5),
            cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _BorneOffBadge(
            white: gs.borneOff[PlayerColor.white] ?? 0,
            black: gs.borneOff[PlayerColor.black] ?? 0,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: msgColor),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                message,
                key: ValueKey(message),
                style: TextStyle(fontSize: 12, color: msgColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BorneOffBadge extends StatelessWidget {
  const _BorneOffBadge({required this.white, required this.black});

  final int white;
  final int black;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [Colors.white, Color(0xFFD0C8C0)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 0.8,
              ),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
            ),
          ),
          const SizedBox(width: 4),
          Text('$white/15',
              style: TextStyle(fontSize: 11, color: cs.onSurface, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [Color(0xFF444444), Colors.black],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Text('$black/15',
              style: TextStyle(fontSize: 11, color: cs.onSurface, fontWeight: FontWeight.w500)),
        ]),
      ],
    );
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
