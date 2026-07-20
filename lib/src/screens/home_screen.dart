import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../design/app_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const features = <_Feature>[
    _Feature(
      'Explore Destinations',
      'Discover stunning places worldwide',
      Icons.explore_rounded,
      '/destinations',
      AppColors.brand,
      Color(0xFFECFDF8),
    ),
    _Feature(
      'Curated Tours',
      'Expert-led travel experiences',
      Icons.luggage_rounded,
      '/tours',
      Color(0xFF7C3AED),
      Color(0xFFF5F3FF),
    ),
    _Feature(
      'Travel Feed',
      'Stories from real travelers',
      Icons.dynamic_feed_rounded,
      '/travel-feed',
      Color(0xFFDB2777),
      Color(0xFFFDF2F8),
    ),
    _Feature(
      'View in 360°',
      'Step inside any scene',
      Icons.threesixty_rounded,
      '/view360',
      Color(0xFF0284C7),
      Color(0xFFEFF6FF),
    ),
    _Feature(
      'AI Trip Planner',
      'Smart recommendations for you',
      Icons.auto_awesome_rounded,
      '/ai',
      Color(0xFFEA580C),
      Color(0xFFFFF7ED),
    ),
    _Feature(
      'Interactive Map',
      'Find places near you',
      Icons.map_rounded,
      '/maps',
      Color(0xFF16A34A),
      Color(0xFFF0FDF4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          _HomeAppBar(),
          SliverToBoxAdapter(child: _HeroBanner()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AppSectionHeader(
                title: 'Shape your journey',
                subtitle: 'Everything you need, beautifully organized',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            sliver: SliverGrid.builder(
              itemCount: features.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (_, i) => _FeatureCard(feature: features[i]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverToBoxAdapter(child: _GroupTripsBanner()),
          ),
        ],
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                colors: AppColors.brandGradientLight,
              ),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'TravelLens',
            style: AppTextStyles.h3.copyWith(letterSpacing: -0.5),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/wishlist'),
          icon: const Icon(Icons.favorite_border_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF065F52), Color(0xFF0A7E6E), Color(0xFF06B6D4)],
            stops: [0, 0.5, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .30),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .06),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'YOUR WORLD, REIMAGINED',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Go beyond\nthe ordinary.',
                    style: AppTextStyles.h1White.copyWith(fontSize: 30),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => context.go('/destinations'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brand,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_rounded, size: 18),
                        SizedBox(width: 7),
                        Text('Start exploring'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(feature.path),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: feature.soft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(feature.icon, color: feature.color, size: 24),
              ),
              const Spacer(),
              Text(
                feature.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h4.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                feature.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTripsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/group-trips'),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: .2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NEW',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.brandLight,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Better trips,\ntogether.',
                    style: AppTextStyles.h2White.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plan, invite and travel with your favorite people.',
                    style: AppTextStyles.bodySmallWhite,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
