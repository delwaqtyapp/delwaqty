import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// One step in a [FeatureTourPage] walkthrough.
class FeatureTourStep {
  const FeatureTourStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// A polished, animated first-use tour: gradient background that cross-fades
/// per step, paged slides, dot indicator, skip and next/done actions.
///
/// Visual language intentionally mirrors the pre-login onboarding carousel so
/// the first-run experience feels like one continuous flow. Shown once per
/// install via `FeatureTourGate`, replayable anywhere by pushing it directly.
class FeatureTourPage extends StatefulWidget {
  const FeatureTourPage({super.key, required this.steps, required this.onDone});

  final List<FeatureTourStep> steps;
  final VoidCallback onDone;

  @override
  State<FeatureTourPage> createState() => _FeatureTourPageState();
}

class _FeatureTourPageState extends State<FeatureTourPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _previousPage = 0;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onTint = theme.colorScheme.onPrimary;
    final step = widget.steps[_currentPage];
    final isLast = _currentPage == widget.steps.length - 1;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final fromColor = Color.lerp(
            widget.steps[_previousPage].color,
            widget.steps[_currentPage].color,
            _bgController.value,
          )!;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  fromColor,
                  fromColor.withValues(alpha: 0.75),
                  fromColor.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8, end: 16),
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: Text(
                      l10n.onboardingSkip,
                      style: TextStyle(
                        color: onTint.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.steps.length,
                  onPageChanged: (index) {
                    setState(() {
                      _previousPage = _currentPage;
                      _currentPage = index;
                    });
                    _bgController.forward(from: 0);
                  },
                  itemBuilder: (context, index) {
                    final s = widget.steps[index];
                    // Adaptive slide: the icon disc scales with the screen
                    // instead of a fixed 132px, gaps shrink on short
                    // screens, and the whole slide scrolls so large text
                    // scales, landscape and narrow RTL layouts can never
                    // overflow. Skip stays pinned above, dots and the
                    // Next/Done button stay pinned below.
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final shortest = MediaQuery.of(context)
                            .size
                            .shortestSide;
                        final disc = (shortest * 0.26).clamp(64.0, 132.0);
                        final horizontal = constraints.maxWidth < 360
                            ? 20.0
                            : 32.0;
                        final gap = constraints.maxHeight < 480 ? 16.0 : 36.0;
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: horizontal),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: disc,
                                  height: disc,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    s.icon,
                                    size: disc * 0.47,
                                    color: onTint,
                                  ),
                                ),
                                SizedBox(height: gap),
                                Text(
                                  s.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: onTint,
                                      ),
                                ),
                                SizedBox(height: gap * 0.4),
                                Text(
                                  s.body,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: onTint.withValues(alpha: 0.92),
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? onTint : onTint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: step.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _next,
                    child: Text(
                      isLast ? l10n.onboardingDone : l10n.onboardingNext,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
