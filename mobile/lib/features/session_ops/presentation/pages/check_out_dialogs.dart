part of 'check_out_page.dart';

extension _CheckOutDialogs on _CheckOutPageState {
    void _showSuccessDialog([SessionDetail? closedSession]) {
      final detail = closedSession ?? _session;
      final nimText = detail?.nim ?? widget.nim;
      final plateText = _currentCheckOutPlate;
      final durationText = _duration;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.spSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
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
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
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

    void _showRejectDialog() {
      if (_session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada sesi yang dipilih.')),
        );
        return;
      }
      _actionNoteController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.spSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
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
            ElevatedButton(
              onPressed: () async {
                final note = _actionNoteController.text.trim();
                if (note.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.spDanger,
                      content: Text('Penolakan check-out wajib disertai catatan.'),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _submitReject(note);
              },
              style: ElevatedButton.styleFrom(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada sesi yang dipilih.')),
        );
        return;
      }
      _actionNoteController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.spSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
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
            ElevatedButton(
              onPressed: () async {
                final note = _actionNoteController.text.trim();
                if (note.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.spDanger,
                      content: Text('Pembatalan check-in wajib disertai alasan.'),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _submitVoid(note);
              },
              style: ElevatedButton.styleFrom(
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
