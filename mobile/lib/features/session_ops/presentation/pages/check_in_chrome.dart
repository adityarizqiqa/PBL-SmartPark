part of 'check_in_page.dart';

extension _CheckInChrome on _CheckInPageState {
  String get _stepTitle {
    switch (_currentStep) {
      case CheckInStep.manualNim:
        return 'Verifikasi Mahasiswa';
      case CheckInStep.plate:
        return 'Scan Plat Kendaraan';
      case CheckInStep.confirm:
        return 'Konfirmasi Check-In';
      case CheckInStep.ktm:
        return 'Scan KTM Mahasiswa';
    }
  }

  Widget _buildAppBar() {
    return PageAppBar(
      title: _stepTitle,
      onBack: _goBack,
      trailing: const ShiftActiveBadge(),
    );
  }
}
