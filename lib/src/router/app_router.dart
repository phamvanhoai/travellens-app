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
import '../features/tours/tour_detail_screen.dart';
import '../screens/account_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/blocked_users_screen.dart';
import '../screens/entity_screens.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/group_trips_screen.dart';
import '../screens/group_trip_detail_screen.dart';
import '../screens/invitations_screen.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/my_travel_stories_screen.dart';
import '../screens/travel_map_screen.dart';
import '../screens/payment_checkout_screen.dart';
import '../screens/payment_history_screen.dart';
import '../screens/reference_screens.dart';
import '../screens/wishlist_screen.dart';
import '../widgets/app_shell.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authProvider, (_, _) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);
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
    refreshListenable: refreshNotifier,
    redirect: (_, state) {
      final auth = ref.read(authProvider);
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
        builder: (_, s) => TourDetailScreen(
          id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/travel-feed/:id',
        builder: (_, s) => EntityDetailScreen(
          title: 'Travel post',
          endpoint: '/travel-feed/${s.pathParameters['id']}',
        ),
      ),
      GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const MyBookingsScreen()),
      GoRoute(
        path: '/payments',
        builder: (_, _) => const PaymentHistoryScreen(),
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
        builder: (_, _) => const MyTravelStoriesScreen(),
      ),
      GoRoute(
        path: '/group-trips',
        builder: (_, _) => const GroupTripsScreen(),
      ),
      GoRoute(
        path: '/group-trips/:id',
        builder: (_, s) => GroupTripDetailScreen(
          id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/invitations',
        builder: (_, _) => const InvitationsScreen(),
      ),
      GoRoute(
        path: '/blocked-users',
        builder: (_, _) => const BlockedUsersScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const EditProfileScreen()),
      GoRoute(
        path: '/booking',
        builder: (_, s) => BookingScreen(
          tourId: int.tryParse(s.uri.queryParameters['tourId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/payment/checkout',
        builder: (_, s) => PaymentCheckoutScreen(
          bookingId: s.uri.queryParameters['bookingId'] ?? '',
        ),
      ),
      GoRoute(path: '/ai', builder: (_, _) => const AiAssistantScreen()),
      GoRoute(path: '/maps', builder: (_, _) => const TravelMapScreen()),
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
