part of 'check_in_page.dart';

extension _CheckInStepPlate on _CheckInPageState {
    Widget _buildStep2ScanPlat() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stepper Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0E4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.spPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'ALUR CHECK-IN MASUK',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFF114976),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Langkah 2 dari 3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.spPrimary600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar 3 segment
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.spPrimary600,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.spPrimary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.spTint4,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'Scan Plat Kendaraan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.spInk,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Arahkan kamera ke plat nomor kendaraan.',
            style: TextStyle(fontSize: 14, color: AppColors.spInk2),
          ),

          const SizedBox(height: 14),

          // Viewfinder & Camera Stream Mockup
          Container(
            height: 270,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF213145),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live camera feed; hasil jepretan menutupi feed saat pratinjau.
                if (_platePreviewing && _platePhotoPath != null)
                  Image.file(
                    File(_platePhotoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: const Color(0xFF213145),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  )
                else if (_plateCamera != null && _plateCamReady)
                  CameraPreview(_plateCamera!)
                else if (_plateCamError != null)
                  Container(
                    color: const Color(0xFF213145),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _plateCamError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF213145),
                    child: const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.spScan,
                        ),
                      ),
                    ),
                  ),

                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF213145).withValues(alpha: 0.4),
                        Colors.transparent,
                        const Color(0xFF213145).withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),

                // Animated Laser Line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 270 * _laserAnimation.value,
                      left: 32,
                      right: 32,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.spScan,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.spScan,
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Bounding Box with Corners
                Center(
                  child: Container(
                    width: 290,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // Corners
                        Positioned(
                          top: -2,
                          left: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.spScan,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(2)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.spScan,
                              borderRadius: BorderRadius.only(topRight: Radius.circular(2)),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          left: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.spScan,
                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(2)),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.spScan,
                              borderRadius: BorderRadius.only(bottomRight: Radius.circular(2)),
                            ),
                          ),
                        ),
                        // Tag
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xE6213145),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 14, color: AppColors.spScan),
                                const SizedBox(width: 4),
                                Text(
                                  _platePreviewing ? 'Pratinjau' : 'Foto Plat',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Top Toolbar
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xCC213145),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.center_focus_strong, size: 14, color: AppColors.spScan),
                            SizedBox(width: 4),
                            Text(
                              'Auto-Focus Aktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _togglePlateTorch,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _flashlightOn
                                ? Colors.amber.withValues(alpha: 0.3)
                                : const Color(0xCC213145),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flash_on_rounded,
                            size: 18,
                            color: _flashlightOn ? Colors.amber : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom status feedback
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.spPrimary600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _platePreviewing
                                ? 'Pratinjau Foto Plat'
                                : _plateCamReady
                                    ? 'Kamera Smartphone Aktif'
                                    : 'Menyiapkan kamera…',
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Real-Time Floating OCR Result Card
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: _showPlateEditDialog,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.spTint2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined, size: 14, color: AppColors.spPrimary),
                            SizedBox(width: 4),
                            Text(
                              'Koreksi Manual',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.spPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Embossed Vehicle Plate Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF213145),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _plateNumber,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Student identity link
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.spTint1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD0E4FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: Color(0xFF001D35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NIM: $_nim',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk,
                              ),
                            ),
                            const Text(
                              'QR KTM berhasil dibaca',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.spInk2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.spPrimary600),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ergonomic Primary Field Action Controls
          ElevatedButton.icon(
            onPressed: () => _setStep(3), // Move to Step 3: Konfirmasi
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              elevation: 2,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text(
              'Gunakan Plat Ini',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: _plateCapturing
                ? null
                : (_platePreviewing ? _retakePlate : _capturePlateInline),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spTint3,
              foregroundColor: AppColors.spInk,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _plateCapturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _platePreviewing ? Icons.refresh_rounded : Icons.photo_camera_outlined,
                    size: 18,
                  ),
            label: Text(
              _plateCapturing
                  ? 'Mengambil foto…'
                  : _platePreviewing
                      ? 'Ambil Ulang Foto'
                      : 'Ambil Foto Plat',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Info Note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 16, color: AppColors.spPrimary600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Foto plat diambil langsung dari kamera. Tekan Koreksi Manual bila hasil foto kurang jelas atau plat perlu diubah.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.spInk2,
                    height: 1.4,
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
    // STEP 3: KONFIRMASI CHECK-IN (10-checkin-konfirmasi-sukses.html)
    // ===========================================================================
}
