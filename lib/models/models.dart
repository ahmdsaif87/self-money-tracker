// Model classes matching the RN source (src/db/schema.ts + stores)

class Account {
  final String id;
  final String name;
  final String type; // cash | bank | ewallet | checking | savings | credit | investment
  final double balance;
  final String color;
  final String icon;
  final String createdAt;
  final String updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        balance: (m['balance'] as num).toDouble(),
        color: (m['color'] as String?) ?? '#7FA98B',
        icon: (m['icon'] as String?) ?? 'wallet',
        createdAt: m['created_at'] as String,
        updatedAt: m['updated_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'color': color,
        'icon': icon,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  Account copyWith({String? name, String? type, double? balance, String? color, String? icon, String? updatedAt}) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Category {
  final String id;
  final String name;
  final String type; // expense | income
  final String icon;
  final String color;
  final bool isSystem;
  final String createdAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isSystem,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: m['icon'] as String,
        color: (m['color'] as String?) ?? '#E06D53',
        isSystem: (m['is_system'] as int?) == 1,
        createdAt: m['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'is_system': isSystem ? 1 : 0,
        'created_at': createdAt,
      };

  Category copyWith({String? name, String? icon, String? color}) => Category(
        id: id,
        name: name ?? this.name,
        type: type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isSystem: isSystem,
        createdAt: createdAt,
      );
}

class Transaction {
  final String id;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final double amount;
  final String type; // expense | income | transfer
  final String? note;
  final String date; // YYYY-MM-DD
  final String createdAt;
  final String updatedAt;

  Transaction({
    required this.id,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.amount,
    required this.type,
    this.note,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as String,
        accountId: m['account_id'] as String,
        toAccountId: m['to_account_id'] as String?,
        categoryId: m['category_id'] as String?,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] as String,
        note: m['note'] as String?,
        date: m['date'] as String,
        createdAt: m['created_at'] as String,
        updatedAt: m['updated_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'category_id': categoryId,
        'amount': amount,
        'type': type,
        'note': note,
        'date': date,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class AIQueueItem {
  final String id;
  final String prompt;
  final String status; // pending | processing | completed | failed
  final String? response;
  final String createdAt;

  AIQueueItem({
    required this.id,
    required this.prompt,
    required this.status,
    this.response,
    required this.createdAt,
  });

  factory AIQueueItem.fromMap(Map<String, dynamic> m) => AIQueueItem(
        id: m['id'] as String,
        prompt: m['prompt'] as String,
        status: m['status'] as String,
        response: m['response'] as String?,
        createdAt: m['created_at'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'status': status,
        'response': response,
        'created_at': createdAt,
      };
}

class ChatMessage {
  final String id;
  final String sender; // user | ai
  final String text;
  final bool queued;
  final String? queueId;
  final String? state; // pending | processing | completed | failed
  final String? payload; // JSON structured payload for UI (e.g. draft_tx)

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.queued = false,
    this.queueId,
    this.state,
    this.payload,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        sender: m['sender'] as String,
        text: m['text'] as String,
        queued: (m['queued'] as int?) == 1,
        queueId: m['queue_id'] as String?,
        state: m['state'] as String?,
        payload: m['payload'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': sender,
        'text': text,
        'queued': queued ? 1 : 0,
        'queue_id': queueId,
        'state': state,
        'payload': payload,
      };

  ChatMessage copyWith({String? state, String? payload, String? text}) => ChatMessage(
        id: id,
        sender: sender,
        text: text ?? this.text,
        queued: queued,
        queueId: queueId,
        state: state ?? this.state,
        payload: payload ?? this.payload,
      );
}
