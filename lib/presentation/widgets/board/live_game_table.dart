import 'dart:async';

import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/models/game_state.dart';
import 'package:backgammon_score_tracker/core/models/move.dart';
import 'package:backgammon_score_tracker/presentation/widgets/interactive_backgammon_board.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/animated_dice_roller.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_thrown_dice_overlay.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/board_layout.dart';
import 'package:backgammon_score_tracker/presentation/widgets/board/package_dice_panel.dart'
    show playDiceRollFlash;

/// Height of the status strip below the board (safe area, not on play surface).
const double kLiveGameStatusBarHeight = 40;

/// Felt table: dice strip → board → status strip (no overlays on checkers).
class LiveGameTable extends StatefulWidget {
  const LiveGameTable({
    super.key,
    required this.state,
    required this.legalMoves,
    required this.myColor,
    required this.interactive,
    required this.remainingDice,
    required this.canRoll,
    required this.onRoll,
    required this.onMove,
    required this.statusMessage,
    required this.statusIcon,
    required this.statusColor,
    required this.whiteBorneOff,
    required this.blackBorneOff,
    this.showDice = true,
    this.headerPanel,
    this.onUndo,
    this.canUndo = false,
  });

  final GameState state;
  final List<Move> legalMoves;
  final PlayerColor myColor;
  final bool interactive;
  final List<int> remainingDice;
  final bool canRoll;
  final VoidCallback onRoll;
  final ValueChanged<Move> onMove;
  final String statusMessage;
  final IconData statusIcon;
  final Color statusColor;
  final int whiteBorneOff;
  final int blackBorneOff;
  final bool showDice;
  /// Optional panel above the board (e.g. opening roll) — uses safe strip, not overlay.
  final Widget? headerPanel;
  final VoidCallback? onUndo;
  final bool canUndo;

  @override
  State<LiveGameTable> createState() => _LiveGameTableState();
}

class _LiveGameTableState extends State<LiveGameTable> {
  bool _rolling = false;
  List<int> _flashDice = [];
  int _diceSnapshotVersion = -1;
  bool _hydratedFromServer = false;

  @override
  void initState() {
    super.initState();
    _hydrateDiceFromServer();
  }

  void _hydrateDiceFromServer() {
    _flashDice = List<int>.from(widget.remainingDice);
    _diceSnapshotVersion = widget.state.version;
    _hydratedFromServer = true;
  }

  @override
  void didUpdateWidget(LiveGameTable old) {
    super.didUpdateWidget(old);
    final newDice = widget.remainingDice;
    final oldDice = old.remainingDice;
    if (newDice.isNotEmpty && oldDice.isEmpty && _hydratedFromServer) {
      _diceSnapshotVersion = widget.state.version;
      if (!_rolling) {
        _playRoll(newDice);
      } else {
        setState(() => _flashDice = List<int>.from(newDice));
      }
      return;
    }
    if (newDice != oldDice) {
      setState(() => _flashDice = List<int>.from(newDice));
      _diceSnapshotVersion = widget.state.version;
    }
  }

  void _onUserRollTap() {
    if (_rolling || !widget.canRoll || widget.remainingDice.isNotEmpty) {
      return;
    }
    unawaited(_playRoll(const [1, 1]));
    widget.onRoll();
  }

  Future<void> _playRoll(List<int> finalDice) async {
    setState(() => _rolling = true);
    await Future.wait([
      playDiceRollFlash(
        finalDice: finalDice,
        isMounted: () => mounted,
        onFlash: (f) {
          if (!mounted) return;
          setState(() => _flashDice = f);
        },
      ),
      Future.delayed(const Duration(milliseconds: 1050)),
    ]);
    if (!mounted) return;
    final resolved = widget.remainingDice.isNotEmpty
        ? widget.remainingDice
        : finalDice;
    setState(() {
      _flashDice = List<int>.from(resolved);
      _rolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayDice = _rolling ? _flashDice : widget.remainingDice;

    return ColoredBox(
      color: const Color(0xFF142e18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.headerPanel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: widget.headerPanel!,
            )
          else if (widget.showDice)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: _DiceStrip(
                displayDice: displayDice,
                isRolling: _rolling,
                canRoll: widget.canRoll,
                onRoll: _onUserRollTap,
                showRollButton: widget.interactive,
                canUndo: widget.canUndo,
                onUndo: widget.onUndo,
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = computeBoardSizeLiveFill(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Center(
                  child: SizedBox(
                    width: boardSize.width,
                    height: boardSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InteractiveBackgammonBoard(
                          state: widget.state,
                          legalMoves: widget.legalMoves,
                          onMoveSelected: widget.onMove,
                          myColor: widget.myColor,
                          interactive: widget.interactive,
                          boardSize: boardSize,
                        ),
                        BoardThrownDiceOverlay(
                          boardSize: boardSize,
                          targetValues: displayDice,
                          isRolling: _rolling,
                          rollingPlayer: widget.state.currentTurn,
                          viewerColor: widget.myColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            child: LiveGameStatusBar(
              message: widget.statusMessage,
              icon: widget.statusIcon,
              color: widget.statusColor,
              whiteOff: widget.whiteBorneOff,
              blackOff: widget.blackBorneOff,
            ),
          ),
        ],
      ),
    );
  }
}

/// Turn info + borne-off counts — sits below the board, above chat.
class LiveGameStatusBar extends StatelessWidget {
  const LiveGameStatusBar({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    required this.whiteOff,
    required this.blackOff,
  });

  final String message;
  final IconData icon;
  final Color color;
  final int whiteOff;
  final int blackOff;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kLiveGameStatusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _OffChip(count: whiteOff, isWhite: true),
          const SizedBox(width: 6),
          _OffChip(count: blackOff, isWhite: false),
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dice in the top safe strip — never on the play surface.
class _DiceStrip extends StatelessWidget {
  const _DiceStrip({
    required this.displayDice,
    required this.isRolling,
    required this.canRoll,
    required this.onRoll,
    required this.showRollButton,
    required this.canUndo,
    this.onUndo,
  });

  final List<int> displayDice;
  final bool isRolling;
  final bool canRoll;
  final VoidCallback onRoll;
  final bool showRollButton;
  final bool canUndo;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DiceControlStrip(
            canRoll: canRoll,
            onRollTap: onRoll,
            isRolling: isRolling,
            hasDiceOnBoard: displayDice.isNotEmpty,
            showRollButton: showRollButton,
            compact: true,
          ),
        ),
        if (canUndo && onUndo != null) ...[
          const SizedBox(width: 4),
          Material(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            child: IconButton(
              tooltip: 'Bu turdaki tum hamleleri geri al',
              onPressed: onUndo,
              icon: const Icon(Icons.undo, color: Colors.white, size: 20),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }
}

class _OffChip extends StatelessWidget {
  const _OffChip({required this.count, required this.isWhite});

  final int count;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isWhite
                  ? [Colors.white, const Color(0xFFE0D8D0)]
                  : [const Color(0xFF555555), const Color(0xFF111111)],
            ),
            border: Border.all(
              color: isWhite ? const Color(0xFFC9A227) : Colors.white24,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
