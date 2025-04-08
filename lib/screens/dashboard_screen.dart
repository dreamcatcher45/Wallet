// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../models/expense.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Filter options: All, By Tag, Month, Week, Year, Date Range
  String _selectedFilter = 'All';
  String? _selectedTag;
  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;

  double _calculateTotal(List<Expense> expenses) {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_selectedFilter == 'By Tag' && _selectedTag != null) {
      return expenses.where((expense) => expense.tag == _selectedTag).toList();
    } else if (_selectedFilter == 'Month' && _selectedDate != null) {
      return expenses.where((expense) =>
          expense.date.year == _selectedDate!.year &&
          expense.date.month == _selectedDate!.month).toList();
    } else if (_selectedFilter == 'Week' && _selectedDate != null) {
      final weekday = _selectedDate!.weekday;
      final startOfWeek = _selectedDate!.subtract(Duration(days: weekday - 1));
      final endOfWeek = _selectedDate!.add(Duration(days: 7 - weekday));
      return expenses.where((expense) =>
          expense.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(endOfWeek.add(const Duration(days: 1)))).toList();
    } else if (_selectedFilter == 'Year' && _selectedDate != null) {
      return expenses
          .where((expense) => expense.date.year == _selectedDate!.year)
          .toList();
    } else if (_selectedFilter == 'Date Range' && _selectedRange != null) {
      return expenses.where((expense) =>
          expense.date.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(_selectedRange!.end.add(const Duration(days: 1)))).toList();
    }
    return expenses;
  }

  Future<void> _pickDate([bool isRange = false]) async {
    if (isRange) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (range != null) {
        setState(() {
          _selectedRange = range;
        });
      }
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (date != null) {
        setState(() {
          _selectedDate = date;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final filteredExpenses = _filterExpenses(expenseProvider.expenses);
    final totalExpense = _calculateTotal(filteredExpenses);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header card with a gradient summary
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expense',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Filters card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filter By',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All')),
                                DropdownMenuItem(
                                    value: 'By Tag', child: Text('By Tag')),
                                DropdownMenuItem(
                                    value: 'Month', child: Text('Month')),
                                DropdownMenuItem(
                                    value: 'Week', child: Text('Week')),
                                DropdownMenuItem(
                                    value: 'Year', child: Text('Year')),
                                DropdownMenuItem(
                                    value: 'Date Range', child: Text('Date Range')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedFilter = value!;
                                  _selectedTag = null;
                                  _selectedDate = null;
                                  _selectedRange = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_selectedFilter == 'By Tag')
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedTag ?? settingsProvider.defaultTag,
                                decoration: const InputDecoration(
                                  labelText: 'Tag',
                                  border: OutlineInputBorder(),
                                ),
                                items: settingsProvider.tags
                                    .map((tag) => DropdownMenuItem(
                                          value: tag,
                                          child: Text(tag),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTag = value;
                                  });
                                },
                              ),
                            )
                          else if (_selectedFilter == 'Month' ||
                              _selectedFilter == 'Week' ||
                              _selectedFilter == 'Year')
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_selectedDate == null
                                    ? 'Select Date'
                                    : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                                onPressed: () => _pickDate(false),
                              ),
                            )
                          else if (_selectedFilter == 'Date Range')
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(_selectedRange == null
                                    ? 'Select Date Range'
                                    : '${DateFormat('yyyy-MM-dd').format(_selectedRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedRange!.end)}'),
                                onPressed: () => _pickDate(true),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Expense list summary
              ListView.builder(
                itemCount: filteredExpenses.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final expense = filteredExpenses[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(expense.name),
                      subtitle: Text(
                          '${DateFormat('yyyy-MM-dd').format(expense.date)} • ${expense.tag}'),
                      trailing: Text(
                        '₹${expense.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
