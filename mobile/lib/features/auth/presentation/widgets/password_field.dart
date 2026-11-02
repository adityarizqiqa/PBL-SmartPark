import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';

/// Kolom kata sandi dengan tombol lihat/sembunyikan.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            Text(
              'Wajib Diisi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmitted(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.spInk,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.spTint1,
            hintText: 'Masukkan password petugas',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.spInk4,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: AppColors.spInk2,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.spInk2,
              ),
              tooltip: _obscured ? 'Tampilkan' : 'Sembunyikan',
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.spPrimary600,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.spDanger,
                width: 1.2,
              ),
            ),
          ),
          validator: Validators.password,
        ),
      ],
    );
  }
}
