import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../providers/expense_provider.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});
  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final TextEditingController _tagController = TextEditingController();

  // Function to show a confirmation dialog before deleting a tag.
  Future<bool> _confirmDeletion(String tagName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete the tag "$tagName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Function to show an edit modal for updating allowance details.
  Future<void> _showEditTagModal(Tag tag) async {
    final allowanceController = TextEditingController(
        text: tag.allowanceLimit != null ? tag.allowanceLimit!.toStringAsFixed(2) : '');
    final durationController = TextEditingController(text: tag.duration.toString());
    DateTime startDate = tag.allowanceStart ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              // Compute expiration details.
              final duration = int.tryParse(durationController.text) ?? 30;
              final expiryDate = startDate.add(Duration(days: duration));
              final daysLeft = expiryDate.difference(DateTime.now()).inDays;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Tag: ${tag.name}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: allowanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Allowance Limit (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duration (days, default 30)',
                        border: const OutlineInputBorder(),
                        helperText: 'Expires in $daysLeft day(s)',
                      ),
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
                            final newAllowance =
                                double.tryParse(allowanceController.text);
                            final newDuration = int.tryParse(durationController.text) ?? 30;
                            final updatedTag = Tag(
                              name: tag.name,
                              allowanceLimit: newAllowance,
                              duration: newDuration,
                              allowanceStart: startDate,
                            );
                            context.read<SettingsProvider>().updateTag(updatedTag);
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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    // Also pull expense data so we can show spending info per tag.
    final expenseProvider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input area to add a new tag.
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'Enter new tag',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final tagName = _tagController.text.trim();
                        if (tagName.isNotEmpty) {
                          settingsProvider.addTag(tagName);
                          _tagController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // List of tags as full-width item cards with swipe to edit and delete.
            Expanded(
              child: settingsProvider.tags.isEmpty
                  ? Center(
                      child: Text(
                        'No tags added yet.',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    )
                  : ListView.separated(
                      itemCount: settingsProvider.tags.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tag = settingsProvider.tags[index];
                        // Get expense info for this tag.
                        final tagExpenses = expenseProvider.expenses
                            .where((exp) =>
                                exp.tag.toLowerCase() ==
                                tag.name.toLowerCase())
                            .toList();
                        final currentUsed = tagExpenses.fold(
                            0.0, (sum, exp) => sum + exp.amount);
                        final numTransactions = tagExpenses.length;
                        // If allowance is set, calculate remaining and usage percentage.
                        double allowanceLimit = tag.allowanceLimit ?? 0;
                        double leftAmount = tag.allowanceLimit != null
                            ? allowanceLimit - currentUsed
                            : 0;
                        double usagePercent = tag.allowanceLimit != null &&
                                allowanceLimit > 0
                            ? (currentUsed / allowanceLimit) * 100
                            : 0;
                        int daysLeft = 0;
                        if (tag.allowanceLimit != null) {
                          final start =
                              tag.allowanceStart ?? DateTime.now();
                          final expiryDate =
                              start.add(Duration(days: tag.duration));
                          daysLeft = expiryDate.difference(DateTime.now()).inDays;
                        }
                        bool isOverspent = tag.allowanceLimit != null &&
                            currentUsed > allowanceLimit;
                        Color indicatorColor =
                            isOverspent ? Colors.red : Colors.green;
                        double overspendAmount =
                            isOverspent ? currentUsed - allowanceLimit : 0;

                        return Container(
                          width: double.infinity,
                          child: Dismissible(
                            key: Key(tag.name),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                // Delete action: ask for confirmation.
                                bool confirmed =
                                    await _confirmDeletion(tag.name);
                                if (confirmed) {
                                  await settingsProvider.removeTag(tag.name);
                                }
                                return confirmed;
                              } else if (direction ==
                                  DismissDirection.endToStart) {
                                // Edit action.
                                await _showEditTagModal(tag);
                                return false;
                              }
                              return false;
                            },
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Tag Name.
                                    Text(
                                      tag.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    // Display allowance details if set. Otherwise, show a message.
                                    if (tag.allowanceLimit != null) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Allowance Limit:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            '₹${allowanceLimit.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Amount Used:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            '₹${currentUsed.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Remaining:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            '₹${leftAmount.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Transactions:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            '$numTransactions',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Days Left:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Text(
                                            '$daysLeft',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Usage:',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '${usagePercent.toStringAsFixed(1)}%',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium!
                                                    .copyWith(
                                                        color: indicatorColor,
                                                        fontWeight: FontWeight.bold),
                                              ),
                                              if (isOverspent)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 8.0),
                                                  child: Text(
                                                    'Overspent by ₹${overspendAmount.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall!
                                                        .copyWith(
                                                            color: Colors.red),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // When no allowance is set, show a placeholder line.
                                      Text(
                                        'No allowance set',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
