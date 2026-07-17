import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;

  late final AnimationController _enterController;
  late final AnimationController _bgController;
  late final Animation<double> _enterScale;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _enterScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.elasticOut),
    );
    _enterController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _enterController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    await sharedPrefs.saveBool(
      key: StorageKeys.onboardingComplete,
      value: true,
    );
    if (mounted) context.go('/welcome');
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final slides = _OnboardingSlides.get(l10n);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final fromColor = _bgController.value < 0.5
              ? _getColor(_currentPage)
              : _getColor(_currentPage);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fromColor,
                  fromColor.withValues(alpha: 0.7),
                  theme.colorScheme.surface,
                ],
                stops: const [0.0, 0.5, 1.0],
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
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      l10n.onboardingSkip,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
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
                    _enterController
                      ..reset()
                      ..forward();
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingSlideWidget(
                      slide: slides[index],
                      index: index,
                      enterController: _enterController,
                      enterScale: _enterScale,
                    );
                  },
                ),
              ),
              _buildBottomSection(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(int index) {
    const colors = [
      Color(0xFF6750A4),
      Color(0xFFE65100),
      Color(0xFF2E7D32),
      Color(0xFF0288D1),
      Color(0xFFAD1457),
      Color(0xFF6750A4),
    ];
    return colors[index % colors.length];
  }

  Widget _buildBottomSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (i) => _buildDot(i)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _nextPage,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _getColor(_currentPage),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                elevation: 0,
              ),
              child: Text(
                _currentPage == _totalPages - 1
                    ? l10n.onboardingDone
                    : l10n.onboardingNext,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.illustration,
  });

  final String title;
  final String description;
  final IconData icon;
  final String illustration;
}

class _OnboardingSlides {
  static List<_OnboardingSlideData> get(AppLocalizations l10n) => [
        _OnboardingSlideData(
          title: l10n.onboardingTitle1,
          description: l10n.onboardingDesc1,
          icon: Icons.auto_awesome_rounded,
          illustration: '✨',
        ),
        _OnboardingSlideData(
          title: l10n.onboardingTitle2,
          description: l10n.onboardingDesc2,
          icon: Icons.restaurant_rounded,
          illustration: '🍕',
        ),
        _OnboardingSlideData(
          title: l10n.onboardingTitle6,
          description: l10n.onboardingDesc6,
          icon: Icons.shopping_bag_rounded,
          illustration: '🛍️',
        ),
        _OnboardingSlideData(
          title: l10n.onboardingTitle3,
          description: l10n.onboardingDesc3,
          icon: Icons.home_repair_service_rounded,
          illustration: '🔧',
        ),
        _OnboardingSlideData(
          title: l10n.onboardingTitle4,
          description: l10n.onboardingDesc4,
          icon: Icons.delivery_dining_rounded,
          illustration: '📍',
        ),
        _OnboardingSlideData(
          title: l10n.onboardingTitle5,
          description: l10n.onboardingDesc5,
          icon: Icons.rocket_launch_rounded,
          illustration: '🚀',
        ),
      ];
}

class _OnboardingSlideWidget extends StatelessWidget {
  const _OnboardingSlideWidget({
    required this.slide,
    required this.index,
    required this.enterController,
    required this.enterScale,
  });

  final _OnboardingSlideData slide;
  final int index;
  final AnimationController enterController;
  final Animation<double> enterScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: enterScale,
            builder: (context, child) {
              return Transform.scale(
                scale: enterScale.value,
                child: child,
              );
            },
            child: Text(
              slide.illustration,
              style: const TextStyle(fontSize: 80),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: enterScale,
            builder: (context, child) {
              return Opacity(
                opacity: enterScale.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - enterScale.value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(slide.icon, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: enterScale,
            builder: (context, child) {
              return Opacity(
                opacity: enterScale.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - enterScale.value)),
                  child: child,
                ),
              );
            },
            child: Text(
              slide.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: enterScale,
            builder: (context, child) {
              return Opacity(
                opacity: (enterScale.value * 0.85).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - enterScale.value)),
                  child: child,
                ),
              );
            },
            child: Text(
              slide.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
