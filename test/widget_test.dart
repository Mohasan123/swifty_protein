// Basic smoke test for Swifty Protein.
//
// flutter create regenerates this file with a default counter-app test
// that references MyApp, which doesn't exist in this project — replace
// it with a minimal smoke test referencing the real app widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_protein/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SwiftyProteinApp());

    // The splash screen should be visible immediately on launch.
    expect(find.text('Swifty Protein'), findsOneWidget);
  });
}
