import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filtering state variables
  String _selectedFilter = "All"; // Options: "All", "Current Month", "Date Range", "Tag Based"
  DateTimeRange? _selectedRange;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    // Ensure expenses are loaded
    Future.microtask(() => context.read<ExpenseProvider>().loadExpenses());
  }

  // Group transactions by month for display
  Map<String, List<Expense>> _groupExpensesByMonth(List<Expense> expenses) {
    final groupedExpenses = <String, List<Expense>>{};
    for (var expense in expenses) {
      final monthKey = DateFormat('MMMM yyyy').format(expense.date);
      if (!groupedExpenses.containsKey(monthKey)) {
        groupedExpenses[monthKey] = [];
      }
      groupedExpenses[monthKey]!.add(expense);
    }
    groupedExpenses.forEach((key, list) {
      list.sort((a, b) => b.date.compareTo(a.date));
    });
    final sortedEntries = groupedExpenses.entries.toList()
      ..sort((a, b) =>
          DateFormat('MMMM yyyy').parse(b.key).compareTo(DateFormat('MMMM yyyy').parse(a.key)));
    return Map.fromEntries(sortedEntries);
  }

  // Apply filtering based on the current selection
  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_selectedFilter == "Current Month") {
      return expenses.where((expense) =>
          expense.date.year == DateTime.now().year &&
          expense.date.month == DateTime.now().month).toList();
    } else if (_selectedFilter == "Date Range" && _selectedRange != null) {
      return expenses.where((expense) =>
          expense.date.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(_selectedRange!.end.add(const Duration(days: 1)))).toList();
    } else if (_selectedFilter == "Tag Based" && _selectedTag != null) {
      return expenses.where((expense) =>
          expense.tag.toLowerCase() == _selectedTag!.toLowerCase()).toList();
    }
    return expenses; // "All" or if no additional filtering criteria set
  }

  // CSV export function remains unchanged
  Future<void> _exportCsv() async {
    try {
      // Use the filtered list for CSV export if desired,
      // else, you may opt to export all expenses.
      final csvData = await context.read<ExpenseProvider>().exportToCsv();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/expenses.csv');
      await file.writeAsString(csvData);
      await Share.shareFiles([file.path], text: 'Expenses CSV');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export CSV'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show modal bottom sheet for filtering options
  Future<void> _showFilterModal() async {
    // Use temporary local variables for modal state.
    String tempFilter = _selectedFilter;
    DateTimeRange? tempRange = _selectedRange;
    String? tempTag = _selectedTag;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // Use a StatefulBuilder so that modal state can be updated.
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Filter Transactions", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tempFilter,
                      decoration: const InputDecoration(
                        labelText: "Filter Type",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "All", child: Text("All Time")),
                        DropdownMenuItem(value: "Current Month", child: Text("Current Month")),
                        DropdownMenuItem(value: "Date Range", child: Text("Date Range")),
                        DropdownMenuItem(value: "Tag Based", child: Text("Tag Based")),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          tempFilter = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (tempFilter == "Date Range")
                      TextButton(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (range != null) {
                            setModalState(() {
                              tempRange = range;
                            });
                          }
                        },
                        child: Text(tempRange == null
                            ? "Select Date Range"
                            : "${DateFormat('yyyy-MM-dd').format(tempRange!.start)} - ${DateFormat('yyyy-MM-dd').format(tempRange!.end)}"),
                      ),
                    if (tempFilter == "Tag Based")
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, child) {
                          return DropdownButtonFormField<String>(
                            value: tempTag ?? settingsProvider.defaultTag,
                            decoration: const InputDecoration(
                              labelText: "Select Tag",
                              border: OutlineInputBorder(),
                            ),
                            items: settingsProvider.tags
                                .map((tag) => DropdownMenuItem<String>(
                                      value: tag.name,
                                      child: Text(tag.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setModalState(() {
                                tempTag = value;
                              });
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Update the state with the new filters and close the modal.
                        setState(() {
                          _selectedFilter = tempFilter;
                          _selectedRange = tempRange;
                          _selectedTag = tempTag;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Apply"),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showEditExpenseDialog(Expense expense) async {
    final nameController = TextEditingController(text: expense.name);
    final amountController = TextEditingController(text: expense.amount.toString());
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(expense.date));
    String selectedTag = expense.tag;
    DateTime selectedDate = expense.date;
    final settingsProvider = context.read<SettingsProvider>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Expense', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setStateModal(() {
                            selectedDate = picked;
                            dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: dateController,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tag dropdown in edit expense dialog:
                    DropdownButtonFormField<String>(
                      value: selectedTag,
                      decoration: const InputDecoration(
                        labelText: 'Tag',
                        border: OutlineInputBorder(),
                      ),
                      items: settingsProvider.tags
                          .map((tag) => DropdownMenuItem<String>(
                                value: tag.name,
                                child: Text(tag.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setStateModal(() {
                          selectedTag = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            final updatedExpense = Expense(
                              id: expense.id,
                              name: nameController.text,
                              amount: double.tryParse(amountController.text) ?? expense.amount,
                              date: selectedDate,
                              tag: selectedTag,
                            );
                            context.read<ExpenseProvider>().updateExpense(updatedExpense);
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExpenseItem(Expense expense, ColorScheme colorScheme, ExpenseProvider provider) {
    return Dismissible(
      key: Key(expense.id.toString()),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.edit, color: colorScheme.onPrimary),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _showEditExpenseDialog(expense);
          return false;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          provider.deleteExpense(expense.id!).then((_) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Expense deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    provider.undoDelete();
                  },
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          });
        }
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              expense.name[0].toUpperCase(),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            expense.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            DateFormat('E, MMM d').format(expense.date),
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${expense.amount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              Text(expense.tag),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search transactions',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Swipe left to edit, right to delete',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ExpenseProvider>(
              builder: (context, provider, child) {
                final filteredExpenses = _filterExpenses(provider.expenses).where((expense) {
                  return expense.name.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();
                if (filteredExpenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  );
                }
                final groupedExpenses = _groupExpensesByMonth(filteredExpenses);
                return ListView.builder(
                  itemCount: groupedExpenses.length,
                  padding: const EdgeInsets.only(top: 8),
                  itemBuilder: (context, monthIndex) {
                    final monthKey = groupedExpenses.keys.elementAt(monthIndex);
                    final monthExpenses = groupedExpenses[monthKey]!;
                    double monthTotal = 0;
                    for (var expense in monthExpenses) {
                      monthTotal += expense.amount;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                monthKey,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface.withOpacity(0.8)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '₹${monthTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: monthExpenses.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            return _buildExpenseItem(monthExpenses[index], colorScheme, provider);
                          },
                        ),
                        SizedBox(height: monthIndex == groupedExpenses.length - 1 ? 16 : 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
