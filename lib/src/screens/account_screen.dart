import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user ?? {};
    final name = '${user['name'] ?? 'Traveler'}';
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Your space')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F766E), Color(0xFF0891B2)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2B0F766E),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: Colors.white70, width: 3),
                        ),
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF0F766E),
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WELCOME BACK',
                              style: TextStyle(
                                color: Color(0xFF99F6E4),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.5,
                              ),
                            ),
                            Text(
                              '${user['email'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD5FAF5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context.push('/profile'),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your journeys',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 12),
                const _MenuGroup(
                  items: [
                    _MenuItem(
                      'My bookings',
                      'Upcoming and previous tours',
                      Icons.calendar_month_rounded,
                      '/bookings',
                      Color(0xFF0F766E),
                      Color(0xFFCCFBF1),
                    ),
                    _MenuItem(
                      'Payments',
                      'Transactions and payment status',
                      Icons.account_balance_wallet_rounded,
                      '/payments',
                      Color(0xFF7C3AED),
                      Color(0xFFEDE9FE),
                    ),
                    _MenuItem(
                      'Wishlist',
                      'Tours you want to experience',
                      Icons.favorite_rounded,
                      '/wishlist',
                      Color(0xFFDB2777),
                      Color(0xFFFCE7F3),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Community & planning',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 12),
                const _MenuGroup(
                  items: [
                    _MenuItem(
                      'My stories',
                      'Manage your 24-hour moments',
                      Icons.auto_stories_rounded,
                      '/stories',
                      Color(0xFF0284C7),
                      Color(0xFFE0F2FE),
                    ),
                    _MenuItem(
                      'Group trips',
                      'Plan adventures together',
                      Icons.groups_rounded,
                      '/group-trips',
                      Color(0xFFEA580C),
                      Color(0xFFFFEDD5),
                    ),
                    _MenuItem(
                      'Invitations',
                      'Trips your friends shared',
                      Icons.mark_email_unread_rounded,
                      '/invitations',
                      Color(0xFF16A34A),
                      Color(0xFFDCFCE7),
                    ),
                    _MenuItem(
                      'Blocked users',
                      'Manage your privacy',
                      Icons.shield_rounded,
                      '/blocked-users',
                      Color(0xFF475569),
                      Color(0xFFE2E8F0),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFDA4AF)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE8EDF3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MenuRow(item: items[i]),
          if (i < items.length - 1) const Divider(indent: 72),
        ],
      ],
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final _MenuItem item;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(item.path),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: item.soft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    ),
  );
}

class _MenuItem {
  const _MenuItem(
    this.title,
    this.subtitle,
    this.icon,
    this.path,
    this.color,
    this.soft,
  );
  final String title, subtitle, path;
  final IconData icon;
  final Color color, soft;
}
