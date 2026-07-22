import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// A comprehensive form-field component for the Delwaqty platform.
///
/// Wraps Flutter's [TextFormField] and [DropdownButtonFormField] to provide
/// a consistent API for text inputs, search fields, multi-line text areas,
/// dropdowns, and form validation across the app.
class AppFormField extends StatelessWidget {
  /// Creates a text-input form field.
  const AppFormField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
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
    this.initialValue,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.fillColor,
    this.contentPadding,
    this.textCapitalization = TextCapitalization.none,
  });

  /// Controller for the underlying text field.
  final TextEditingController? controller;

  /// Label text displayed above the field or as placeholder.
  final String? label;

  /// Hint text shown inside the field when empty.
  final String? hint;

  /// Helper text displayed below the field.
  final String? helperText;

  /// Widget placed at the start of the field (prefix).
  final Widget? prefixIcon;

  /// Widget placed at the end of the field (suffix).
  final Widget? suffixIcon;

  /// Whether the input is obscured (password fields).
  final bool obscureText;

  /// Whether the field is interactive.
  final bool enabled;

  /// Whether the field is read-only (tappable but not editable).
  final bool readOnly;

  /// Validation callback. Return `null` for valid input, or an error string.
  final String? Function(String?)? validator;

  /// Called whenever the field value changes.
  final void Function(String)? onChanged;

  /// Called when the field is tapped (useful for read-only / date picker fields).
  final VoidCallback? onTap;

  /// Called when the user submits the field (e.g. presses "done" on keyboard).
  final void Function(String)? onFieldSubmitted;

  /// Keyboard type for the input.
  final TextInputType? keyboardType;

  /// Action button shown on the keyboard.
  final TextInputAction? textInputAction;

  /// Maximum number of lines (set to > 1 for multi-line / textarea).
  final int maxLines;

  /// Minimum number of lines to display.
  final int? minLines;

  /// Maximum character count. Shows counter when set.
  final int? maxLength;

  /// Whether to auto-focus this field on build.
  final bool autofocus;

  /// Optional focus node for external control.
  final FocusNode? focusNode;

  /// Initial value when no controller is provided.
  final String? initialValue;

  /// Whether to enable autocorrect.
  final bool autocorrect;

  /// Whether to enable input suggestions.
  final bool enableSuggestions;

  /// Override for the fill color.
  final Color? fillColor;

  /// Override for the content padding.
  final EdgeInsetsGeometry? contentPadding;

  /// Text capitalization behaviour.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: contentPadding,
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
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
    );
  }

  /// Creates a search-styled text field with a search prefix icon and an
  /// optional clear button.
  static Widget search({
    Key? key,
    TextEditingController? controller,
    String? hint,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool autofocus = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return _AppSearchField(
      key: key,
      controller: controller,
      hint: hint,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  /// Creates a multi-line text area field.
  static Widget textArea({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    String? helperText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 5,
    int minLines = 3,
    int? maxLength,
    bool enabled = true,
  }) {
    return AppFormField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      enabled: enabled,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }
}

/// A dropdown form field wrapping [DropdownButtonFormField].
class AppDropdownField<T> extends StatelessWidget {
  /// Creates a dropdown form field.
  const AppDropdownField({
    super.key,
    required this.items,
    this.value,
    this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.prefixIcon,
    this.contentPadding,
    this.borderRadius,
  });

  /// The list of selectable items.
  final List<AppDropdownItem<T>> items;

  /// Currently selected value.
  final T? value;

  /// Label text displayed above the field.
  final String? label;

  /// Hint text shown when nothing is selected.
  final String? hint;

  /// Validation callback.
  final String? Function(T?)? validator;

  /// Called when the user selects a new value.
  final void Function(T?)? onChanged;

  /// Whether the dropdown is interactive.
  final bool enabled;

  /// Optional prefix icon.
  final Widget? prefixIcon;

  /// Override for the content padding.
  final EdgeInsetsGeometry? contentPadding;

  /// Override for the border radius.
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        contentPadding: contentPadding,
      ),
      validator: validator,
      onChanged: enabled ? onChanged : null,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(child: Text(item.label)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// A single item for [AppDropdownField].
class AppDropdownItem<T> {
  /// Creates a dropdown item.
  const AppDropdownItem({required this.value, required this.label, this.icon});

  /// The underlying value of this item.
  final T value;

  /// The display label.
  final String label;

  /// Optional leading icon.
  final IconData? icon;
}

/// Internal search-styled field.
class _AppSearchField extends StatelessWidget {
  const _AppSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppSpacing.borderRadiusXl,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint ?? AppLocalizations.of(context).searchHint,
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          prefixIcon:
              prefixIcon ??
              Icon(AppIcons.actionSearch, color: colors.onSurfaceVariant),
          suffixIcon:
              suffixIcon ??
              (controller?.text.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(AppIcons.actionClear, size: 20),
                      onPressed: () {
                        controller?.clear();
                        onChanged?.call('');
                      },
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.fieldPaddingHorizontal,
            vertical: AppSpacing.fieldPaddingVertical,
          ),
        ),
      ),
    );
  }
}
