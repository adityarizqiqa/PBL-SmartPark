import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/di/providers.dart';
import 'core/widgets/app_entry.dart';

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
        home: const EntryPoint(),
      ),
    );
  }
}
