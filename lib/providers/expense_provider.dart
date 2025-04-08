// lib/providers/expense_provider.dart
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  double _monthlyTotal = 0;
  Expense? _lastDeletedExpense;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Expense> get expenses => _expenses;
  double get monthlyTotal => _monthlyTotal;

  ExpenseProvider() {
    loadExpenses();
  }

  Future<void> addExpense(String name, double amount, String tag) async {
    try {
      final expense = Expense(
        name: name,
        amount: amount,
        date: DateTime.now(),
        tag: tag,
      );
      await _dbHelper.insertExpense(expense);
      await loadExpenses();
      notifyListeners();
    } catch (e) {
      print('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> loadExpenses() async {
    try {
      _expenses = await _dbHelper.getExpenses();
      await calculateMonthlyTotal();
      notifyListeners();
    } catch (e) {
      print('Error loading expenses: $e');
      _expenses = [];
      _monthlyTotal = 0;
      notifyListeners();
    }
  }

  Future<void> calculateMonthlyTotal() async {
    try {
      final monthExpenses = await _dbHelper.getMonthExpenses(DateTime.now());
      _monthlyTotal =
          monthExpenses.fold(0, (prev, expense) => prev + expense.amount);
      notifyListeners();
    } catch (e) {
      print('Error calculating monthly total: $e');
      _monthlyTotal = 0;
      notifyListeners();
    }
  }

  /// Export CSV with optional filtering:
  /// filter: 'all' | 'currentMonth' | 'specific'
  /// if filter == 'specific', start and end must be provided.
  Future<String> exportToCsv({String filter = 'all', DateTime? start, DateTime? end}) async {
    try {
      List<Expense> expenses;
      if (filter == 'currentMonth') {
        expenses = await _dbHelper.getMonthExpenses(DateTime.now());
      } else if (filter == 'specific' && start != null && end != null) {
        expenses = await _dbHelper.getExpensesByDateRange(start, end);
      } else {
        expenses = await _dbHelper.getExpenses();
      }
      final csvData = [
        ['Index', 'Date', 'Name', 'Amount', 'Tag'],
        ...expenses.asMap().entries.map((entry) => [
              entry.key + 1,
              entry.value.date.toString(),
              entry.value.name,
              entry.value.amount.toStringAsFixed(2),
              entry.value.tag,
            ])
      ];
      return const ListToCsvConverter().convert(csvData);
    } catch (e) {
      print('Error exporting to CSV: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      _lastDeletedExpense =
          _expenses.firstWhere((expense) => expense.id == id);
      await _dbHelper.deleteExpense(id);
      await loadExpenses();
      notifyListeners();
    } catch (e) {
      print('Error deleting expense: $e');
      rethrow;
    }
  }

  Future<void> undoDelete() async {
    if (_lastDeletedExpense != null) {
      try {
        await _dbHelper.insertExpense(_lastDeletedExpense!);
        await loadExpenses();
        _lastDeletedExpense = null;
        notifyListeners();
      } catch (e) {
        print('Error undoing delete: $e');
        rethrow;
      }
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await _dbHelper.updateExpense(expense);
      await loadExpenses();
      notifyListeners();
    } catch (e) {
      print('Error updating expense: $e');
      rethrow;
    }
  }
}
