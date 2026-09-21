import 'package:flutter/material.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';

/// Item data model for custom AppPickerField options.
class AppPickerItem<T> {
  final T id;
  final String title;
  final String? subtitle;
  final String? iconName;
  final Color? color;

  AppPickerItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.iconName,
    this.color,
  });
}

/// Custom picker field that replaces standard DropdownButtonFormField.
class AppPickerField<T> extends StatelessWidget {
  final String label;
  final T? selectedValue;
  final List<AppPickerItem<T>> items;
  final ValueChanged<T> onChanged;
  final String placeholder;

  const AppPickerField({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.placeholder = 'Select option',
  });

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final cardBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final borderColor = dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    final textColor = dark ? Colors.white : const Color(0xFF1C1C1E);
    final subtextColor = dark ? Colors.white60 : Colors.black54;

    AppPickerItem<T>? selectedItem;
    try {
      selectedItem = items.firstWhere((item) => item.id == selectedValue);
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: subtextColor,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            _showPickerBottomSheet(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                if (selectedItem?.color != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selectedItem!.color!.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: selectedItem.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    selectedItem?.title ?? placeholder,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selectedItem != null ? FontWeight.w600 : FontWeight.normal,
                      color: selectedItem != null ? textColor : subtextColor,
                    ),
                  ),
                ),
                if (selectedItem?.subtitle != null) ...[
                  Text(
                    selectedItem!.subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: subtextColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: ThemeStore.instance,
          builder: (ctx, _) {
            final dark = ThemeStore.instance.isDarkMode;
            final bg = dark ? const Color(0xFF1C1C1E) : Colors.white;
            final cardBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
            final textColor = dark ? Colors.white : const Color(0xFF1C1C1E);
            final subtextColor = dark ? Colors.white60 : Colors.black54;
            final accent = ThemeColors.accentExpense(dark);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select $label',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: subtextColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (itemCtx, itemIndex) => const SizedBox(height: 8),
                      itemBuilder: (itemCtx, index) {
                        final item = items[index];
                        final isSelected = item.id == selectedValue;

                        return InkWell(
                          onTap: () {
                            onChanged(item.id);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: dark ? 0.25 : 0.12)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? accent
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (item.color != null) ...[
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: item.color!.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: item.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? accent : textColor,
                                        ),
                                      ),
                                      if (item.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: subtextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: accent,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
