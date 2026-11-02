part of 'check_in_page.dart';

extension _CheckInStepKtm on _CheckInPageState {

    // ===========================================================================
    // STEP 1: SCAN KTM MAHASISWA (05-checkin-scan-ktm.html)
    // ===========================================================================
    Widget _buildStep1ScanKtm() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header & Stepper Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.spTint3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0E4FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LANGKAH 1 DARI 3',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF001D35),
                        ),
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.qr_code_scanner, size: 14, color: AppColors.spPrimary600),
                        SizedBox(width: 4),
                        Text(
                          'Scan KTM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spPrimary600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Segment progress bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.spPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.spTint4,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.spTint4,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'PETUGAS: ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spInk2,
                      ),
                    ),
                    Text(
                      widget.officerName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check-In Kendaraan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.spInk,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Arahkan QR Code pada KTM mahasiswa ke area pemindaian.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.spInk2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Camera Scanning Viewfinder Container
          Container(
            height: 380,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0C1622),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.spTint3, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Live camera feed: QR terbaca otomatis via _onQrDetect.
                Positioned.fill(
                  child: MobileScanner(
                    controller: _qrController,
                    onDetect: _onQrDetect,
                    errorBuilder: (context, error) => Container(
                      color: const Color(0xFF0C1622),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: const Text(
                        'Kamera tidak tersedia di perangkat ini.\nKetik NIM secara manual.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                // Radial glow in background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.6,
                        colors: [
                          AppColors.spScan.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Central Reticle Box (live camera feed di belakang)
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 4 Corner Brackets
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.spScan, width: 4),
                                left: BorderSide(color: AppColors.spScan, width: 4),
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.spScan, width: 4),
                                right: BorderSide(color: AppColors.spScan, width: 4),
                              ),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.spScan, width: 4),
                                left: BorderSide(color: AppColors.spScan, width: 4),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.spScan, width: 4),
                                right: BorderSide(color: AppColors.spScan, width: 4),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // Animated Scan Laser
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: 240 * _laserAnimation.value,
                              left: 12,
                              right: 12,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.spScan.withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.spScan,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.spScan,
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      ],
                    ),
                  ),
                ),

                // Top Overlay Controls
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xD9213145),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.spScan,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _lastQrCode.isEmpty ? 'Mencari QR Code…' : 'QR Code Terdeteksi',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleQrTorch,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _flashlightOn
                                    ? Colors.amber.withValues(alpha: 0.3)
                                    : const Color(0xCC213145),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _flashlightOn
                                      ? Colors.amber
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flash_on_rounded,
                                    size: 16,
                                    color: _flashlightOn ? Colors.amber : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Senter',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _flashlightOn ? Colors.amber : Colors.white,
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
                ),

                // Bottom Overlay
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xCC213145),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.crop_free, size: 12, color: Colors.white70),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Jarak 15 – 25 cm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xD9022C22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x4D34D399)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34D399),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Kamera Aktif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6EE7B7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Section - Detection Result Card below Viewfinder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.spTint3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
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
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.spSuccessInk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'QR Code Terdeteksi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
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
                            'Format NIM Valid',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spSuccessInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Student NIM Display Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.spTint1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spTint2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NIM MAHASISWA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _nim,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: AppColors.spPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _showNimEditDialog,
                            tooltip: 'Ubah NIM',
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            color: AppColors.spPrimary600,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.spSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppColors.spTint3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: _copyNimToClipboard,
                            tooltip: 'Salin NIM',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            color: AppColors.spInk2,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.spSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppColors.spTint3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Integrated Metadata Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.spTint1,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.spTint2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WAKTU SCAN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentFormattedTime,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.spTint1,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.spTint2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'POS MASUK',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _posShortCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.spTint1,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.spTint2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PETUGAS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.officerName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Disclaimer note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.spWarnBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xCCFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.spWarn,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan: Identitas mahasiswa diverifikasi secara visual oleh petugas melalui KTM.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          ElevatedButton(
            onPressed: () => _setStep(2), // Move to Step 2: Scan Plat
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              elevation: 2,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Lanjut Scan Plat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),

          const SizedBox(height: 10),


          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _rescanQrNim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.spTint2,
                    foregroundColor: AppColors.spPrimary,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.spTint3),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Pindai Ulang',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _setStep(10), // Switch to Manual NIM input
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.spTint3,
                    foregroundColor: AppColors.spInk,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: const Text(
                    'Ketik NIM Manual',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      );
    }

    // ===========================================================================
    // STEP 1 ALTERNATE: INPUT NIM MANUAL (09-checkin-verifikasi-mahasiswa.html)
    // ===========================================================================
}
