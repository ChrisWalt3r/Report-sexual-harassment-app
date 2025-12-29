import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String value;
  final bool isReadOnly;
  final bool isLocked;
  final bool isDropdown;
  final String? helperText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  
  // Additional fields for form validation
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.label,
    this.value = '',
    this.isReadOnly = false,
    this.isLocked = false,
    this.isDropdown = false,
    this.helperText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // If using new form validation mode
    if (hint != null || prefixIcon != null || validator != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textLight,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AppColors.textGray)
                  : null,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      );
    }
    
    // Original implementation for profile screen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppStyles.label,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isDropdown || isLocked ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderLight,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: isReadOnly || isLocked || isDropdown
                      ? Text(
                          value,
                          style: AppStyles.bodyMedium,
                        )
                      : TextFormField(
                          controller: controller,
                          initialValue: controller == null ? value : null,
                          onChanged: onChanged,
                          style: AppStyles.bodyMedium,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                        ),
                ),
                if (isLocked)
                  const Icon(
                    Icons.lock_outline,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                if (isDropdown)
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textLight,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: AppStyles.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }
}
