import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(
                      '${user['name'] ?? 'T'}'.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['name'] ?? 'Traveler'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${user['email'] ?? ''}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...[
            ('My profile', Icons.person_outline, '/profile'),
            ('My bookings', Icons.book_online_outlined, '/bookings'),
            ('Payments', Icons.payments_outlined, '/payments'),
            ('Wishlist', Icons.favorite_outline, '/wishlist'),
            ('My travel stories', Icons.auto_stories_outlined, '/stories'),
            ('Group trips', Icons.groups_outlined, '/group-trips'),
            ('Invitations', Icons.mail_outline, '/invitations'),
            ('Blocked users', Icons.block_outlined, '/blocked-users'),
          ].map(
            (x) => Card(
              child: ListTile(
                leading: Icon(x.$2),
                title: Text(x.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(x.$3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
