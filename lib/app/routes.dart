import 'dart:ui';
import 'package:flutter/material.dart';

import '../features/properties/screens/properties_screen.dart';
import '../features/requirements/screens/requirements_screen.dart';
import '../features/account/screens/account_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const PropertiesScreen(),
    const RequirementsScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 12, right: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: (screenWidth * 0.58).clamp(200.0, 270.0),
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 177, 177, 177).withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color.fromARGB(255, 230, 230, 230).withValues(alpha: 0.28),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(
                        0,
                        Icons.real_estate_agent_outlined,
                        Icons.real_estate_agent,
                        'Properties',
                      ),
                      _buildNavItem(
                        1,
                        Icons.assignment_outlined,
                        Icons.assignment,
                        'Reqs',
                      ),
                      _buildNavItem(
                        2,
                        Icons.person_outline,
                        Icons.person,
                        'Account',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.72),
          size: 25,
        ),
      ),
    );
  }
}
