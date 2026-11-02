import 'package:flutter/material.dart';

import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/login_controller.dart';
import 'area_picker_field.dart';
import 'officer_picker_field.dart';
import 'password_field.dart';

/// Kartu utama formulir masuk: pilih petugas, kata sandi, lahan, kirim.
class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    required this.state,
    required this.passwordController,
    required this.onSelectOfficer,
    required this.onSelectArea,
    required this.onSubmit,
    required this.onRetry,
  });

  final LoginState state;
  final TextEditingController passwordController;
  final ValueChanged<Officer> onSelectOfficer;
  final ValueChanged<Area?> onSelectArea;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorder),
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
          const Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 20,
                color: AppColors.spPrimary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aktivasi Sesi Pos Lahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.isLoadingOptions)
            const _LoadingBody()
          else if (state.optionsError != null)
            _ErrorBody(message: state.optionsError!, onRetry: onRetry)
          else ...[
            OfficerPickerField(
              officers: state.officers,
              selected: state.selectedOfficer,
              onSelected: onSelectOfficer,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: passwordController,
              onSubmitted: onSubmit,
            ),
            const SizedBox(height: 16),
            AreaPickerField(
              areas: state.areas,
              selected: state.selectedArea,
              isSupervisor: state.selectedOfficer?.isSupervisor ?? false,
              onSelected: onSelectArea,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: state.canSubmit ? onSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Mulai Bertugas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.spPrimary,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Memuat data petugas & lahan...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.spDanger,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.spDanger,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.spPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
