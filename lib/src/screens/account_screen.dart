import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user ?? {};
    final name = '${user['name'] ?? 'Traveler'}';
    final email = '${user['email'] ?? ''}';
    final isLoggedIn = auth.authenticated;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Your space'),
            backgroundColor: Colors.white,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList.list(
              children: [
                // Profile Header
                if (isLoggedIn) _ProfileHeader(name: name, email: email)
                else _GuestHeader(),
                const SizedBox(height: 28),

                // Journeys section
                Text('Your journeys', style: AppTextStyles.h3),
                const SizedBox(height: 14),
                _MenuGroup(
                  items: [
                    _MenuItem(
                      'My bookings',
                      'Upcoming and past tours',
                      Icons.calendar_month_rounded,
                      '/bookings',
                      AppColors.brand,
                      const Color(0xFFECFDF8),
                    ),
                    _MenuItem(
                      'Payments',
                      'Transactions and history',
                      Icons.account_balance_wallet_rounded,
                      '/payments',
                      const Color(0xFF7C3AED),
                      const Color(0xFFF5F3FF),
                    ),
                    _MenuItem(
                      'Wishlist',
                      'Tours you want to experience',
                      Icons.favorite_rounded,
                      '/wishlist',
                      const Color(0xFFDB2777),
                      const Color(0xFFFDF2F8),
                    ),
                  ],
                ),

                if (isLoggedIn) ...[
                  const SizedBox(height: 28),
                  Text('Community & planning', style: AppTextStyles.h3),
                  const SizedBox(height: 14),
                  _MenuGroup(
                    items: [
                      _MenuItem(
                        'My stories',
                        'Manage your 24-hour moments',
                        Icons.auto_stories_rounded,
                        '/stories',
                        const Color(0xFF0284C7),
                        const Color(0xFFEFF6FF),
                      ),
                      _MenuItem(
                        'Group trips',
                        'Plan adventures together',
                        Icons.groups_rounded,
                        '/group-trips',
                        const Color(0xFFEA580C),
                        const Color(0xFFFFF7ED),
                      ),
                      _MenuItem(
                        'Invitations',
                        'Trips your friends shared',
                        Icons.mark_email_unread_rounded,
                        '/invitations',
                        const Color(0xFF16A34A),
                        const Color(0xFFF0FDF4),
                      ),
                      _MenuItem(
                        'Blocked users',
                        'Manage your privacy',
                        Icons.shield_rounded,
                        '/blocked-users',
                        AppColors.muted,
                        AppColors.borderLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Sign out
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: AppColors.errorSoft,
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                ] else ...[
                  const SizedBox(height: 28),
                  _SignInPrompt(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});
  final String name, email;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF065F52), Color(0xFF0A7E6E), Color(0xFF0891B2)],
            stops: [0, 0.5, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: AppTextStyles.h2.copyWith(color: AppColors.brand),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WELCOME BACK',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: .7),
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3White,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmallWhite,
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.push('/profile'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .15),
                foregroundColor: Colors.white,
                minimumSize: const Size(40, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_outline_rounded, size: 48, color: AppColors.subtle),
          const SizedBox(height: 12),
          Text('Welcome to TravelLens', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Sign in to access your bookings, trips, and more.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/login'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.brand, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in required', style: AppTextStyles.label),
                const SizedBox(height: 3),
                Text(
                  'Access your community features after signing in.',
                  style: AppTextStyles.bodySmall,
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
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: .04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MenuRow(item: items[i]),
          if (i < items.length - 1)
            const Divider(height: 1, indent: 72),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.soft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(item.subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: AppColors.subtle,
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
