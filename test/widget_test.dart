import 'package:flutter_test/flutter_test.dart';
import 'package:meditwin/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NexoraApp());
    
    // This is a placeholder test for your professional build
    expect(find.byType(NexoraApp), findsOneWidget);
  });
}