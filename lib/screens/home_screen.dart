import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import 'transactions_screen.dart';
import 'dashboard_screen.dart';
import 'tags_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _amount = '';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    // Set the default tag (or the first tag) from settings as selected by default.
    final defaultTag = context.read<SettingsProvider>().defaultTag;
    _selectedTag = defaultTag;
  }

  void _addNumber(String number) {
    setState(() {
      if (number == '.') {
        if (!_amount.contains('.')) {
          _amount = _amount.isEmpty ? '0.' : _amount + '.';
        }
      } else {
        _amount += number;
      }
      _amountController.text = _amount;
    });
  }

  void _clear() {
    setState(() {
      _amount = '';
      _amountController.text = '';
    });
  }

  void _deleteLastDigit() {
    setState(() {
      if (_amount.isNotEmpty) {
        _amount = _amount.substring(0, _amount.length - 1);
        _amountController.text = _amount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        // Only display the price value (monthly total) without the prefix.
        title: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            return Text(
              '₹${provider.monthlyTotal.toStringAsFixed(2)}',
              style: TextStyle(
                  color: colorScheme.onSurface, fontWeight: FontWeight.bold),
            );
          },
        ),
        actions: [
          // Dashboard button.
          IconButton(
            icon: Icon(
              Icons.dashboard,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            },
          ),
          // Transactions button.
          IconButton(
            icon: Icon(
              Icons.receipt_long_rounded,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionsScreen(),
                ),
              );
            },
          ),
          // Tags button.
          IconButton(
            icon: Icon(
              Icons.tag,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TagsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Expense Name',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_rupee,
                            color: colorScheme.onSurfaceVariant),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.backspace,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: _deleteLastDigit,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Tag:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Horizontally scrolling list of ChoiceChips for tag selection.
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: settingsProvider.tags.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final tag = settingsProvider.tags[index];
                          return ChoiceChip(
                            label: Text(tag.name),
                            selected: _selectedTag == tag.name,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTag = tag.name;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (var i = 1; i <= 9; i++)
                  NumberButton(
                    number: i.toString(),
                    onPressed: () => _addNumber(i.toString()),
                  ),
                NumberButton(
                  number: '.',
                  onPressed: () => _addNumber('.'),
                ),
                NumberButton(
                  number: '0',
                  onPressed: () => _addNumber('0'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    if (_amount.isNotEmpty && _nameController.text.isNotEmpty) {
                      context.read<ExpenseProvider>().addExpense(
                            _nameController.text,
                            double.parse(_amount),
                            _selectedTag ?? settingsProvider.defaultTag,
                          );
                      _clear();
                      _nameController.clear();
                    }
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    color: colorScheme.onSecondaryContainer,
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NumberButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;
  const NumberButton({
    super.key,
    required this.number,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
