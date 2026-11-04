part of 'check_out_page.dart';

extension _CheckOutLookup on _CheckOutPageState {
    Widget _buildAppBar() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          border: const Border(
            bottom: BorderSide(color: AppColors.spBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppColors.spPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.spPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: const Text(
                                'SmartPark',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: AppColors.spPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.spTint2,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Campus',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.spPrimary600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Verifikasi Check-Out',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spInk3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.spSuccessBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spSuccess.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.spSuccess,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Shift Aktif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spSuccessInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  color: AppColors.spInk3,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildTesterSelector() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.spTint2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'VERIFIKASI CHECK-OUT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.spPrimary600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'POS KELUAR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.spInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.spTint5,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.spPrimary600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Petugas: ${widget.officerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildLookupSearchCard() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.spBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(Icons.search_rounded, size: 18, color: AppColors.spPrimary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pencarian Sesi Parkir',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.spInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_session != null) ...[
                      InkWell(
                        onTap: _clearSessionState,
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spDanger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    InkWell(
                      onTap: () {
                        rebuild(() {
                          _showNimSearch = !_showNimSearch;
                        });
                      },
                      child: Text(
                        _showNimSearch ? 'Sembunyikan NIM' : 'Cari via NIM',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _outPlateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Plat Nomor Scan / Keluar',
                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.spInk3),
                      hintText: 'Contoh: N 1234 ABC',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                      filled: true,
                      fillColor: AppColors.spTint1,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.spBorder),
                      ),
                    ),
                    onSubmitted: (val) => _performLookup(
                      val,
                      nim: _showNimSearch ? _nimFallbackController.text : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching
                      ? null
                      : () => _performLookup(
                            _outPlateController.text,
                            nim: _showNimSearch ? _nimFallbackController.text : null,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.spPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Cari',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                ),
              ],
            ),
            if (_showNimSearch) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nimFallbackController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'NIM Mahasiswa (Fallback)',
                        labelStyle: const TextStyle(fontSize: 12, color: AppColors.spInk3),
                        hintText: 'Contoh: 244107020204',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                        filled: true,
                        fillColor: AppColors.spTint1,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.spBorder),
                        ),
                      ),
                      onSubmitted: (val) => _performLookup(_outPlateController.text, nim: val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isSearching
                        ? null
                        : () => _performLookup(
                              _outPlateController.text,
                              nim: _nimFallbackController.text,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.spPrimary,
                      side: const BorderSide(color: AppColors.spPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Cari NIM',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildCandidatesSection() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.spWarnBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.spWarn.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.spWarnInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Plat Mirip Ditemukan (${_candidates.length} kandidat):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spWarnInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._candidates.map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.spBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.plateIn,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.spInk,
                            ),
                          ),
                          Text(
                            'ID: #${c.sessionId} • Masuk: ${_formatTime(c.checkedInAt)} • ${c.areaName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppColors.spInk3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSearching ? null : () => _selectCandidate(c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.spPrimary600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Pilih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    Widget _buildLookupMessageBanner() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.spTint2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.spBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.spInk2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _lookupMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.spInk2),
              ),
            ),
          ],
        ),
      );
    }
}
