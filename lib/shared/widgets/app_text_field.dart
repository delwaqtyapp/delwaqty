import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.onChanged,
    this.onTap,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final VoidCallback? onTap;
  final void Function(String)? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      autofocus: autofocus,
      focusNode: focusNode,
    );
  }
}
