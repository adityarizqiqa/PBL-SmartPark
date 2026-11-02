part of 'check_in_page.dart';

extension _CheckInStepManualNim on _CheckInPageState {
    Widget _buildStep1AltManualNim() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intro Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.spTint3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MODE CADANGAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Input NIM Manual',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.spPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gunakan fitur ini hanya jika QR Code KTM tidak dapat dibaca.',
            style: TextStyle(fontSize: 14, color: AppColors.spInk2),
          ),

          const SizedBox(height: 14),

          // Warning Note Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.spTint3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.spTint4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: AppColors.spPrimary600, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perhatian Petugas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Input manual hanya digunakan sebagai cadangan saat QR gagal dibaca. Wajib melakukan verifikasi visual terhadap KTM mahasiswa.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.spInk2,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Form Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.spTint3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NIM MAHASISWA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.spPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Large NIM Input Box with Icon
                TextField(
                  controller: _nimController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.spPrimary,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.spSurface,
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.spInk2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.spTint4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.spPrimary600,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: const [
                    Icon(Icons.verified_user_outlined, size: 14, color: AppColors.spPrimary600),
                    SizedBox(width: 6),
                    Text(
                      'Pastikan petugas telah memeriksa KTM secara visual.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spInk2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Detail Grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.spTint1,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WAKTU INPUT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentFormattedTime,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.spTint1,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'POS MASUK',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.spInk2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _posFullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.spTint1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PETUGAS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Confirmation Checkbox Card
          InkWell(
            onTap: () {
              rebuild(() {
                _manualKtmVerified = !_manualKtmVerified;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.spTint1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.spTint3),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _manualKtmVerified,
                    onChanged: (val) {
                      rebuild(() {
                        _manualKtmVerified = val ?? false;
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
                          'KTM Mahasiswa Telah Diperiksa Fisik',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Petugas memastikan identitas pemilik sesuai secara visual.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.spInk2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          ElevatedButton(
            onPressed: _manualKtmVerified
                ? () {
                    rebuild(() {
                      _nim = _nimController.text.trim();
                      _currentStep = 2; // Move to Step 2
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              elevation: 2,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'LANJUT SCAN PLAT KENDARAAN',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () {
              rebuild(() {
                _currentStep = 1; // Back to Step 1 camera
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.spSurface,
              foregroundColor: AppColors.spPrimary,
              side: const BorderSide(color: AppColors.spTint3),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Kembali ke Scan QR KTM',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(height: 16),
        ],
      );
    }

    // ===========================================================================
    // STEP 2: SCAN PLAT KENDARAAN (08-checkin-scan-plat.html)
    // ===========================================================================
}
