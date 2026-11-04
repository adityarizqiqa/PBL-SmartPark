part of 'check_out_page.dart';

extension _CheckOutVerification on _CheckOutPageState {
    Widget _buildLiveStatusBanner() {
      final isMatched = _isPlateMatched;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMatched ? AppColors.spTint5 : AppColors.spDangerBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMatched ? AppColors.spPrimary600 : AppColors.spDanger,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isMatched ? AppColors.spPrimary600 : AppColors.spDanger)
                        .withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isMatched ? Icons.shield_rounded : Icons.gpp_bad_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isMatched ? 'SESUAI' : 'PERLU VERIFIKASI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: isMatched ? AppColors.spInkStrong : AppColors.spDangerInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small test case switcher button
                      InkWell(
                        onTap: () {
                          rebuild(() {
                            if (_isPlateMatched) {
                              _outPlateController.text = 'N 1234 ABD';
                            } else {
                              _outPlateController.text = _checkInPlate != '-' ? _checkInPlate : 'N 1234 ABC';
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            _isPlateMatched ? 'Uji: Selisih' : 'Uji: Normal',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMatched
                        ? 'Plat kendaraan keluar sesuai dengan data rekaman saat check-in.'
                        : 'Karakter plat nomor keluar berbeda dengan rekaman check-in. Perlu verifikasi manual petugas.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isMatched ? AppColors.spPrimary800 : AppColors.spDangerInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildPlateComparisonCard() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.spPrimary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PERBANDINGAN PLAT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.spPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.spTint2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Kamera HP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spInk2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Two side-by-side columns
            Row(
              children: [
                // 1. Saat Masuk
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.spTint1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.spTint3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: const Text(
                                '1. MASUK',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.spPrimary600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _checkInTime,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Ingress Photo Preview
                        Container(
                          height: 96,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFF213145),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_inPhotoBytes != null)
                                Image.memory(
                                  _inPhotoBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (ctx, err, stack) => const Center(
                                    child: Icon(Icons.photo_camera,
                                        color: Colors.white24, size:28),
                                  ),
                                )
                              else
                                const Center(
                                  child: Icon(Icons.photo_camera_outlined,
                                      color: Colors.white24, size: 28),
                                ),
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xD9213145),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Foto Saat Masuk',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Plate Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF213145),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Plat Check-In',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFCBDBF5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _checkInPlate,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Saat Keluar
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isPlateMatched ? AppColors.spTint1 : AppColors.spDangerBg.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPlateMatched ? AppColors.spTint3 : AppColors.spDanger.withValues(alpha: 0.5),
                        width: _isPlateMatched ? 1 : 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '2. KELUAR',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _isPlateMatched ? AppColors.spPrimary : AppColors.spDangerInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _checkOutTime,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Egress Photo Preview
                        InkWell(
                          onTap: _captureOutPhoto,
                          child: Container(
                            height: 96,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFF213145),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_outPhotoPath != null)
                                  Image.file(
                                    File(_outPhotoPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Center(
                                      child: Icon(Icons.photo_camera,
                                          color: Colors.white24, size: 28),
                                    ),
                                  )
                                else
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.photo_camera_outlined,
                                            color: Colors.white38, size: 28),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Ketuk untuk foto plat',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xD9213145),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Foto Saat Keluar',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Plate Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF213145),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Plat Check-Out',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFCBDBF5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (_isPlateMatched)
                                Text(
                                  _currentCheckOutPlate,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                )
                              else
                                Text(
                                  _currentCheckOutPlate.isNotEmpty ? _currentCheckOutPlate : 'TIDAK TERDETEKSI',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: AppColors.spDanger,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildActiveSessionMetadata() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
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
                      Icon(Icons.storage_rounded, size: 18, color: AppColors.spPrimary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data Sesi Aktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.spInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.spTint5,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _sessionId,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spPrimary800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2-column, 6-cell grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaCell('NIM', _currentNim, flexWidth: true),
                _buildMetaCell('PLAT CHECK-IN', _checkInPlate, flexWidth: true, isBrand: true),
                _buildMetaCell('WAKTU MASUK', _checkInTime, flexWidth: true),
                _buildMetaCell('WAKTU SCAN KELUAR', _checkOutTime, flexWidth: true),
                _buildMetaCell('DURASI', _duration, flexWidth: true, isBrand: true),
                _buildMetaCell(
                  'STATUS',
                  _isPlateMatched ? 'Sesuai' : 'Perlu Verifikasi',
                  flexWidth: true,
                  isBrand: _isPlateMatched,
                  isDanger: !_isPlateMatched,
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildManualVerificationSection() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment_late_outlined, color: AppColors.spDanger, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verifikasi Manual Petugas',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.spDangerInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Lakukan pencocokan STNK dan KTM secara langsung bila ada selisih karakter plat.',
              style: TextStyle(fontSize: 12, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tuliskan catatan verifikasi (contoh: STNK asli cocok dengan NIM, plat belakang pudar)...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _handleManualClearance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.spPrimary700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.verified_user_rounded, size: 18),
              label: const Text('Setujui Pelepasan Manual', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    Widget _buildActionControls() {
      return Column(
        children: [
          // KTM Inspection Checkbox Card
          InkWell(
            onTap: () {
              rebuild(() {
                _ktmChecked = !_ktmChecked;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.spSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x66C2C7D0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _ktmChecked,
                    onChanged: (val) {
                      rebuild(() {
                        _ktmChecked = val ?? false;
                      });
                    },
                    activeColor: AppColors.spPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'KTM telah diperiksa secara visual',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spInk,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Pastikan KTM yang ditunjukkan sesuai dengan mahasiswa sebelum menyelesaikan Check-Out.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.spInk2,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Confirm Button
          ElevatedButton.icon(
            onPressed: (_ktmChecked && _isPlateMatched && !_isSubmitting)
                ? _handleConfirmCheckOut
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.spPrimary.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white70,
              elevation: (_ktmChecked && _isPlateMatched) ? 2 : 0,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isSubmitting ? 'Memproses...' : 'Konfirmasi Check-Out',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Action row for Tolak Keluar & Void
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _showRejectDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.spDanger,
                    side: const BorderSide(color: AppColors.spDanger),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text(
                    'Tolak Keluar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _showVoidDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.spWarnInk,
                    side: const BorderSide(color: AppColors.spWarn),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined, size: 16),
                  label: const Text(
                    'Batalkan (Void)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          TextButton.icon(
            onPressed: () {
              rebuild(() {
                _showManualForm = !_showManualForm;
              });
            },
            icon: Icon(
              _showManualForm ? Icons.keyboard_arrow_up : Icons.assignment_late_outlined,
              size: 16,
              color: AppColors.spPrimary600,
            ),
            label: Text(
              _showManualForm ? 'Sembunyikan Form Verifikasi Manual' : 'Buka Form Verifikasi Manual',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.spPrimary600,
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildBottomNav() {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          border: const Border(
            top: BorderSide(color: AppColors.spBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            if (index == 0) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (index == 1) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (index == 2) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              rebuild(() {
                _selectedNavIndex = index;
              });
            }
          },
          backgroundColor: AppColors.spSurface,
          selectedItemColor: AppColors.spPrimary,
          unselectedItemColor: AppColors.spInk3,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car_rounded),
              label: 'Kendaraan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
      );
    }
}
