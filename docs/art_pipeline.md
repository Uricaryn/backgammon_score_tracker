# Backgammon board visuals

Hybrid stack: **CustomPaint board** for gameplay, **pub packages** for dice and celebration, optional **PNG sprites** for checkers.

## Packages (no custom animation files)

| Feature | Package | Notes |
|---------|---------|--------|
| Dice faces | [`roll_dice_2d`](https://pub.dev/packages/roll_dice_2d) | Red/white PNGs 1–6 bundled in the package; used by `PackageDiceRow` |
| Win celebration | [`confetti`](https://pub.dev/packages/confetti) | Particle burst on `GameStatus.finished` |
| Hit (blot) | Built-in | `_HitBurstPainter` in `board_effects_overlay.dart` |
| Piece motion | Built-in | Arc + squash in `animated_piece_overlay.dart` |
| Dice roll feel | [`flutter_animate`](https://pub.dev/packages/flutter_animate) | Tumble during roll flash |

Dice values always come from the game server (`remainingDice`); packages only control **how** faces are drawn, not the outcome.

## Optional checker sprites (no Blender required)

Drop PNGs in [`assets/sprites/checkers/`](../assets/sprites/checkers/):

- `checker_white.png`
- `checker_black.png`

If missing, checkers use gradient discs via `paintChecker` in [`checker_painter.dart`](../lib/presentation/widgets/board/checker_painter.dart).

## Optional: richer art later

- **Lottie** ([`lottie`](https://pub.dev/packages/lottie)) + one free JSON from [LottieFiles](https://lottiefiles.com/free-animations) if you want a fancier hit effect (single download, not authoring from scratch).
- **Blender** ortho renders — only if you want custom checker sprites; see previous checklist in git history.

## Layout code

[`lib/presentation/widgets/board/board_layout.dart`](../lib/presentation/widgets/board/board_layout.dart)

- `kPieceMoveMs` (320)
- `boardArcPosition`, `boardLandingScaleY`

## Accessibility

`MediaQuery.disableAnimations` skips confetti play and piece flight.
