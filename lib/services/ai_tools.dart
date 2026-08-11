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
            'description': 'Nama kategori (opsional, akan dicocokkan otomatis).',
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
    final keyword = (args['keyword'] as String?)?.toLowerCase() ?? '';
    final limit = (args['limit'] as num?)?.toInt() ?? 10;
    
    await TransactionStore.instance.fetchTransactions();
    await CategoryStore.instance.fetchCategories();
    final categories = CategoryStore.instance.categories;
    var txs = TransactionStore.instance.transactions;
    
    if (keyword.isNotEmpty) {
      txs = txs.where((tx) {
        final noteMatch = tx.note?.toLowerCase().contains(keyword) ?? false;
        final cat = categories.where((c) => c.id == tx.categoryId).firstOrNull;
        final catMatch = cat?.name.toLowerCase().contains(keyword) ?? false;
        return noteMatch || catMatch;
      }).toList();
    }
    
    final result = txs.take(limit).map((tx) {
      final cat = categories.where((c) => c.id == tx.categoryId).firstOrNull;
      return {
        'date': tx.date,
        'type': tx.type,
        'amount': tx.amount,
        'category': cat?.name,
        'note': tx.note,
      };
    }).toList();
    
    return {
      'results': result,
      'count': result.length,
      'total_matches': txs.length,
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
      final matched = await _matchCategory(type, searchText);
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
      'nasi', 'ayam', 'mie', 'snack', 'jajan', 'burger', 'pizza',
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

  static Future<Category?> _matchCategory(String? type, String input) async {
    if (type == null || input.trim().isEmpty) return null;
    final cats = CategoryStore.instance.categories
        .where((c) => c.type == type)
        .toList();
    if (cats.isEmpty) return null;

    final text = input.toLowerCase();
    Category? best;
    var bestScore = 0;
    for (final c in cats) {
      var score = 0;
      final keywords = _categoryKeywords[c.id] ?? [c.name];
      for (final kw in keywords) {
        if (text.contains(kw.toLowerCase())) score++;
      }
      if (text.contains(c.name.toLowerCase())) score += 3;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    if (best != null && bestScore > 0) return best;

    final fallback = cats
        .where((c) => c.name.toLowerCase() == 'lainnya')
        .firstOrNull;
    if (fallback != null) return fallback;

    return CategoryStore.instance.addCategory(
      name: 'Lainnya',
      type: type,
      icon: 'tag',
      color: '#8C827A',
    );
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
}
