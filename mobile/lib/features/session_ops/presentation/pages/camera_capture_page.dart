import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';

/// Halaman kamera live: pratinjau + tombol shutter.
///
/// Mengembalikan path berkas foto ([String]) lewat `Navigator.pop`,
/// atau `null` bila pengguna membatalkan.
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key, required this.title});

  final String title;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  String? _error;
  bool _busy = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_setup());
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Tidak ada kamera yang tersedia di perangkat.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.description ?? 'Kamera tidak bisa dibuka (${e.code}).',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kamera tidak bisa dibuka.');
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_busy || controller.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(
        context,
        e.description ?? 'Gagal mengambil foto.',
      );
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _torchOn = next);
    } on CameraException {
      // Diam: tidak semua perangkat mendukung torch.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (controller != null && controller.value.isInitialized)
            IconButton(
              tooltip: _torchOn ? 'Matikan lampu' : 'Nyalakan lampu',
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _controller = null;
                          });
                          unawaited(_setup());
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.spPrimary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : controller == null || !controller.value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.spPrimary),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: CameraPreview(controller),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: GestureDetector(
                          onTap: _busy ? null : _capture,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: _busy
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: AppColors.spPrimary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
