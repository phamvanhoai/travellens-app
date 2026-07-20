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
        extendBody: false,
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
      top: false,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: .04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
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
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            selected ? item.selectedIcon : item.icon,
                            key: ValueKey(selected),
                            size: 21,
                            color: selected ? AppColors.brand : AppColors.subtle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.inter(
                            fontSize: 9,
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
  _NavItem('Trang chủ', Icons.home_outlined, Icons.home_rounded),
  _NavItem('Khám phá', Icons.search_rounded, Icons.search_rounded),
  _NavItem('Chuyến đi', Icons.card_travel_outlined, Icons.card_travel_rounded),
  _NavItem('Cộng đồng', Icons.groups_outlined, Icons.groups_rounded),
  _NavItem('Cá nhân', Icons.person_outline_rounded, Icons.person_rounded),
];
