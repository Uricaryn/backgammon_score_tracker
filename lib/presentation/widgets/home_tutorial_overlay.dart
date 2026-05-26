import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Tek adımlık coach mark: hedefe kaydır, konumu ölç, spotlight + tooltip göster.
class HomeTutorialOverlay extends StatefulWidget {
  const HomeTutorialOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.totalSteps,
    required this.scrollController,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.preferTooltipAbove = false,
    this.scrollToEndFirst = false,
    this.scrollAlignment = 0.08,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final int stepIndex;
  final int totalSteps;
  final ScrollController scrollController;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final bool preferTooltipAbove;
  final bool scrollToEndFirst;

  /// [Scrollable.ensureVisible] hizası; üstteki kartlar için düşük tutulur.
  final double scrollAlignment;

  @override
  State<HomeTutorialOverlay> createState() => _HomeTutorialOverlayState();
}

class _HomeTutorialOverlayState extends State<HomeTutorialOverlay> {
  Rect? _targetRect;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _prepareStep());
  }

  @override
  void didUpdateWidget(covariant HomeTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.stepIndex != widget.stepIndex) {
      setState(() {
        _ready = false;
        _targetRect = null;
      });
      SchedulerBinding.instance.addPostFrameCallback((_) => _prepareStep());
    }
  }

  Future<void> _prepareStep() async {
    if (widget.scrollToEndFirst && widget.scrollController.hasClients) {
      await widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
      await _waitFrames(2);
    }

    final targetContext = widget.targetKey.currentContext;
    if (targetContext != null && targetContext.mounted) {
      if (!_isTargetVisibleEnough(targetContext)) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOut,
          alignment: widget.scrollAlignment,
          alignmentPolicy: widget.scrollToEndFirst
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    }

    await _waitFrames(2);
    if (!mounted) return;

    _measureTarget();
    if (_targetRect != null && mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _waitFrames(int count) async {
    for (var i = 0; i < count; i++) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  bool _isTargetVisibleEnough(BuildContext targetContext) {
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final media = MediaQuery.of(targetContext);
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const appBarHeight = kToolbarHeight;
    final viewTop = media.padding.top + appBarHeight;
    final viewBottom = media.size.height - media.padding.bottom - 72;
    return top >= viewTop - 12 && bottom <= viewBottom + 12;
  }

  void _measureTarget() {
    final targetBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (targetBox == null ||
        !targetBox.hasSize ||
        overlayBox == null ||
        !overlayBox.hasSize) {
      _targetRect = null;
      return;
    }

    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = targetBox.localToGlobal(
      targetBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    _targetRect = Rect.fromPoints(topLeft, bottomRight);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _targetRect == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final screen = media.size;
    final padding = media.padding;
    final hole = _targetRect!.inflate(4);
    final tooltipSpace = 200.0;
    final showAbove = widget.preferTooltipAbove ||
        hole.bottom + tooltipSpace > screen.height - padding.bottom - 72;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TutorialHolePainter(hole: hole),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
          ),
          Positioned(
            left: hole.left,
            top: hole.top,
            width: hole.width,
            height: hole.height,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          _TooltipCard(
            hole: hole,
            screen: screen,
            padding: padding,
            showAbove: showAbove,
            title: widget.title,
            description: widget.description,
            stepIndex: widget.stepIndex,
            totalSteps: widget.totalSteps,
            onNext: widget.onNext,
            onPrevious: widget.onPrevious,
            onSkip: widget.onSkip,
          ),
        ],
      ),
    );
  }
}

class _TutorialHolePainter extends CustomPainter {
  _TutorialHolePainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.72));
  }

  @override
  bool shouldRepaint(covariant _TutorialHolePainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.hole,
    required this.screen,
    required this.padding,
    required this.showAbove,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  final Rect hole;
  final Size screen;
  final EdgeInsets padding;
  final bool showAbove;
  final String title;
  final String description;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    const horizontalMargin = 16.0;
    const gap = 12.0;
    const maxTooltipHeight = 200.0;
    final cardWidth = screen.width - horizontalMargin * 2;
    final cs = Theme.of(context).colorScheme;

    double top;
    if (showAbove) {
      top = (hole.top - gap - maxTooltipHeight).clamp(
        padding.top + 8,
        hole.top - gap - 72,
      );
    } else {
      top = (hole.bottom + gap).clamp(
        hole.bottom + gap,
        screen.height - padding.bottom - maxTooltipHeight - 16,
      );
    }

    final isLast = stepIndex >= totalSteps - 1;

    return Positioned(
      left: horizontalMargin,
      top: top,
      width: cardWidth,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text(
                    '${stepIndex + 1} / $totalSteps',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  TextButton(onPressed: onSkip, child: const Text('Atla')),
                  if (stepIndex > 0)
                    TextButton(
                      onPressed: onPrevious,
                      child: const Text('Geri'),
                    ),
                  FilledButton(
                    onPressed: onNext,
                    child: Text(isLast ? 'Bitir' : 'İleri'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
