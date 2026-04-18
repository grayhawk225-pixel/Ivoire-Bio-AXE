import 'package:flutter_test/flutter_test.dart';
import 'package:projet_app1/main.dart';

void main() {
  testWidgets('Counter smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const IvoireBioAxeApp());

    // Basic check to ensure the app starts (e.g. finds some text or widget)
    expect(find.byType(IvoireBioAxeApp), findsOneWidget);
  });
}
