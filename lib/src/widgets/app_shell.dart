import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  static const paths = [
    '/home',
    '/destinations',
    '/tours',
    '/travel-feed',
    '/account',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    var index = paths.indexWhere((path) => location.startsWith(path));
    if (index < 0) index = 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: _FloatingNavBar(currentIndex: index),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xF8FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withValues(alpha: .6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: .10),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .04),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == currentIndex;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: item.label,
                child: GestureDetector(
                  onTap: () => context.go(AppShell.paths[i]),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brand.withValues(alpha: .1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            selected ? item.selectedIcon : item.icon,
                            key: ValueKey(selected),
                            size: 22,
                            color: selected ? AppColors.brand : AppColors.subtle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                            color: selected ? AppColors.brand : AppColors.subtle,
                          ),
                          child: Text(item.label, maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

const _items = [
  _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
  _NavItem('Explore', Icons.explore_outlined, Icons.explore_rounded),
  _NavItem('Tours', Icons.luggage_outlined, Icons.luggage_rounded),
  _NavItem('Feed', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded),
  _NavItem('You', Icons.person_outline_rounded, Icons.person_rounded),
];
