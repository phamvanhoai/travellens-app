import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';
import '../features/destinations/destinations_screen.dart';
import '../features/destinations/destination_detail_screen.dart';
import '../features/view360/view360_screen.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/travel_feed/travel_feed_screen.dart';
import '../features/tours/tours_screen.dart';
import '../screens/account_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/entity_screens.dart';
import '../screens/home_screen.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final protected = [
    '/account',
    '/profile',
    '/wishlist',
    '/bookings',
    '/payments',
    '/reviews',
    '/stories',
    '/group-trips',
    '/invitations',
    '/blocked-users',
    '/booking',
    '/payment',
    '/ai',
  ];
  return GoRouter(
    initialLocation: '/home',
    redirect: (_, state) {
      if (!auth.ready) return state.uri.path == '/splash' ? null : '/splash';
      if (state.uri.path == '/splash')
        return auth.authenticated ? '/home' : '/home';
      final isAuth =
          state.uri.path == '/login' || state.uri.path == '/register';
      if (isAuth && auth.authenticated) return '/home';
      if (protected.any((p) => state.uri.path.startsWith(p)) &&
          !auth.authenticated)
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthScreen(register: false),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AuthScreen(register: true),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/destinations',
            builder: (_, _) => const DestinationsScreen(),
          ),
          GoRoute(path: '/tours', builder: (_, _) => const ToursScreen()),
          GoRoute(
            path: '/travel-feed',
            builder: (_, _) => const TravelFeedScreen(),
          ),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(
        path: '/destinations/:id',
        builder: (_, s) => DestinationDetailScreen(
          id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/locations',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Locations',
            endpoint: '/locations',
            keys: ['locations'],
            detailBase: '/locations',
          ),
        ),
      ),
      GoRoute(
        path: '/locations/:id',
        builder: (_, s) => LocationDetailScreen(
          id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/tours/:id',
        builder: (_, s) => EntityDetailScreen(
          title: 'Tour details',
          endpoint: '/tours/${s.pathParameters['id']}',
          bookTour: true,
        ),
      ),
      GoRoute(
        path: '/travel-feed/:id',
        builder: (_, s) => EntityDetailScreen(
          title: 'Travel post',
          endpoint: '/travel-feed/${s.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Saved tours',
            endpoint: '/saved/tours',
            keys: ['tours', 'saved'],
            detailBase: '/tours',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'My bookings',
            endpoint: '/bookings',
            keys: ['bookings'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/payments',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Payments',
            endpoint: '/payments',
            keys: ['payments'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/reviews',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Location reviews',
            endpoint: '/reviews',
            keys: ['reviews'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/stories',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'My travel stories',
            endpoint: '/travel-stories/mine',
            keys: ['stories'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/group-trips',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Group trips',
            endpoint: '/group-trips',
            keys: ['group_trips'],
            detailBase: '/group-trips',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/group-trips/:id',
        builder: (_, s) => EntityDetailScreen(
          title: 'Group trip',
          endpoint: '/group-trips/${s.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/invitations',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Invitations',
            endpoint: '/group-trip-invites',
            keys: ['invites', 'invitations'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/blocked-users',
        builder: (_, _) => const EntityListScreen(
          config: EntityConfig(
            title: 'Blocked users',
            endpoint: '/travel-feed/blocked-users',
            keys: ['users', 'blocked_users'],
            detailBase: '',
            auth: true,
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const EntityDetailScreen(
          title: 'My profile',
          endpoint: '/auth/profile',
        ),
      ),
      GoRoute(
        path: '/booking',
        builder: (_, s) => BookingScreen(
          tourId: int.tryParse(s.uri.queryParameters['tourId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/payment/checkout',
        builder: (_, s) => EntityDetailScreen(
          title: 'Payment checkout',
          endpoint: '/bookings/${s.uri.queryParameters['bookingId'] ?? 0}',
        ),
      ),
      GoRoute(
        path: '/ai',
        builder: (_, _) => const _InfoPage(
          title: 'AI travel planner',
          message:
              'Describe your ideal trip to receive personalized destination recommendations.',
          icon: Icons.auto_awesome,
        ),
      ),
      GoRoute(
        path: '/maps',
        builder: (_, _) => const _InfoPage(
          title: 'Travel map',
          message:
              'Interactive location map integration is ready for the map provider key.',
          icon: Icons.map,
        ),
      ),
      GoRoute(
        path: '/view360',
        builder: (_, s) => View360Screen(
          destinationId: int.tryParse(
            s.uri.queryParameters['destinationId'] ?? '',
          ),
          locationId: int.tryParse(s.uri.queryParameters['locationId'] ?? ''),
          sceneId: int.tryParse(s.uri.queryParameters['sceneId'] ?? ''),
        ),
      ),
    ],
  );
});

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF0E7490)),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ],
        ),
      ),
    ),
  );
}
