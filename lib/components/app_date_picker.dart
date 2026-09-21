import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';

/// A sleek, custom-designed date picker bottom sheet matching app aesthetics.
class AppDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const AppDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppDatePickerSheet(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2100),
      ),
    );
  }

  @override
  State<AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<AppDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _viewMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    });
  }

  void _selectPreset(DateTime date) {
    setState(() {
      _selectedDate = date;
      _viewMonth = DateTime(date.year, date.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        final bg = dark ? const Color(0xFF1C1C1E) : Colors.white;
        final cardBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
        final textColor = dark ? Colors.white : const Color(0xFF1C1C1E);
        final subtextColor = dark ? Colors.white60 : Colors.black54;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final accent = ThemeColors.accentExpense(dark);

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
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

              // Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: subtextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Presets
              Row(
                children: [
                  _buildPresetChip('Today', today, dark, accent),
                  const SizedBox(width: 8),
                  _buildPresetChip('Yesterday', yesterday, dark, accent),
                ],
              ),
              const SizedBox(height: 16),

              // Month Navigator Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textColor),
                      onPressed: _previousMonth,
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_viewMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textColor),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekday Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                    .map((day) => SizedBox(
                          width: 38,
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Days Grid
              _buildDaysGrid(dark, textColor, cardBg, accent),
              const SizedBox(height: 20),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm - ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(String label, DateTime date, bool dark, Color accent) {
    final isSelected = DateUtils.isSameDay(_selectedDate, date);
    final activeBg = accent;
    final inactiveBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final activeFg = Colors.white;
    final inactiveFg = dark ? Colors.white70 : Colors.black87;

    return GestureDetector(
      onTap: () => _selectPreset(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeFg : inactiveFg,
          ),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(bool dark, Color textColor, Color cardBg, Color accent) {
    final firstDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;

    final startingOffset = firstDayOfMonth.weekday - 1;

    List<Widget> dayWidgets = [];

    for (int i = 0; i < startingOffset; i++) {
      dayWidgets.add(const SizedBox(width: 38, height: 38));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
      final isSelected = DateUtils.isSameDay(_selectedDate, date);
      final isToday = DateUtils.isSameDay(DateTime.now(), date);

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
          },
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent
                  : isToday
                      ? (dark ? Colors.white12 : Colors.black12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: accent, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : textColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      children: dayWidgets,
    );
  }
}
