import 'package:flutter/material.dart';

/// Theme constants — mirrors src/theme/theme.ts
class ThemeColors {
  static const terracottaDefault = Color(0xFFE06D53);
  static const terracottaLight = Color(0xFFF49883);
  static const terracottaDark = Color(0xFFB84C34);

  static const sageDefault = Color(0xFF7FA98B);
  static const sageLight = Color(0xFFA3C4AC);
  static const sageDark = Color(0xFF587D63);

  static const sand50 = Color(0xFFFDFBF7);
  static const sand100 = Color(0xFFFBF8F3);
  static const sand200 = Color(0xFFF5EFE6);
  static const sand300 = Color(0xFFE8DED1);

  static const lightBackground = Color(0xFFFBF8F3);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSecondaryCard = Color(0xFFF4EFEA);
  static const lightBorder = Color(0xFFEAE3DA);
  static const lightTextPrimary = Color(0xFF2C2623);
  static const lightTextSecondary = Color(0xFF6E6660);
  static const lightTextMuted = Color(0xFF766D65);

  static const darkBackground = Color(0xFF191817);
  static const darkCard = Color(0xFF242220);
  static const darkSecondaryCard = Color(0xFF2F2C2A);
  static const darkBorder = Color(0xFF3D3936);
  static const darkTextPrimary = Color(0xFFF5F3EF);
  static const darkTextSecondary = Color(0xFFC5BFC7);
  static const darkTextMuted = Color(0xFFA49B93);

  static const income = Color(0xFF7FA98B);
  static const incomeDark = Color(0xFF587D63);
  static const expense = Color(0xFFE06D53);
  static const expenseDark = Color(0xFFB84C34);
  static const dangerDefault = Color(0xFFB84C34);
  static const dangerSurface = Color(0x1AB84C34);
  static const warningDefault = Color(0xFFA96A2B);
  static const warningSurface = Color(0x1AA96A2B);
  static const fillIncome = Color(0xFF587D63);
  static const fillExpense = Color(0xFFB84C34);
  static const fillWarning = Color(0xFF9A5F23);

  static const borderRadiusSm = 8.0;
  static const borderRadiusMd = 12.0;
  static const borderRadiusLg = 16.0;
  static const borderRadiusXl = 20.0;
  static const borderRadiusFull = 9999.0;

  static Color accentIncome(bool dark) => dark ? const Color(0xFF7FA98B) : const Color(0xFF587D63);
  static Color accentExpense(bool dark) => dark ? const Color(0xFFE06D53) : const Color(0xFFB84C34);
  static Color accentWarning(bool dark) => dark ? const Color(0xFFE0A75A) : const Color(0xFF9A5F23);

  static Color bg(bool dark) => dark ? darkBackground : lightBackground;
  static Color card(bool dark) => dark ? darkCard : lightCard;
  static Color secondaryCard(bool dark) => dark ? darkSecondaryCard : lightSecondaryCard;
  static Color border(bool dark) => dark ? darkBorder : lightBorder;
  static Color textPrimary(bool dark) => dark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool dark) => dark ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(bool dark) => dark ? darkTextMuted : lightTextMuted;
}

/// Named colors used by the icon set (lucide-equivalent palette)
const Map<String, Color> iconColors = {
  'expense': Color(0xFFE06D53),
  'income': Color(0xFF7FA98B),
  'warning': Color(0xFFA96A2B),
};
