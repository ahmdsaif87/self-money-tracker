import 'package:flutter/foundation.dart' hide Category;
import '../models/models.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/transaction_store.dart';
import 'finance_summary.dart';

class AITools {
  static final List<Map<String, dynamic>> toolDeclarations = [
    {
      'name': 'get_balance',
      'description': 'Mendapatkan total saldo saat ini dan saldo per akun.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {},
      },
    },
    {
      'name': 'search_transactions',
      'description': 'Mencari riwayat transaksi berdasarkan kata kunci, rentang waktu, atau tipe.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'keyword': {
            'type': 'STRING',
            'description': 'Kata kunci pencarian pada catatan transaksi atau nama kategori.',
          },
          'limit': {
            'type': 'INTEGER',
            'description': 'Maksimal jumlah transaksi yang dikembalikan (default: 10, maksimal: 50).',
          }
        },
      },
    },
    {
      'name': 'get_financial_summary',
      'description': 'Mendapatkan ringkasan total pemasukan, pengeluaran, dan rincian per kategori untuk beberapa bulan terakhir.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'month_count': {
            'type': 'INTEGER',
            'description': 'Jumlah bulan ke belakang yang ingin diringkas (default 1).',
          }
        },
      },
    },
    {
      'name': 'create_transaction_draft',
      'description': 'Membuat draft transaksi baru (pemasukan/pengeluaran) untuk dikonfirmasi pengguna. Gunakan ini jika pengguna meminta untuk menambahkan/mencatat transaksi.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'type': {
            'type': 'STRING',
            'description': 'Tipe transaksi: "expense" atau "income" atau "transfer".',
          },
          'amount': {
            'type': 'NUMBER',
            'description': 'Nominal transaksi (harus angka positif).',
          },
          'category_name': {
            'type': 'STRING',
            'description': 'Nama kategori atau klasifikasi paling tepat dari transaksi berdasarkan prompt/deskripsi pengguna (contoh: jika user sebut "Lunch" / "Makan Siang" pilih kategori "Dining Out" / "Makan di Luar" / "Food & Beverage", jika "Bensin" / "Ojek" pilih "Transport"). AI harus mengklasifikasikan nama kategori secara cerdas.',
          },
          'note': {
            'type': 'STRING',
            'description': 'Catatan atau deskripsi transaksi.',
          }
        },
        'required': ['type', 'amount'],
      },
    },
    {
      'name': 'calculate_saving_plan',
      'description': 'Menghitung rencana tabungan berdasarkan target nominal dan waktu.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'target_amount': {
            'type': 'NUMBER',
            'description': 'Target jumlah uang yang ingin ditabung.',
          },
          'months': {
            'type': 'INTEGER',
            'description': 'Jangka waktu dalam hitungan bulan.',
          }
        },
        'required': ['target_amount', 'months'],
      },
    },
    {
      'name': 'calculate_budget',
      'description': 'Menghitung rekomendasi budget sederhana berdasarkan pendapatan.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'income': {
            'type': 'NUMBER',
            'description': 'Total pendapatan.',
          }
        },
        'required': ['income'],
      },
    },
    {
      'name': 'analyze_spending_anomalies',
      'description': 'Menganalisis anomali pengeluaran dengan membandingkan pengeluaran bulan ini dan bulan lalu per kategori. Memberikan insight kategori mana yang bengkak/naik drastis.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {},
      },
    },
    {
      'name': 'get_summary_by_date',
      'description': 'Mendapatkan ringkasan total pemasukan dan pengeluaran beserta rincian kategori pada rentang tanggal spesifik.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'start_date': {
            'type': 'STRING',
            'description': 'Tanggal awal dalam format YYYY-MM-DD.',
          },
          'end_date': {
            'type': 'STRING',
            'description': 'Tanggal akhir dalam format YYYY-MM-DD.',
          }
        },
        'required': ['start_date', 'end_date'],
      },
    }
  ];

  static Future<Map<String, dynamic>> executeTool(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'get_balance':
          return await _getBalance();
        case 'search_transactions':
          return await _searchTransactions(args);
        case 'get_financial_summary':
          return await _getFinancialSummary(args);
        case 'create_transaction_draft':
          return await _createTransactionDraft(args);
        case 'calculate_saving_plan':
          return _calculateSavingPlan(args);
        case 'calculate_budget':
          return _calculateBudget(args);
        case 'analyze_spending_anomalies':
          return await _analyzeSpendingAnomalies();
        case 'get_summary_by_date':
          return await _getSummaryByDate(args);
        default:
          return {'error': 'Tool $name not found'};
      }
    } catch (e) {
      debugPrint('Error executing tool $name: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _getBalance() async {
    await AccountStore.instance.fetchAccounts(); // Ensure fresh
    final accounts = AccountStore.instance.accounts;
    final total = accounts.fold(0.0, (sum, a) => sum + a.balance);
    return {
      'total_balance': total,
      'accounts': accounts.map((a) => {
        'name': a.name,
        'type': a.type,
        'balance': a.balance,
      }).toList(),
    };
  }

  static Future<Map<String, dynamic>> _searchTransactions(Map<String, dynamic> args) async {
    final keyword = (args['keyword'] as String?) ?? '';
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 50);

    // SQL-side search with LIMIT — no full-table load into memory.
    final txs = await TransactionStore.instance.searchTransactions(keyword, limit: limit);
    final totalMatches = await TransactionStore.instance.countSearchTransactions(keyword);
    await CategoryStore.instance.fetchCategories();
    final catMap = <String, Category>{
      for (final c in CategoryStore.instance.categories) c.id: c,
    };

    final result = txs.map((tx) {
      return {
        'date': tx.date,
        'type': tx.type,
        'amount': tx.amount,
        'category': tx.categoryId != null ? catMap[tx.categoryId]?.name : null,
        'note': tx.note,
      };
    }).toList();

    return {
      'results': result,
      'count': result.length,
      'total_matches': totalMatches,
    };
  }

  static Future<Map<String, dynamic>> _getFinancialSummary(Map<String, dynamic> args) async {
    final months = (args['month_count'] as num?)?.toInt() ?? 1;
    final summary = await FinanceSummaryService.buildFinancialSummary(monthCount: months);
    
    return {
      'total_balance': summary.totalBalance,
      'months': summary.months.map((m) => {
        'month': m.month,
        'income': m.income,
        'expense': m.expense,
        'categories': m.byCategory.map((c) => {
          'name': c.name,
          'type': c.type,
          'amount': c.amount,
        }).toList(),
      }).toList(),
    };
  }

  static Future<Map<String, dynamic>> _createTransactionDraft(Map<String, dynamic> args) async {
    final type = args['type'] as String?;
    final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
    final catName = args['category_name'] as String?;
    final note = args['note'] as String?;

    await CategoryStore.instance.fetchCategories();

    String? categoryId;
    String? categoryName;
    if (type != 'transfer') {
      final searchText = '${note ?? ''} ${catName ?? ''}'.trim();
      final matched = await _matchCategory(type, searchText, catNameFromAi: catName);
      if (matched != null) {
        categoryId = matched.id;
        categoryName = matched.name;
      }
    }

    await AccountStore.instance.fetchAccounts();
    final accountId = AccountStore.instance.accounts.firstOrNull?.id;

    return {
      'status': 'draft_created',
      '_internal_payload': {
        'type': 'draft_tx',
        'data': {
          'tx_type': type,
          'amount': amount,
          'category_id': categoryId,
          'category_name_fallback': categoryName ?? catName,
          'account_id': accountId,
          'note': note,
        }
      }
    };
  }

  static const Map<String, List<String>> _categoryKeywords = {
    'cat_groceries': [
      'belanja bulanan', 'belanja', 'groceries', 'grocery', 'minimarket',
      'supermarket', 'pasar', 'sembako', 'bahan makanan', 'alfamart',
      'indomaret',
    ],
    'cat_dining': [
      'makan', 'makanan', 'minum', 'kopi', 'warung', 'restoran', 'cafe',
      'nasi', 'ayam', 'mie', 'snack', 'jajan', 'burger', 'pizza', 'lunch', 'dinner', 'breakfast',
    ],
    'cat_bills': [
      'tagihan', 'listrik', 'air', 'pulsa', 'internet', 'wifi', 'bpjs',
      'iuran', 'sewa', 'token', 'gas', 'asuransi', 'langganan',
    ],
    'cat_transport': [
      'bensin', 'bbm', 'transport', 'ojek', 'grab', 'gojek', 'taksi', 'taxi',
      'bus', 'kereta', 'parkir', 'tol', 'pesawat', 'tiket',
    ],
    'cat_shopping': [
      'baju', 'pakaian', 'sepatu', 'shopping', 'online', 'lazada', 'shopee',
      'tokopedia',
    ],
    'cat_health': [
      'obat', 'apotek', 'apotik', 'dokter', 'klinik', 'rumah sakit',
      'vitamin', 'berobat',
    ],
    'cat_entertainment': [
      'film', 'nonton', 'bioskop', 'game', 'netflix', 'spotify', 'konser',
      'hiburan',
    ],
    'cat_salary': [
      'gaji', 'salary', 'upah', 'gajian', 'thr', 'komisi', 'pendapatan',
      'bonus',
    ],
    'cat_freelance': [
      'freelance', 'lepas', 'project', 'proyek', 'desain', 'jasa',
      'kerja sampingan', 'sampingan',
    ],
    'cat_investments': [
      'investasi', 'saham', 'crypto', 'kripto', 'reksadana', 'dividen',
      'bunga', 'emas', 'deposito',
    ],
    'cat_gift': ['hadiah', 'gift', 'kado'],
  };

  static Future<Category?> _matchCategory(String? type, String input, {String? catNameFromAi}) async {
    if (type == null) return null;
    final cats = CategoryStore.instance.categories
        .where((c) => c.type == type)
        .toList();
    if (cats.isEmpty) return null;

    final text = input.trim().toLowerCase();
    final aiCat = catNameFromAi?.trim().toLowerCase();

    // 1. Direct match with AI suggested category name if provided
    if (aiCat != null && aiCat.isNotEmpty) {
      for (final c in cats) {
        final cName = c.name.toLowerCase();
        if (cName == aiCat || cName.contains(aiCat) || aiCat.contains(cName)) {
          return c;
        }
      }
    }

    // 2. Direct match with user input text vs category names
    if (text.isNotEmpty) {
      for (final c in cats) {
        final cName = c.name.toLowerCase();
        if (cName.isNotEmpty && (text.contains(cName) || cName.contains(text))) {
          return c;
        }
      }

      // 3. Keyword matching
      Category? best;
      var bestScore = 0;
      for (final c in cats) {
        var score = 0;
        final keywords = _categoryKeywords[c.id] ?? [c.name];
        for (final kw in keywords) {
          if (text.contains(kw.toLowerCase())) score++;
        }
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (best != null && bestScore > 0) return best;
    }

    // 4. Return first category for type if available, or 'Lainnya'
    final fallback = cats
        .where((c) => c.name.toLowerCase() == 'lainnya' || c.name.toLowerCase() == 'other')
        .firstOrNull;
    if (fallback != null) return fallback;

    return cats.firstOrNull;
  }

  static Map<String, dynamic> _calculateSavingPlan(Map<String, dynamic> args) {
    final target = (args['target_amount'] as num?)?.toDouble() ?? 0.0;
    final months = (args['months'] as num?)?.toInt() ?? 1;
    
    if (months <= 0) return {'error': 'Months must be > 0'};
    
    final monthly = target / months;
    final weekly = target / (months * 4.33); // approx weeks
    final daily = target / (months * 30); // approx days
    
    return {
      'target': target,
      'months': months,
      'required_monthly': monthly.roundToDouble(),
      'required_weekly': weekly.roundToDouble(),
      'required_daily': daily.roundToDouble(),
    };
  }

  static Map<String, dynamic> _calculateBudget(Map<String, dynamic> args) {
    final income = (args['income'] as num?)?.toDouble() ?? 0.0;
    
    // 50/30/20 rule
    final needs = income * 0.50;
    final wants = income * 0.30;
    final savings = income * 0.20;
    
    return {
      'income': income,
      'rule': '50/30/20',
      'needs': needs.roundToDouble(),
      'wants': wants.roundToDouble(),
      'savings': savings.roundToDouble(),
    };
  }

  static Future<Map<String, dynamic>> _analyzeSpendingAnomalies() async {
    final summary = await FinanceSummaryService.buildFinancialSummary(monthCount: 2);
    if (summary.months.length < 2) {
      return {'message': 'Belum cukup data untuk membandingkan bulan ini dan bulan sebelumnya.'};
    }

    final thisMonth = summary.months[0];
    final lastMonth = summary.months[1];

    final anomalies = <Map<String, dynamic>>[];
    for (final catThis in thisMonth.byCategory) {
      if (catThis.type != 'expense') continue;
      
      final catLast = lastMonth.byCategory.where((c) => c.name == catThis.name).firstOrNull;
      final lastAmount = catLast?.amount ?? 0.0;
      
      if (lastAmount > 0) {
        final increasePct = ((catThis.amount - lastAmount) / lastAmount) * 100;
        if (increasePct > 20) { // Threshold anomali: naik > 20%
          anomalies.add({
            'category': catThis.name,
            'this_month': catThis.amount,
            'last_month': lastAmount,
            'increase_percentage': increasePct.toStringAsFixed(1),
          });
        }
      } else if (catThis.amount > 0) {
        anomalies.add({
          'category': catThis.name,
          'this_month': catThis.amount,
          'last_month': 0.0,
          'increase_percentage': '100',
          'note': 'Pengeluaran baru di bulan ini',
        });
      }
    }

    return {
      'this_month_total_expense': thisMonth.expense,
      'last_month_total_expense': lastMonth.expense,
      'anomalies': anomalies,
    };
  }

  static Future<Map<String, dynamic>> _getSummaryByDate(Map<String, dynamic> args) async {
    final startDateStr = args['start_date'] as String?;
    final endDateStr = args['end_date'] as String?;

    if (startDateStr == null || endDateStr == null) {
      return {'error': 'start_date and end_date are required'};
    }

    // SQL-side aggregations — no full-table load into memory.
    final store = TransactionStore.instance;
    final summary = await store.summaryByDateRange(startDateStr, endDateStr);
    final breakdown = await store.categoryBreakdownByDateRange(startDateStr, endDateStr);

    final income = summary.income;
    final expense = summary.expense;
    final list = breakdown
        .map((c) => (
              name: c.name == 'Uncategorized' ? 'Tanpa kategori' : c.name,
              amount: c.amount,
              type: c.type,
            ))
        .toList();

    return {
      'start_date': startDateStr,
      'end_date': endDateStr,
      'income': income,
      'expense': expense,
      'categories': list.map((c) => {
        'name': c.name,
        'type': c.type,
        'amount': c.amount,
      }).toList(),
    };
  }
}
