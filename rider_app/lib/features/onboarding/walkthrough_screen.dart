import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';

class _Slide {
  const _Slide(this.image, this.title, this.body);
  final String image;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    'assets/images/walkthrough_1.jpg',
    'Welcome to GoRide - Your Journey, Your Way',
    'Get ready to experience hassle-free transportation. We\'ve got everything you need to travel with ease. Let\'s get started!',
  ),
  _Slide(
    'assets/images/walkthrough_2.jpg',
    'Choose Your Ride - Tailored to Your Needs',
    'Select your preferred mode of transportation - bike, keke or car - and order a ride with just a few taps.',
  ),
  _Slide(
    'assets/images/walkthrough_3.jpg',
    'Secure Payments & Seamless Transactions',
    'Pay for your rides your way: GoRide Wallet, card, bank transfer or cash. Every fare is shown upfront in Naira.',
  ),
];

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  void _next() {
    if (_isLast) {
      context.go(Routes.welcome);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final imageHeight = size.height * 0.52;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Column(
                    children: [
                      Container(
                        color: AppColors.primary,
                        height: MediaQuery.paddingOf(context).top,
                      ),
                      SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: Image.asset(
                          s.image,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                s.body,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: _slides.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: AppColors.primary,
                dotColor: Color(0xFFE0E0E0),
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 4,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: _isLast
                    ? AppButton(label: 'Let\'s Get Started', onPressed: _next)
                    : Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Skip',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => context.go(Routes.welcome),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'Continue',
                              onPressed: _next,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
