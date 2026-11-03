part of 'check_out_page.dart';

extension _CheckOutDialogs on _CheckOutPageState {
  void _showSuccessDialog([SessionDetail? closedSession]) {
    final detail = closedSession ?? _session;
    final nimText = detail?.nim ?? widget.nim;
    final plateText = _currentCheckOutPlate;
    final durationText = _durationText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.spSuccessBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.spSuccess,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check-Out Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.spInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sesi parkir kendaraan $plateText telah selesai. Palang keluar terbuka otomatis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.spInk2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Summary receipt card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.spTint1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.spTint3),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NIM PEMILIK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        nimText,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.spInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DURASI PARKIR',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        durationText,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.spPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TARIF',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        'Rp 0 (Gratis)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.spSuccessInk),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _clearSessionState();
                rebuild(() {});
                final finished = widget.onFinished;
                if (finished != null) {
                  if (detail != null) finished(detail);
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.spPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Selesai & Ke Beranda',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Jalur manual tunggal: plat selisih hanya lolos dengan catatan wajib.
  void _showManualConfirmDialog(SessionDetail session) {
    _manualNoteController.clear();
    var confirmError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.spSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.spPrimary600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Manual?',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plat keluar $_currentCheckOutPlate berbeda dengan rekaman ${session.plateIn}. Pelepasan manual wajib disertai pemeriksaan KTM dan catatan verifikasi fisik.',
                style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualNoteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Catatan verifikasi fisik wajib diisi...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                  filled: true,
                  fillColor: AppColors.spTint1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.spBorder),
                  ),
                ),
                onChanged: (_) {
                  if (confirmError.isNotEmpty) {
                    setDialogState(() => confirmError = '');
                  }
                },
              ),
              if (confirmError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  confirmError,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.spDanger,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.spInk3)),
            ),
            FilledButton(
              onPressed: () {
                final note = _manualNoteController.text.trim();
                if (note.isEmpty) {
                  setDialogState(() {
                    confirmError = 'Catatan verifikasi wajib diisi untuk pelepasan manual.';
                  });
                  return;
                }
                Navigator.of(ctx).pop();
                _submitCheckOut(session, status: 'manual_verified', note: note);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.spPrimary600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka Palang Manual'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog() {
    if (_session == null) {
      rebuild(() {
        _actionError =
            'Tidak ada sesi aktif yang dipilih. Cari sesi lewat plat nomor atau NIM terlebih dahulu.';
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.spDanger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tolak Check-Out',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesi #${_session!.id} akan tetap aktif. Penolakan check-out dicatat sebagai event ke sistem.',
              style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actionNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tuliskan alasan penolakan (contoh: STNK tidak cocok, plat mencurigakan)...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.spInk3)),
          ),
          FilledButton(
            onPressed: () async {
              final note = _actionNoteController.text.trim();
              if (note.isEmpty) {
                AppSnackBar.error(
                  ctx,
                  'Penolakan check-out wajib disertai catatan.',
                );
                return;
              }
              Navigator.of(ctx).pop();
              await _submitReject(note);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.spDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak Check-Out'),
          ),
        ],
      ),
    );
  }

  void _showVoidDialog() {
    if (_session == null) {
      rebuild(() {
        _actionError =
            'Tidak ada sesi aktif yang dipilih. Cari sesi lewat plat nomor atau NIM terlebih dahulu.';
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: AppColors.spDanger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Batalkan Check-In (Void)',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membatalkan check-in akan membebaskan NIM ${_session!.nim} dan Plat ${_session!.plateIn} untuk digunakan kembali.',
              style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actionNoteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tuliskan alasan pembatalan (contoh: salah input nomor plat/NIM)...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.spInk3)),
          ),
          FilledButton(
            onPressed: () async {
              final note = _actionNoteController.text.trim();
              if (note.isEmpty) {
                AppSnackBar.error(
                  ctx,
                  'Pembatalan check-in wajib disertai alasan.',
                );
                return;
              }
              Navigator.of(ctx).pop();
              await _submitVoid(note);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.spDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Batalkan Check-In'),
          ),
        ],
      ),
    );
  }
}
