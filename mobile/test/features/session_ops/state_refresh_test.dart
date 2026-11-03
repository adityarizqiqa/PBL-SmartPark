import 'package:mobile/core/entities/parking_session.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart' as core;
import 'package:mobile/core/session/session_scope.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_controller.dart';
import 'package:mobile/features/history/presentation/providers/history_controller.dart';
import 'package:mobile/features/session_ops/presentation/pages/check_in_page.dart';
import 'package:mobile/features/session_ops/presentation/pages/check_out_page.dart';
import 'package:mobile/features/vehicles/domain/entities/active_vehicle.dart';
import 'package:mobile/features/vehicles/presentation/providers/vehicles_controller.dart';

void main() {
  group('State Management & Auto-Refresh Tests', () {
    http.Client createMockClient() {
      return MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/sessions/active') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/dashboard') {
          return http.Response(
            jsonEncode({
              'active_now': 10,
              'checked_in_today': 20,
              'checked_out_today': 10,
              'recent': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/api/sessions/history') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/history/meta') {
          return http.Response(
            jsonEncode({'total': 0, 'limit': 20, 'offset': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
    }

    testWidgets('resetSessionScopedState invalidates vehicles, dashboard, and history providers',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            core.ApiClient(
              client: createMockClient(),
              baseUrl: 'http://test.local',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      int vehiclesBuildCount = 0;
      int dashboardBuildCount = 0;
      int historyBuildCount = 0;

      container.listen(vehiclesControllerProvider, (_, _) {
        vehiclesBuildCount++;
      });
      container.listen(dashboardControllerProvider, (_, _) {
        dashboardBuildCount++;
      });
      container.listen(historyControllerProvider, (_, _) {
        historyBuildCount++;
      });

      // Allow initial microtasks to complete
      await tester.pump(const Duration(milliseconds: 50));

      final initialVehiclesCount = vehiclesBuildCount;
      final initialDashboardCount = dashboardBuildCount;
      final initialHistoryCount = historyBuildCount;

      // Trigger resetSessionScopedState
      resetSessionScopedState(container);

      await tester.pump(const Duration(milliseconds: 50));

      // Listeners were notified due to invalidation / rebuild
      expect(vehiclesBuildCount, greaterThan(initialVehiclesCount));
      expect(dashboardBuildCount, greaterThan(initialDashboardCount));
      expect(historyBuildCount, greaterThan(initialHistoryCount));
    });

    testWidgets('VehiclesController addVehicle and removeVehicle mutate state locally',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            core.ApiClient(
              client: createMockClient(),
              baseUrl: 'http://test.local',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(vehiclesControllerProvider.notifier);
      final dummyVehicle = ActiveVehicle(
        id: 999,
        nim: '244107020001',
        plateIn: 'N 9999 ZZ',
        checkedInAt: DateTime.now(),
        durationMinutes: 10,
        areaId: 1,
        areaName: 'Pos Utama',
        checkedInBy: 'Budi',
      );

      controller.addVehicle(dummyVehicle);
      expect(container.read(vehiclesControllerProvider).all.any((v) => v.id == 999), isTrue);

      controller.removeVehicle(999);
      expect(container.read(vehiclesControllerProvider).all.any((v) => v.id == 999), isFalse);
    });

    testWidgets('CheckInPage calls onFinished and resets state upon successful check-in',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool onFinishedCalled = false;
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/sessions/check-in') {
          return http.Response(
            jsonEncode({
              'id': 105,
              'nim': '244107020204',
              'plate_in': 'N 1234 ABC',
              'plate_out': null,
              'checked_in_at': '2026-10-12T07:32:00.000Z',
              'checked_out_at': null,
              'status': 'active',
              'match_method': 'plate_exact',
              'verification_note': null,
              'plate_in_photo_path': null,
              'plate_out_photo_path': null,
              'area_id': 1,
              'area_name': 'POS-UTAMA • Pos Parkir Utama',
              'checked_in_by': {
                'assignment_id': 1,
                'officer_id': 1,
                'officer_name': 'Budi Santoso',
              },
              'checked_out_by': null,
              'events': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/api/sessions/active') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/dashboard') {
          return http.Response('{"active_now": 0, "checked_in_today": 0, "checked_out_today": 0, "recent": []}', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/history') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/history/meta') {
          return http.Response('{"total": 0, "limit": 20, "offset": 0}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(
              core.ApiClient(client: mockClient, baseUrl: 'http://test.local'),
            ),
          ],
          child: MaterialApp(
            home: CheckInPage(
              onFinished: () => onFinishedCalled = true,
            ),
          ),
        ),
      );

      // Step 1 -> Step 2
      await tester.ensureVisible(find.text('Lanjut Scan Plat'));
      await tester.tap(find.text('Lanjut Scan Plat'));
      await tester.pump(const Duration(milliseconds: 300));

      // Step 2 -> Step 3
      await tester.ensureVisible(find.text('Gunakan Plat Ini'));
      await tester.tap(find.text('Gunakan Plat Ini'));
      await tester.pump(const Duration(milliseconds: 300));

      // Step 3 -> Submit
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'),
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(onFinishedCalled, isTrue);
      expect(find.text('Check-In Berhasil!'), findsOneWidget);
    });

    testWidgets('CheckOutPage calls onFinished upon successful check-out',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool onFinishedCalled = false;
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/sessions/lookup') {
          return http.Response(
            jsonEncode({
              'match_method': 'plate_exact',
              'session': {
                'id': 89,
                'nim': '244107020204',
                'plate_in': 'N 1234 ABC',
                'plate_out': null,
                'checked_in_at': '2026-10-12T07:32:00.000Z',
                'checked_out_at': null,
                'status': 'active',
                'match_method': 'plate_exact',
                'verification_note': null,
                'plate_in_photo_path': null,
                'plate_out_photo_path': null,
                'area_id': 1,
                'area_name': 'POS-UTAMA • Pos Parkir Utama',
                'checked_in_by': {
                  'assignment_id': 1,
                  'officer_id': 1,
                  'officer_name': 'Budi Santoso',
                },
                'checked_out_by': null,
                'events': [],
              },
              'candidates': [],
              'message': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.endsWith('/check-out')) {
          return http.Response(
            jsonEncode({
              'id': 89,
              'nim': '244107020204',
              'plate_in': 'N 1234 ABC',
              'plate_out': 'N 1234 ABC',
              'checked_in_at': '2026-10-12T07:32:00.000Z',
              'checked_out_at': '2026-10-12T11:00:00.000Z',
              'status': 'matched',
              'match_method': 'plate_exact',
              'verification_note': null,
              'plate_in_photo_path': null,
              'plate_out_photo_path': null,
              'area_id': 1,
              'area_name': 'POS-UTAMA • Pos Parkir Utama',
              'checked_in_by': {
                'assignment_id': 1,
                'officer_id': 1,
                'officer_name': 'Budi Santoso',
              },
              'checked_out_by': {
                'assignment_id': 1,
                'officer_id': 1,
                'officer_name': 'Budi Santoso',
              },
              'events': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/api/sessions/active') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/dashboard') {
          return http.Response('{"active_now": 0, "checked_in_today": 0, "checked_out_today": 0, "recent": []}', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/history') {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/api/sessions/history/meta') {
          return http.Response('{"total": 0, "limit": 20, "offset": 0}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(
              core.ApiClient(client: mockClient, baseUrl: 'http://test.local'),
            ),
          ],
          child: MaterialApp(
            home: CheckOutPage(
              initialSession: SessionDetail(
                id: 89,
                nim: '244107020204',
                plateIn: 'N 1234 ABC',
                plateOut: null,
                checkedInAt: DateTime.parse('2026-10-12T07:32:00.000Z'),
                checkedOutAt: null,
                status: 'active',
                matchMethod: 'plate_exact',
                verificationNote: null,
                plateInPhotoPath: null,
                plateOutPhotoPath: null,
                areaId: 1,
                areaName: 'POS-UTAMA • Pos Parkir Utama',
                checkedInBy: const SessionOfficer(
                  assignmentId: 1,
                  officerId: 1,
                  officerName: 'Budi Santoso',
                ),
                checkedOutBy: null,
                events: const [],
              ),
              onFinished: () => onFinishedCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('KTM telah diperiksa secara visual'));
      await tester.tap(find.text('KTM telah diperiksa secara visual'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Konfirmasi Check-Out'));
      await tester.tap(find.text('Konfirmasi Check-Out'));
      await tester.pumpAndSettle();

      expect(onFinishedCalled, isTrue);
      expect(find.text('Check-Out Berhasil!'), findsOneWidget);
    });
  });
}
