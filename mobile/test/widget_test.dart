import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/beranda_screen.dart';
import 'package:mobile/screens/kendaraan_screen.dart';
import 'package:mobile/screens/riwayat_screen.dart';

void main() {
  testWidgets('Full flow test: Login -> Beranda -> Kendaraan -> Riwayat Screen', (WidgetTester tester) async {
    // Set a phone-like viewport size
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartParkApp());

    // Verify key Login UI elements exist
    expect(find.text('SmartPark'), findsOneWidget);
    expect(find.text('KAMPUS'), findsOneWidget);
    expect(find.text('Aktivasi Sesi Pos Lahan'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Mulai Bertugas'), findsOneWidget);

    // Enter password
    await tester.enterText(find.byType(TextFormField), 'password123');

    // Ensure button is visible & tap 'Mulai Bertugas'
    await tester.ensureVisible(find.text('Mulai Bertugas'));
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pump();

    // Advance time for simulated login delay (600ms)
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify that BerandaScreen is displayed
    expect(find.byType(BerandaScreen), findsOneWidget);
    expect(find.text('Beranda Petugas'), findsOneWidget);
    expect(find.text('CHECK-IN'), findsOneWidget);
    expect(find.text('CHECK-OUT'), findsOneWidget);
    expect(find.text('Sedang Parkir'), findsOneWidget);
    expect(find.text('AKSI CEPAT GERBANG'), findsOneWidget);
    expect(find.text('STATISTIK OPERASIONAL'), findsOneWidget);
    expect(find.text('AKTIVITAS TERAKHIR DI POS'), findsOneWidget);

    // Dismiss any active floating SnackBar from login
    ScaffoldMessenger.of(tester.element(find.byType(BerandaScreen))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Tap on 'Kendaraan' in BottomNavigationBar
    await tester.tap(find.byIcon(Icons.directions_car_outlined));
    await tester.pumpAndSettle();

    // Verify that KendaraanScreen is displayed
    expect(find.byType(KendaraanScreen), findsOneWidget);
    expect(find.text('Kendaraan Sedang\nParkir'), findsOneWidget);
    expect(find.text('Cari NIM atau Plat Nomor...'), findsOneWidget);
    expect(find.text('Scan Check-Out'), findsOneWidget);
    expect(find.text('N 1234 ABC'), findsOneWidget);

    // Tap on 'Riwayat' in BottomNavigationBar from KendaraanScreen
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();

    // Verify that RiwayatScreen is displayed
    expect(find.byType(RiwayatScreen), findsOneWidget);
    expect(find.text('Riwayat Sesi Parkir'), findsOneWidget);
    expect(find.text('RIWAYAT SESI'), findsOneWidget);
    expect(find.text('852'), findsOneWidget);
    expect(find.text('835'), findsOneWidget);
    expect(find.text('#089'), findsOneWidget);
  });
}
