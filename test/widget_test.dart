import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travellens_app/src/app.dart';

void main() {
  testWidgets('TravelLens app starts', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TravelLensApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
