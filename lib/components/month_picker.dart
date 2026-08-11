import 'package:flutter/material.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

/// Shared month-grid picker. Returns a 'yyyy-mm' key or null when dismissed.
/// Replaces the stock day-calendar used for "Pilih Bulan" so the user picks a
/// month directly instead of an arbitrary day inside it.
Future<String?> showMonthPickerDialog(
  BuildContext context,
  String currentKey,
) async {
  final dark = ThemeStore.instance.isDarkMode;
  var year = int.tryParse(currentKey.split('-').first) ?? DateTime.now().year;
  var month = int.tryParse(currentKey.split('-').last) ?? 1;

  final now = DateTime.now();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final textPrimary = ThemeColors.textPrimary(dark);
      final textSecondary = ThemeColors.textSecondary(dark);
      final cardBg = ThemeColors.card(dark);
      final border = ThemeColors.border(dark);
      final accent = ThemeColors.accentExpense(dark);
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isCurrentYear = year == now.year;
          Widget monthCell(int m) {
            final selected =
                year == int.tryParse(currentKey.split('-').first) && m == month;
            final disabled =
                year > now.year || (year == now.year && m > now.month);
            return GestureDetector(
              onTap: disabled
                  ? null
                  : () => Navigator.pop(
                      ctx,
                      '$year-${m.toString().padLeft(2, '0')}',
                    ),
              child: Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? accent : border),
                ),
                child: Text(
                  monthNames[m - 1],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: disabled
                        ? ThemeColors.textMuted(dark).withValues(alpha: 0.4)
                        : selected
                        ? Colors.white
                        : textPrimary,
                  ),
                ),
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: ThemeColors.bg(dark),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: isCurrentYear
                            ? null
                            : () => setDialogState(() => year -= 1),
                        child: Opacity(
                          opacity: isCurrentYear ? 0.3 : 1,
                          child: AppIcon(
                            'chevron-left',
                            size: 20,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '$year',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: year >= now.year
                            ? null
                            : () => setDialogState(() => year += 1),
                        child: Opacity(
                          opacity: year >= now.year ? 0.3 : 1,
                          child: AppIcon(
                            'chevron-right',
                            size: 20,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (var m = 1; m <= 12; m++) monthCell(m)],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return result;
}
