import 'package:flutter/material.dart';
import '../stores/category_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/sheet_drag.dart' show hexColor;

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _activeTab = 'expense';

  Future<void> _showCategoryDialog([Category? cat]) async {
    final dark = ThemeStore.instance.isDarkMode;
    final bg = ThemeColors.card(dark);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final accent = ThemeColors.accentExpense(dark);

    final nameCtrl = TextEditingController(text: cat?.name ?? '');
    String type = cat?.type ?? _activeTab;
    String icon = cat?.icon ?? 'tag';
    String color = cat?.color ?? '#8C827A';

    const iconOptions = [
      'tag', 'utensils', 'car', 'shopping-bag', 'heart-pulse',
      'film', 'banknote', 'briefcase', 'trending-up', 'gift', 'wallet', 'home',
    ];

    const colorOptions = [
      '#8C827A', '#E06D53', '#7FA98B', '#E0A75A', '#4A90E2', '#8E44AD', '#E91E63', '#009688',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeColor = hexColor(color);
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ThemeColors.border(dark),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat == null ? 'Add Category' : 'Edit Category',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Preview Header Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeColors.secondaryCard(dark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: activeColor.withValues(alpha: 0.2),
                            child: AppIcon(icon, size: 22, color: activeColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameCtrl.text.trim().isEmpty ? 'Category Name' : nameCtrl.text.trim(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type == 'income' ? 'Income Category' : 'Expense Category',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: type == 'income' ? ThemeColors.income : ThemeColors.expense,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Name Input
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setModalState(() {}),
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: TextStyle(color: textMuted, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type Chips (Expense / Income)
                    Text('Category Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'expense' ? ThemeColors.expense.withValues(alpha: 0.15) : ThemeColors.secondaryCard(dark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: type == 'expense' ? ThemeColors.expense : ThemeColors.border(dark)),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: type == 'expense' ? FontWeight.bold : FontWeight.normal,
                                    color: type == 'expense' ? ThemeColors.expense : textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => type = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'income' ? ThemeColors.income.withValues(alpha: 0.15) : ThemeColors.secondaryCard(dark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: type == 'income' ? ThemeColors.income : ThemeColors.border(dark)),
                              ),
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: type == 'income' ? FontWeight.bold : FontWeight.normal,
                                    color: type == 'income' ? ThemeColors.income : textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Icon Picker Grid
                    Text('Category Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: iconOptions.map((icName) {
                        final selected = icon == icName;
                        return GestureDetector(
                          onTap: () => setModalState(() => icon = icName),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selected ? accent.withValues(alpha: 0.15) : ThemeColors.secondaryCard(dark),
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? accent : ThemeColors.border(dark)),
                            ),
                            child: AppIcon(icName, size: 20, color: selected ? accent : textMuted),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Color Badge Picker
                    Text('Color Badge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorOptions.map((cHex) {
                        final cColor = hexColor(cHex);
                        final selected = color.toUpperCase() == cHex.toUpperCase();
                        return GestureDetector(
                          onTap: () => setModalState(() => color = cHex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cColor,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: textPrimary, width: 2.5) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isNotEmpty) {
                          if (cat != null) {
                            await CategoryStore.instance.updateCategory(
                              cat.id,
                              name: name,
                              type: type,
                              icon: icon,
                              color: color,
                            );
                          } else {
                            await CategoryStore.instance.addCategory(
                              name: name,
                              type: type,
                              icon: icon,
                              color: color,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        cat == null ? 'Create Category' : 'Save Category',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (cat != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          await CategoryStore.instance.deleteCategory(cat.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete Category', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeStore.instance,
        CategoryStore.instance,
      ]),
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        final textPrimary = ThemeColors.textPrimary(dark);
        final categories = CategoryStore.instance.categories;
        final expenseCats = categories.where((c) => c.type == 'expense').toList();
        final incomeCats = categories.where((c) => c.type == 'income').toList();
        final activeList = _activeTab == 'expense' ? expenseCats : incomeCats;

        return Scaffold(
          backgroundColor: ThemeColors.bg(dark),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Manage Categories',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                color: ThemeColors.accentExpense(dark),
                onPressed: () => _showCategoryDialog(),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Segmented Tabs Header
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ThemeColors.card(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThemeColors.border(dark)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 'expense'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 'expense' ? ThemeColors.expense.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _activeTab == 'expense' ? Border.all(color: ThemeColors.expense) : null,
                            ),
                            child: Center(
                              child: Text(
                                'Expenses (${expenseCats.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _activeTab == 'expense' ? FontWeight.bold : FontWeight.w500,
                                  color: _activeTab == 'expense' ? ThemeColors.expense : ThemeColors.textMuted(dark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 'income'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 'income' ? ThemeColors.income.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _activeTab == 'income' ? Border.all(color: ThemeColors.income) : null,
                            ),
                            child: Center(
                              child: Text(
                                'Income (${incomeCats.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _activeTab == 'income' ? FontWeight.bold : FontWeight.w500,
                                  color: _activeTab == 'income' ? ThemeColors.income : ThemeColors.textMuted(dark),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Grid Tiles
                if (activeList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: ThemeColors.card(dark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeColors.border(dark)),
                    ),
                    child: Center(
                      child: Text(
                        'No $_activeTab categories found.\nTap + to add a category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 14),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: activeList.map((cat) {
                      final catColor = hexColor(cat.color);
                      final cardWidth = (MediaQuery.of(context).size.width - 44) / 2;
                      return SizedBox(
                        width: cardWidth,
                        child: Card(
                          color: ThemeColors.card(dark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: InkWell(
                            onTap: () => _showCategoryDialog(cat),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: catColor.withValues(alpha: 0.18),
                                    child: AppIcon(cat.icon, size: 16, color: catColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.edit, size: 16, color: ThemeColors.textMuted(dark)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCategoryDialog(),
            backgroundColor: ThemeColors.accentExpense(dark),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
