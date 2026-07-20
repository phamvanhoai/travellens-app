import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7ECF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Row(
            children: List.generate(_items.length, (itemIndex) {
              final item = _items[itemIndex];
              final selected = itemIndex == index;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => context.go(paths[itemIndex]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFCCFBF1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? item.selectedIcon : item.icon,
                            size: 21,
                            color: selected
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF64748B),
                            ),
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
  _NavItem(
    'Feed',
    Icons.auto_awesome_mosaic_outlined,
    Icons.auto_awesome_mosaic_rounded,
  ),
  _NavItem('You', Icons.person_outline_rounded, Icons.person_rounded),
];
