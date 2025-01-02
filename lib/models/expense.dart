// lib/models/expense.dart
class Expense {
  final int? id;
  final String name;
  final double amount;
  final DateTime date;

  Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: map['amount'] as double,
      date: DateTime.parse(map['date'] as String),
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, name: $name, amount: $amount, date: $date}';
  }
}
