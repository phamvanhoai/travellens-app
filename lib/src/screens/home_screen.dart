import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const features = <_Feature>[
    _Feature(
      'Destinations',
      'Find your next place',
      Icons.explore_rounded,
      '/destinations',
      Color(0xFF0F766E),
      Color(0xFFCCFBF1),
    ),
    _Feature(
      'Curated tours',
      'Travel with confidence',
      Icons.luggage_rounded,
      '/tours',
      Color(0xFF7C3AED),
      Color(0xFFEDE9FE),
    ),
    _Feature(
      'Travel feed',
      'Stories from travelers',
      Icons.auto_awesome_mosaic_rounded,
      '/travel-feed',
      Color(0xFFDB2777),
      Color(0xFFFCE7F3),
    ),
    _Feature(
      'View in 360°',
      'Step inside the scene',
      Icons.threesixty_rounded,
      '/view360',
      Color(0xFF0284C7),
      Color(0xFFE0F2FE),
    ),
    _Feature(
      'AI trip planner',
      'Built around your style',
      Icons.auto_awesome_rounded,
      '/ai',
      Color(0xFFEA580C),
      Color(0xFFFFEDD5),
    ),
    _Feature(
      'Travel map',
      'Explore places nearby',
      Icons.map_rounded,
      '/maps',
      Color(0xFF16A34A),
      Color(0xFFDCFCE7),
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 112,
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.25,
            titlePadding: const EdgeInsets.fromLTRB(18, 0, 18, 17),
            title: const Row(
              children: [
                Icon(Icons.travel_explore_rounded, size: 23),
                SizedBox(width: 8),
                Text(
                  'TravelLens',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ],
            ),
            background: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF115E59), Color(0xFF0891B2)],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push('/wishlist'),
              icon: const Icon(Icons.favorite_border_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
          sliver: SliverList.list(
            children: [
              _Hero(onExplore: () => context.go('/destinations')),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'Shape your journey',
                subtitle: 'Everything you need, thoughtfully organized',
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (_, index) =>
                    _FeatureCard(feature: features[index]),
              ),
              const SizedBox(height: 28),
              InkWell(
                onTap: () => context.push('/group-trips'),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Better trips, together.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Plan, invite and travel with your favorite people.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF14B8A6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F766E), Color(0xFF06B6D4)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3314B8A6),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          top: -34,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'YOUR WORLD, REIMAGINED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Go beyond\nthe ordinary.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                height: 1.02,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Curated places, immersive views and authentic stories—all in one journey.',
              style: TextStyle(color: Color(0xFFE6FFFB), height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F766E),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Start exploring'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFE8EDF3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(feature.path),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: feature.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(feature.icon, color: feature.color, size: 23),
            ),
            const Spacer(),
            Text(
              feature.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              feature.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Feature {
  const _Feature(
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
