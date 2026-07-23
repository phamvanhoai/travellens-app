import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/app_colors.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallbackRoute});

  final String fallbackRoute;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Quay lại',
    onPressed: () =>
        context.canPop() ? context.pop() : context.go(fallbackRoute),
    icon: const Icon(
      Icons.arrow_back_rounded,
      size: 21,
      color: AppColors.brand,
    ),
  );
}
