import 'package:flutter_test/flutter_test.dart';
import 'package:posduif_web/main.dart' as app;

void main() {
  group('Web App Integration Tests', () {
    testWidgets('App starts and shows login screen', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const app.PosduifWebApp());
      await tester.pumpAndSettle();

      // Verify login screen is shown
      expect(find.text('Posduif Web'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });
  });
}



