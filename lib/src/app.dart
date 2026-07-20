import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TravelLensApp extends ConsumerWidget {
  const TravelLensApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ShadApp.router(
    title: 'TravelLens',
    debugShowCheckedModeBanner: false,
    theme: ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadZincColorScheme.light(),
    ),
    materialThemeBuilder: (_, _) => AppTheme.light,
    routerConfig: ref.watch(routerProvider),
  );
}
