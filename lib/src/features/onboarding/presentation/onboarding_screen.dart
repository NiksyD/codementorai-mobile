import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common_widgets/hero_animations.dart';
import '../../../constants/app_colors.dart';
import '../../../theme/theme_mode_controller.dart';

class OnboardingItem {
  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.heroWidget,
  });

  final String title;
  final String subtitle;
  final String description;
  final Widget heroWidget;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingItem> _items = <OnboardingItem>[
    OnboardingItem(
      subtitle: 'INTELLIGENT ASSISTANCE',
      title: 'Real-Time AI Mentorship',
      description:
          'Experience 24/7 pair programming. Get instant code reviews, automated bug detection, and architectural guidance.',
      heroWidget: AIMentorChatHeroStage(),
    ),
    OnboardingItem(
      subtitle: 'HANDS-ON CODING',
      title: 'Interactive Code Sandbox',
      description:
          'Solve real-world challenges with multi-language execution powered by our Judge0 engine right from your phone.',
      heroWidget: CodeSandboxHeroStage(),
    ),
    OnboardingItem(
      subtitle: 'VISUAL GROWTH',
      title: 'Skill Radar Analytics',
      description:
          'Track your technical mastery across algorithms, system design, and clean code with visual radar insights.',
      heroWidget: SkillRadarGridHeroStage(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Column(
            children: <Widget>[
              // Header Bar: Brand Logo & Theme Mode Switch ONLY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(width: 10.0),
                      Text(
                        'CodeMentor AI',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  // Header Theme Switch Only
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceCard
                          : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.all(6.0),
                      constraints: const BoxConstraints(),
                      onPressed: () => themeModeController.toggleTheme(),
                      icon: Icon(
                        isDark
                            ? Icons.wb_sunny_rounded
                            : Icons.dark_mode_rounded,
                        size: 18.0,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : AppColors.primary,
                      ),
                      tooltip: isDark
                          ? 'Switch to Light Mode'
                          : 'Switch to Dark Mode',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Zero-Flicker Full-Bleed Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final OnboardingItem item = _items[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // Hero Stage
                        Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              height: 240,
                              width: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    AppColors.primary.withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            item.heroWidget,
                          ],
                        ),
                        const SizedBox(height: 32.0),

                        // Pill Badge Category
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // Bold Modern Minimal Headline
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 28.0,
                                letterSpacing: -0.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14.0),

                        // Subtitle with Generous Line-Height
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            item.description,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize: 15.0,
                                  height: 1.6,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20.0),

              // Dynamic Indicators & Action Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Animated Indicator Pills
                  Row(
                    children: List<Widget>.generate(
                      _items.length,
                      (int index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6.0),
                        height: 8.0,
                        width: _currentPage == index ? 28.0 : 8.0,
                        decoration: BoxDecoration(
                          gradient: _currentPage == index
                              ? AppColors.primaryGradient
                              : null,
                          color: _currentPage == index
                              ? null
                              : (isDark
                                    ? AppColors.darkSurfaceCard
                                    : AppColors.lightSurfaceCard),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons (Skip & Next/Get Started)
                  Row(
                    children: <Widget>[
                      if (_currentPage < _items.length - 1) ...<Widget>[
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                      ],

                      // Primary Action Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 18.0,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28.0,
                              vertical: 16.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _currentPage == _items.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18.0,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
