import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_app_bar.dart';
import '../providers/history_controller.dart';
import '../../domain/entities/history_item.dart';
import '../widgets/history_header.dart';
import '../widgets/session_card.dart';
import '../widgets/session_detail_sheet.dart';

/// Riwayat sesi parkir: pencarian, saringan status, dan paginasi.
class HistoryPageView extends ConsumerStatefulWidget {
  const HistoryPageView({super.key, required this.areaLabel, this.onLogout});

  final String areaLabel;

  /// Keluar dari sesi; diteruskan shell agar tab ini tetap punya jalan
  /// keluar tanpa menduplikasi logika logout.
  final VoidCallback? onLogout;

  @override
  ConsumerState<HistoryPageView> createState() => _HistoryPageViewState();
}

class _HistoryPageViewState extends ConsumerState<HistoryPageView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final page = state.page;
    final visible = state.visibleItems;

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                _TabAppBar(onLogout: widget.onLogout),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.spPrimary,
                    onRefresh: controller.refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HistoryBanner(
                            areaLabel: widget.areaLabel,
                            total: state.total,
                            matched: state.matchedCount,
                            manual: state.manualCount,
                            active: state.activeCount,
                          ),
                          const SizedBox(height: 14),
                          HistoryFilters(
                            period: state.period,
                            status: state.statusFilter,
                            onPeriodChanged: controller.setPeriod,
                            onStatusChanged: controller.setStatusFilter,
                          ),
                          const SizedBox(height: 12),
                          HistorySearchBar(
                            controller: _searchController,
                            onChanged: controller.search,
                          ),
                          const SizedBox(height: 14),
                          _HistoryList(
                            state: state,
                            items: visible,
                            onRetry: controller.refresh,
                            onDetail: (item) => SessionDetailSheet.show(
                              context,
                              item: item,
                              areaLabel: widget.areaLabel,
                            ),
                          ),
                          if (!state.isLoading &&
                              state.failure == null &&
                              page != null &&
                              page.total > 0) ...[
                            const SizedBox(height: 16),
                            PaginationBar(
                              rangeLabel: page.rangeLabel,
                              pageNumber: page.pageNumber,
                              pageCount: page.pageCount,
                              onPrevious:
                                  page.hasPrevious ? controller.previousPage : null,
                              onNext: page.hasNext ? controller.nextPage : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Bilah atas tab riwayat: lencana shift + tombol keluar bila disediakan.
class _TabAppBar extends StatelessWidget {
  const _TabAppBar({required this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return PageAppBar(
      title: 'Riwayat Sesi',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShiftActiveBadge(),
          if (onLogout != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              color: AppColors.spInk3,
              tooltip: 'Keluar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.state,
    required this.items,
    required this.onRetry,
    required this.onDetail,
  });

  final HistoryState state;
  final List<HistoryItem> items;
  final VoidCallback onRetry;
  final ValueChanged<HistoryItem> onDetail;

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
        title: 'Gagal memuat riwayat',
        message: state.failure!.message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Coba Lagi'),
        ),
      );
    }

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada sesi ditemukan',
        message: state.query.trim().isNotEmpty
            ? 'Tidak ada riwayat yang cocok dengan "${state.query.trim()}".'
            : 'Belum ada data riwayat sesi parkir yang tersimpan.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return SessionCard(
          item: item,
          onDetail: () => onDetail(item),
        );
      },
    );
  }
}
