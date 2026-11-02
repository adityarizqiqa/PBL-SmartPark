import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api/session_store.dart' as legacy;
import 'core/di/providers.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'screens/beranda_screen.dart';
import 'screens/beranda_spv_screen.dart';

void main() {
  runApp(const SmartParkApp());
}

class SmartParkApp extends StatelessWidget {
  const SmartParkApp({super.key, this.httpClient});

  /// Klien HTTP pengganti untuk pengujian; `null` berarti klien sungguhan.
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (httpClient != null)
          apiClientProvider.overrideWithValue(ApiClient(client: httpClient)),
      ],
      child: MaterialApp(
        title: 'SmartPark Kampus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => LoginPage(
            onSignedIn: (result) => _openHome(context, result),
          ),
        ),
      ),
    );
  }

  /// Tujuan setelah masuk.
  ///
  /// Layar beranda masih memakai kode lama, jadi sesi juga dicerminkan ke
  /// penyimpanan lama sampai seluruh layar pindah ke `features/`.
  static void _openHome(BuildContext context, SignInResult result) {
    final navigator = Navigator.of(context);
    switch (result) {
      case SupervisorSignedIn(:final session):
        legacy.SessionStore.instance.setOfficerSession(
          token: session.token,
          id: session.officer.id,
          name: session.officer.name,
          userRole: session.officer.role,
        );
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => BerandaSpvScreen(
              officerName: session.officer.name,
              officerRole: 'Pengawas (SPV)',
            ),
          ),
        );
      case OfficerJoinedShift(:final login, :final officer, :final area):
        legacy.SessionStore.instance
          ..shiftToken = login.token
          ..assignmentId = login.assignment.id
          ..shiftId = login.shift.id
          ..officerId = login.assignment.officerId
          ..officerName = login.assignment.officerName
          ..areaId = login.shift.parkingAreaId
          ..areaName = login.shift.areaName
          ..role = officer.role;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => BerandaScreen(
              officerName: officer.name,
              officerRole: 'Petugas Gerbang',
              isSupervisor: false,
              parkingLot: '${area.code} • ${area.name}',
            ),
          ),
        );
    }
  }
}
