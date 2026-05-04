enum TransactionType { income, expense, transfer, anticipi }

class AppTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String? note;
  final String? subjectId;
  final String? entryId;
  final String? fromSubjectId;
  final String? toSubjectId;
  final DateTime createdAt;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.subjectId,
    this.entryId,
    this.fromSubjectId,
    this.toSubjectId,
    required this.createdAt,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) {
    return AppTransaction(
      id: json['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      subjectId: json['subjectId'] as String?,
      entryId: json['entryId'] as String?,
      fromSubjectId: json['fromSubjectId'] as String?,
      toSubjectId: json['toSubjectId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'subjectId': subjectId,
      'entryId': entryId,
      'fromSubjectId': fromSubjectId,
      'toSubjectId': toSubjectId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
