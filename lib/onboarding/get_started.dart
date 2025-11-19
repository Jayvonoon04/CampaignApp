import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Connect with Causes',
      description: 'Discover meaningful charities and organizations that align with your values and passions.',
      imagePath: 'assets/img/connect.png',
      color: Color(0xFF6C63FF),
    ),
    OnboardingItem(
      title: 'Make an Impact',
      description: 'Your donations directly support those in need with complete transparency.',
      imagePath: 'assets/img/impact.png',
      color: Color(0xFF4A90E2),
    ),
    OnboardingItem(
      title: 'Join the Movement',
      description: 'Become part of a community dedicated to creating positive change in the world.',
      imagePath: 'assets/img/join.png',
      color: Color(0xFF00BFA6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _onboardingItems[_currentPage].color.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
          ),

          // PageView Content
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingItems.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return SingleOnboardingPage(item: _onboardingItems[index]);
            },
          ),

          // Overlapping Page Indicator
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _onboardingItems.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: _onboardingItems[_currentPage].color,
                  dotColor: Colors.grey.withOpacity(0.4),
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                  spacing: 8,
                ),
              ),
            ),
          ),

          // Next Button
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 56,
              decoration: BoxDecoration(
                color: _onboardingItems[_currentPage].color,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _onboardingItems[_currentPage].color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  )],
              ),
              child: TextButton(
                onPressed: () {
                  if (_currentPage == _onboardingItems.length - 1) {
                    // Navigate to main app
                    Navigator.pushReplacementNamed(context, '/login');
                  } else {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  _currentPage == _onboardingItems.length - 1 ? 'Get Started' : 'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Skip Button (only visible on first two pages)
          if (_currentPage < _onboardingItems.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: TextButton(
                onPressed: () {
                  _pageController.animateToPage(
                    _onboardingItems.length - 1,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String imagePath;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.color,
  });
}

class SingleOnboardingPage extends StatelessWidget {
  final OnboardingItem item;

  const SingleOnboardingPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Image Container
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(item.imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 40),
          // Title
          Text(
            item.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          // Description
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}