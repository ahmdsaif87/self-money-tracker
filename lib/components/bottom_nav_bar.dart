import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

enum TabType { dashboard, transactions, reports, add, settings }

class BottomNavBar extends StatelessWidget {
  final TabType currentTab;
  final ValueChanged<TabType> onSelectTab;
  final double bottomMargin;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    this.bottomMargin = 24,
  });

  static const _tabs = [
    (TabType.dashboard, 'Beranda', 'grid-2x2'),
    (TabType.transactions, 'Riwayat', 'receipt-text'),
    (TabType.add, 'Tambah', 'plus'),
    (TabType.reports, 'Laporan', 'chart-pie'),
    (TabType.settings, 'Pengaturan', 'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStoreHolder.isDark(context);
    final textMuted = ThemeColors.textMuted(dark);
    final textStrong = ThemeColors.textPrimary(dark);
    final activePill = dark ? const Color(0xFF3A3532) : ThemeColors.sand200;
    final activeColor = dark ? ThemeColors.expense : ThemeColors.accentExpense(false);
    final barBg = dark ? const Color(0xFF282523) : Colors.white;
    final barBorder = ThemeColors.border(dark);

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomMargin,
      child: Align(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: barBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: barBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _tabs.map((tab) {
              final key = tab.$1;
              if (key == TabType.add) {
                return GestureDetector(
                  onTap: () => onSelectTab(TabType.add),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE06D53),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const AppIcon('plus', size: 24, color: Colors.white),
                  ),
                );
              }
              final isActive = currentTab == key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelectTab(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? activePill : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: AppIcon(
                            tab.$3,
                            key: ValueKey(isActive),
                            size: 20,
                            color: isActive ? activeColor : textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive ? textStrong : textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Small helper: reads dark-mode state from the theme store via an InheritedWidget.
class ThemeStoreHolder {
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
