import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async' show unawaited;
import 'db/database.dart';
import 'stores/account_store.dart';
import 'stores/category_store.dart';
import 'stores/transaction_store.dart';
import 'stores/theme_store.dart';
import 'stores/profile_store.dart';
import 'stores/chat_store.dart';
import 'stores/ai_queue_store.dart';
import 'theme/theme.dart';
import 'components/bottom_nav_bar.dart';
import 'components/app_page_transitions.dart';
import 'components/app_icon.dart';
import 'models/models.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'services/gemini_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatefulWidget {
  const MoneyTrackerApp({super.key});

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await DB.instance.initDatabase();
      await ThemeStore.instance.initTheme();
      await ProfileStore.instance.load();
      await AccountStore.instance.fetchAccounts();
      await CategoryStore.instance.fetchCategories();
      await TransactionStore.instance.fetchTransactions();
      await ChatStore.instance.load();
      await AIQueueStore.instance.fetchQueue();
      unawaited(_syncPendingAIQueue());
    } catch (e) {
      debugPrint('init error: $e');
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _syncPendingAIQueue() async {
    try {
      await GeminiService.syncPendingAIQueue();
      await ChatStore.instance.reflectQueueState();
    } catch (e) {
      debugPrint('queue sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        return MaterialApp(
          title: 'Money Tracker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: ThemeColors.lightBackground,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ThemeColors.expense,
              brightness: Brightness.light,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: AppPageTransitionsBuilder(),
                TargetPlatform.iOS: AppPageTransitionsBuilder(),
                TargetPlatform.linux: AppPageTransitionsBuilder(),
                TargetPlatform.macOS: AppPageTransitionsBuilder(),
                TargetPlatform.windows: AppPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: ThemeColors.darkBackground,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ThemeColors.expense,
              brightness: Brightness.dark,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: AppPageTransitionsBuilder(),
                TargetPlatform.iOS: AppPageTransitionsBuilder(),
                TargetPlatform.linux: AppPageTransitionsBuilder(),
                TargetPlatform.macOS: AppPageTransitionsBuilder(),
                TargetPlatform.windows: AppPageTransitionsBuilder(),
              },
            ),
          ),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: _ready ? const HomeShell() : const LoadingScreen(),
        );
      },
    );
  }
}

/// Global loading screen shown while stores initialize.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = ThemeColors.bg(dark);
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ThemeColors.expense.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                'wallet',
                size: 34,
                color: ThemeColors.expense,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ThemeColors.expense,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Memuat data...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textMuted(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TabType _currentTab = TabType.dashboard;

  void _openAddTransaction([Transaction? tx]) {
    AddTransactionScreen.show(context, editingTx: tx);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) => _buildBody(),
    );
  }

  Widget _buildBody() {
    if (AccountStore.instance.accounts.isEmpty) {
      return OnboardingScreen(onComplete: () => setState(() {}));
    }

    final dark = ThemeStore.instance.isDarkMode;

    Widget body;
    switch (_currentTab) {
      case TabType.dashboard:
        body = DashboardScreen(
          key: const ValueKey('dashboard'),
          onAddTransaction: () => _openAddTransaction(),
          onOpenTransaction: (tx) => _openAddTransaction(tx),
        );
        break;
      case TabType.transactions:
        body = TransactionsScreen(
          key: const ValueKey('transactions'),
          onOpenTransaction: (tx) => _openAddTransaction(tx),
        );
        break;
      case TabType.reports:
        body = ReportsScreen(
          key: const ValueKey('reports'),
          onOpenChat: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => const AIChatScreen(),
            ),
          ),
        );
        break;
      case TabType.settings:
        body = const SettingsScreen(
          key: ValueKey('settings'),
        );
        break;
      case TabType.add:
        body = DashboardScreen(
          key: const ValueKey('dashboard_add'),
          onAddTransaction: _noop,
          onOpenTransaction: _noopTx,
        );
        break;
    }

    // Smooth & lightweight Fade + Scale tab switcher
    body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: body,
    );

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          body,
          BottomNavBar(
            currentTab: _currentTab == TabType.add ? TabType.dashboard : _currentTab,
            onSelectTab: (tab) {
              if (tab == TabType.add) {
                _openAddTransaction();
              } else {
                setState(() {
                  _currentTab = tab;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  static void _noop() {}
  static void _noopTx(Transaction t) {}
}
