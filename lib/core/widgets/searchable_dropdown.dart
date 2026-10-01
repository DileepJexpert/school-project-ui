import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

/// A keyboard-accessible, searchable dropdown form field.
///
/// Features:
/// - Users can Tab into the field and type to search/filter options (e.g. "cla" or "3").
/// - Arrow Up / Arrow Down navigates through the matching dropdown options.
/// - Enter key selects the highlighted option.
/// - Mouse click on the field or trailing dropdown arrow opens the options menu.
/// - Supports FormField validation (required, custom validator, error text).
class SearchableDropdownFormField<T extends Object> extends FormField<T> {
  final List<T> items;
  final String Function(T)? itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final double? menuHeight;

  SearchableDropdownFormField({
    super.key,
    super.onSaved,
    super.validator,
    super.initialValue,
    super.autovalidateMode,
    required this.items,
    this.itemLabel,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.menuHeight = 320,
    bool enabled = true,
  }) : super(
          enabled: enabled,
          builder: (FormFieldState<T> state) {
            final effectiveLabel = (itemLabel ?? (T item) => item.toString());
            final selectedValue = state.value;
            final initialSelection = selectedValue != null && items.contains(selectedValue)
                ? selectedValue
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownMenu<T>(
                  initialSelection: initialSelection,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: menuHeight,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  enabled: enabled,
                  label: labelText != null ? Text(labelText) : null,
                  hintText: hintText,
                  textStyle: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: state.hasError ? AppColors.error : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: state.hasError ? AppColors.error : AppColors.navy,
                        width: 1.5,
                      ),
                    ),
                  ),
                  dropdownMenuEntries: items.map((T item) {
                    final label = effectiveLabel(item);
                    return DropdownMenuEntry<T>(
                      value: item,
                      label: label,
                      style: MenuItemButton.styleFrom(
                        textStyle: GoogleFonts.nunitoSans(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onSelected: (T? val) {
                    state.didChange(val);
                    if (onChanged != null) {
                      onChanged(val);
                    }
                  },
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      state.errorText ?? '',
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
}
