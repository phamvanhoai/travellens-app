import 'package:flutter/material.dart';

import '../design/app_colors.dart';

class BookingProgress extends StatelessWidget {
  const BookingProgress({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Thông tin', 'Thanh toán', 'Xác nhận'];
    return Semantics(
      label: 'Tiến trình đặt tour: bước $currentStep trên 3',
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            _BookingStep(
              number: index + 1,
              label: labels[index],
              active: currentStep == index + 1,
              completed: currentStep > index + 1,
            ),
            if (index < labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 17),
                  color: currentStep > index + 1
                      ? AppColors.brand
                      : AppColors.borderLight,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BookingStep extends StatelessWidget {
  const _BookingStep({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
  });

  final int number;
  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted ? AppColors.brand : AppColors.borderLight,
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: completed
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppColors.subtle,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: highlighted ? AppColors.brand : AppColors.subtle,
            ),
          ),
        ],
      ),
    );
  }
}
