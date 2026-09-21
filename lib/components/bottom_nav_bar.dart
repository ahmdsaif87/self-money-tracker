import 'package:flutter/material.dart';
import '../stores/theme_store.dart';
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
    (TabType.dashboard, 'Dashboard', 'grid-2x2'),
    (TabType.transactions, 'Transactions', 'receipt-text'),
    (TabType.add, 'Add', 'plus'),
    (TabType.reports, 'Reports', 'chart-pie'),
    (TabType.settings, 'Settings', 'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        final textMuted = ThemeColors.textMuted(dark);
        final activePill = dark ? const Color(0xFF3A3532) : ThemeColors.sand200;
        final activeColor = dark ? ThemeColors.expense : ThemeColors.accentExpense(false);
        final barBg = dark ? const Color(0xFF282523) : Colors.white;
        final barBorder = ThemeColors.border(dark);

        return Positioned(
          left: 24,
          right: 24,
          bottom: bottomMargin,
          child: Align(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: barBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 380),
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
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? activePill : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: AppIcon(
                              tab.$3,
                              key: ValueKey(isActive),
                              size: 22,
                              color: isActive ? activeColor : textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
