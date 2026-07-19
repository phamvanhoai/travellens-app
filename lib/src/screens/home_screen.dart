import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final features = <(String, IconData, String)>[
      ('Destinations', Icons.explore, '/destinations'),
      ('Locations', Icons.place, '/locations'),
      ('Tours', Icons.luggage, '/tours'),
      ('Wishlist', Icons.favorite, '/wishlist'),
      ('My bookings', Icons.book_online, '/bookings'),
      ('Payments', Icons.payments, '/payments'),
      ('Reviews', Icons.star, '/reviews'),
      ('Travel stories', Icons.auto_stories, '/stories'),
      ('Group trips', Icons.groups, '/group-trips'),
      ('AI planner', Icons.auto_awesome, '/ai'),
      ('Travel map', Icons.map, '/maps'),
      ('360° views', Icons.threesixty, '/view360'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.travel_explore, color: Color(0xFF0E7490)),
            SizedBox(width: 8),
            Text('TravelLens', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF155E75), Color(0xFF0891B2)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore Vietnam your way',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Discover destinations, book tours and share every journey.',
                  style: TextStyle(color: Color(0xFFE0F2FE), fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Everything you need',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .92,
            ),
            itemBuilder: (_, i) {
              final f = features[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(f.$3),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(f.$2, color: const Color(0xFF0E7490), size: 30),
                        const SizedBox(height: 8),
                        Text(
                          f.$1,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
