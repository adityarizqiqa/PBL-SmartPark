import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../domain/usecases/sign_in.dart';
import '../providers/login_controller.dart';
import '../widgets/branding_header.dart';
import '../widgets/login_card.dart';
import '../widgets/login_footer.dart';
import '../widgets/two_entry_paths_card.dart';

/// Layar masuk petugas gerbang dan pengawas.
///
/// Tidak menyentuh HTTP: seluruh akses data lewat [LoginController].
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.onSignedIn});

  /// Dipanggil setelah sesi tersimpan. Rute pemanggil yang menentukan
  /// tujuan berikutnya.
  final void Function(SignInResult result)? onSignedIn;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(loginControllerProvider.notifier).loadOptions(),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(loginControllerProvider.notifier)
        .submit(password: _passwordController.text.trim());

    if (result == null || !mounted) return;
    widget.onSignedIn?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    ref.listen<Failure?>(
      loginControllerProvider.select((s) => s.submitError),
      (previous, next) {
        if (next == null || !mounted) return;
        AppSnackBar.error(context, next.message);
      },
    );

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const BrandingHeader(),
                    const SizedBox(height: 24),
                    LoginCard(
                      state: state,
                      passwordController: _passwordController,
                      onSelectOfficer: (officer) => ref
                          .read(loginControllerProvider.notifier)
                          .selectOfficer(officer),
                      onSelectArea: (area) {
                        if (area == null) return;
                        ref
                            .read(loginControllerProvider.notifier)
                            .selectArea(area);
                      },
                      onSubmit: _submit,
                      onRetry: () => ref
                          .read(loginControllerProvider.notifier)
                          .loadOptions(),
                    ),
                    const SizedBox(height: 24),
                    const TwoEntryPathsCard(),
                    const SizedBox(height: 28),
                    const LoginFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
