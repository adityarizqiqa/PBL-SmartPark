import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_app_bar.dart';
import '../../domain/entities/active_vehicle.dart';
import '../providers/vehicles_controller.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_detail_sheet.dart';

/// Daftar kendaraan yang masih parkir.
class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({
    super.key,
    required this.fallbackArea,
    required this.onCheckOut,
    required this.onScanCheckOut,
    this.onBack,
  });

  /// Dipakai bila baris tidak membawa nama area.
  final String fallbackArea;

  /// Membuka alur check-out untuk satu kendaraan.
  final void Function(ActiveVehicle vehicle) onCheckOut;

  /// Membuka check-out tanpa kendaraan terpilih (scan bebas).
  final VoidCallback onScanCheckOut;

  final VoidCallback? onBack;

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Stack(
              children: [
                Column(
                  children: [
                    PageAppBar(
                      title: 'Kendaraan Parkir',
                      onBack: widget.onBack,
                      trailing: const ShiftActiveBadge(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.spPrimary,
                        onRefresh: () => ref
                            .read(vehiclesControllerProvider.notifier)
                            .refresh(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Heading(total: state.all.length),
                              const SizedBox(height: AppSpacing.md),
                              _SearchField(
                                controller: _searchController,
                                onChanged: (value) => ref
                                    .read(vehiclesControllerProvider.notifier)
                                    .search(value),
                              ),
                              const SizedBox(height: 10),
                              _FilterChip(total: state.all.length),
                              const SizedBox(height: AppSpacing.md),
                              _VehicleList(
                                state: state,
                                fallbackArea: widget.fallbackArea,
                                onRetry: () => ref
                                    .read(vehiclesControllerProvider.notifier)
                                    .refresh(),
                                onCheckOut: widget.onCheckOut,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: _ScanFab(onTap: widget.onScanCheckOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kendaraan Sedang\nParkir',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
            color: AppColors.spInk,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              size: 15,
              color: AppColors.spPrimary600,
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
                children: [
                  const TextSpan(text: 'Total '),
                  TextSpan(
                    text: '$total ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.spPrimary,
                    ),
                  ),
                  const TextSpan(text: 'Sesi Aktif'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Filter tunggal yang tersedia: seluruh kendaraan aktif.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.spPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.format_list_bulleted_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'Semua ($total)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari NIM atau Plat Nomor...',
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.spInk4,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.spInk4,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.spBorderSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.spBorderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.spPrimary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  const _VehicleList({
    required this.state,
    required this.fallbackArea,
    required this.onRetry,
    required this.onCheckOut,
  });

  final VehiclesState state;
  final String fallbackArea;
  final VoidCallback onRetry;
  final void Function(ActiveVehicle vehicle) onCheckOut;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.spPrimary),
        ),
      );
    }

    if (state.failure != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Gagal memuat kendaraan',
        message: state.failure!.message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Coba Lagi'),
        ),
      );
    }

    final vehicles = state.visible;
    if (vehicles.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_filled_outlined,
        title: 'Tidak ada kendaraan yang sedang parkir',
        message: state.query.trim().isNotEmpty
            ? 'Tidak ada kendaraan yang cocok dengan "${state.query.trim()}".'
            : 'Saat ini belum ada kendaraan yang tercatat di sistem.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        return VehicleCard(
          vehicle: vehicle,
          fallbackArea: fallbackArea,
          onDetail: () => VehicleDetailSheet.show(
            context,
            vehicle: vehicle,
            fallbackArea: fallbackArea,
            onCheckOut: () => onCheckOut(vehicle),
          ),
          onCheckOut: () => onCheckOut(vehicle),
        );
      },
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.spPrimary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.spPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan Check-Out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Buka validasi keluar',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8FBDF0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
