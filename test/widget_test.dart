import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travellens_app/src/app.dart';
import 'package:travellens_app/src/features/auth/auth_controller.dart';

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(ready: false);
}

void main() {
  testWidgets('TravelLens app starts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_TestAuthController.new)],
        child: const TravelLensApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
