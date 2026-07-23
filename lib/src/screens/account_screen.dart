import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';
import '../config/app_config.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user ?? {};
    final name = '${user['name'] ?? 'Khách du lịch'}';
    final email = '${user['email'] ?? ''}';
    final avatar = AppConfig.assetUrl(
      '${user['avatar_url'] ?? user['avatar'] ?? ''}',
    );
    final isLoggedIn = auth.authenticated;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Không gian của bạn'),
            backgroundColor: Colors.white,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 92),
            sliver: SliverList.list(
              children: [
                // Profile Header
                if (isLoggedIn)
                  _ProfileHeader(name: name, email: email, avatar: avatar)
                else
                  _GuestHeader(),
                const SizedBox(height: 20),

                // Journeys section
                const _SectionTitle('Hành trình của bạn'),
                const SizedBox(height: 9),
                _MenuGroup(
                  items: [
                    _MenuItem(
                      'Booking của tôi',
                      'Tour sắp tới và đã tham gia',
                      Icons.calendar_month_rounded,
                      '/bookings',
                      AppColors.brand,
                      const Color(0xFFECFDF8),
                    ),
                    _MenuItem(
                      'Thanh toán',
                      'Giao dịch và lịch sử thanh toán',
                      Icons.account_balance_wallet_rounded,
                      '/payments',
                      const Color(0xFF7C3AED),
                      const Color(0xFFF5F3FF),
                    ),
                    _MenuItem(
                      'Yêu thích',
                      'Tour và điểm đến bạn đã lưu',
                      Icons.favorite_rounded,
                      '/wishlist',
                      const Color(0xFFDB2777),
                      const Color(0xFFFDF2F8),
                    ),
                  ],
                ),

                if (isLoggedIn) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Cộng đồng và kế hoạch'),
                  const SizedBox(height: 9),
                  _MenuGroup(
                    items: [
                      _MenuItem(
                        'Tin của tôi',
                        'Quản lý khoảnh khắc trong 24 giờ',
                        Icons.auto_stories_rounded,
                        '/stories',
                        const Color(0xFF0284C7),
                        const Color(0xFFEFF6FF),
                      ),
                      _MenuItem(
                        'Chuyến đi nhóm',
                        'Cùng nhau lên kế hoạch hành trình',
                        Icons.groups_rounded,
                        '/group-trips',
                        const Color(0xFFEA580C),
                        const Color(0xFFFFF7ED),
                      ),
                      _MenuItem(
                        'Lời mời',
                        'Chuyến đi bạn bè chia sẻ với bạn',
                        Icons.mark_email_unread_rounded,
                        '/invitations',
                        const Color(0xFF16A34A),
                        const Color(0xFFF0FDF4),
                      ),
                      _MenuItem(
                        'Người dùng đã chặn',
                        'Quản lý quyền riêng tư',
                        Icons.shield_rounded,
                        '/blocked-users',
                        AppColors.muted,
                        AppColors.borderLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

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
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Đăng xuất'),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
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
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.avatar,
  });
  final String name, email, avatar;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.brandGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .15),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _AvatarFallback(name: name),
                      errorWidget: (_, _, _) => _AvatarFallback(name: name),
                    )
                  : _AvatarFallback(name: name),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHÀO MỪNG TRỞ LẠI',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 8,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3White.copyWith(fontSize: 15),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmallWhite.copyWith(
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.push('/profile'),
              icon: const Icon(Icons.edit_outlined, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .15),
                foregroundColor: Colors.white,
                minimumSize: const Size(34, 34),
                maximumSize: const Size(34, 34),
                padding: EdgeInsets.zero,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 40,
            color: AppColors.subtle,
          ),
          const SizedBox(height: 10),
          Text('Chào mừng đến TravelLens', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Đăng nhập để xem booking, chuyến đi và nhiều tiện ích khác.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: AppColors.brand,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.brand,
            size: 24,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yêu cầu đăng nhập', style: AppTextStyles.label),
                const SizedBox(height: 3),
                Text(
                  'Đăng nhập để sử dụng các tính năng cộng đồng.',
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
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: .04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MenuRow(item: items[i]),
          if (i < items.length - 1) const Divider(height: 1, indent: 58),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.label.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.ink,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );
}
