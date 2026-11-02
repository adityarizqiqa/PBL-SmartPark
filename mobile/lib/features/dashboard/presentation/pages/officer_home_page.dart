import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/officer_identity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_banner.dart';
import '../providers/dashboard_controller.dart';
import '../widgets/gate_action_card.dart';
import '../widgets/officer_home_app_bar.dart';
import '../widgets/operational_stats.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/status_and_profile.dart';

/// Beranda petugas gerbang: aksi cepat, statistik, dan aktivitas terakhir.
///
/// Navigasi diserahkan ke pemanggil lewat callback agar layar ini tidak
/// mengetahui rute lain.
class OfficerHomePage extends ConsumerWidget {
  const OfficerHomePage({
    super.key,
    required this.onOpenCheckIn,
    required this.onOpenCheckOut,
    required this.onOpenVehicles,
    required this.onOpenHistory,
    required this.onLogout,
  });

  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenCheckOut;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenHistory;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(officerIdentityProvider);
    final state = ref.watch(dashboardControllerProvider);

    if (identity == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sesi tidak ditemukan',
          message: 'Silakan masuk kembali untuk melanjutkan.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                OfficerHomeAppBar(
                  isLoading: state.isLoading,
                  onLogout: onLogout,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.spPrimary,
                    onRefresh: () =>
                        ref.read(dashboardControllerProvider.notifier).refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBar(identity: identity),
                          if (state.failure != null) ...[
                            const SizedBox(height: 10),
                            ErrorBanner(
                              message: state.failure!.message,
                              onRetry: () => ref
                                  .read(dashboardControllerProvider.notifier)
                                  .refresh(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ProfileCard(identity: identity),
                          const SizedBox(height: AppSpacing.md),
                          const SectionTitle(title: 'AKSI CEPAT GERBANG'),
                          GateActionCard.checkIn(onTap: onOpenCheckIn),
                          const SizedBox(height: 10),
                          GateActionCard.checkOut(onTap: onOpenCheckOut),
                          const SizedBox(height: AppSpacing.md),
                          const SectionTitle(title: 'STATISTIK OPERASIONAL'),
                          if (state.summary != null)
                            OperationalStats(
                              summary: state.summary!,
                              onOpenVehicles: onOpenVehicles,
                            )
                          else if (state.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.spPrimary,
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          RecentActivitySection(
                            sessions: state.summary?.recent ?? const [],
                            onSeeAll: onOpenHistory,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    ),
                  ),
                ),
                AppBottomNav(
                  currentIndex: 0,
                  destinations: AppBottomNav.officerDestinations,
                  onTap: (index) {
                    if (index == 1) onOpenVehicles();
                    if (index == 2) onOpenHistory();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
