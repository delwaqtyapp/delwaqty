import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveBool(key: StorageKeys.onboardingComplete, value: true);
    if (mounted) {
      context.go('/welcome');
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    l10n.onboardingSkip,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingContent(
                      key: ValueKey(index),
                      index: index,
                      l10n: l10n,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _totalPages,
                        (index) => _buildDot(index, context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSlideIn(
                      beginOffset: const Offset(0, 0.2),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _nextPage,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _currentPage == _totalPages - 1
                                ? l10n.onboardingDone
                                : l10n.onboardingNext,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? context.colorScheme.primary
            : context.colorScheme.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.index,
    required this.l10n,
    super.key,
  });

  final int index;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final titles = [
      l10n.onboardingTitle1,
      l10n.onboardingTitle2,
      l10n.onboardingTitle3,
      l10n.onboardingTitle4,
    ];
    final descriptions = [
      l10n.onboardingDesc1,
      l10n.onboardingDesc2,
      l10n.onboardingDesc3,
      l10n.onboardingDesc4,
    ];
    final icons = [
      Icons.account_balance_wallet_rounded,
      Icons.pie_chart_rounded,
      Icons.bar_chart_rounded,
      Icons.shield_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedFadeIn(
            duration: const Duration(milliseconds: 800),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[index],
                size: 80,
                color: context.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 48),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              titles[index],
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 400),
            child: Text(
              descriptions[index],
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
