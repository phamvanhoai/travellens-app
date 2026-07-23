import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TravelLensApp extends ConsumerWidget {
  const TravelLensApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Travellens',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: ref.watch(routerProvider),
  );
}
