import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartParkApp());

    // Verify key UI elements exist
    expect(find.text('SmartPark'), findsOneWidget);
    expect(find.text('KAMPUS'), findsOneWidget);
    expect(find.text('Aktivasi Sesi Pos Lahan'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Mulai Bertugas'), findsOneWidget);
  });
}
