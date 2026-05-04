import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/utils/constants.dart';
// import 'package:cassa1/utils/icon_helper.dart'; // TODO: rimuovere se non serve
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.transactions),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: AppStrings.add,
            onPressed: () {
              final subjects = ref.read(subjectsProvider).asData?.value ?? [];
              final groups = ref.read(groupsProvider).asData?.value ?? [];
              final entries = ref.read(entriesProvider).asData?.value ?? [];
              if (subjects.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crea prima un soggetto')),
                );
                return;
              }
              _showAddDialog(context, ref, subjects, groups, entries);
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (transactions) {
          return subjectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Errore: $error')),
            data: (subjects) {
              return groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Errore: $error')),
                data: (groups) {
                  return entriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Errore: $error')),
                    data: (entries) {
                      if (transactions.isEmpty) {
                        return Center(
                          child: Text(
                            'Nessun movimento. Aggiungine uno!',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          return _buildTransactionTile(
                            context,
                            ref,
                            t,
                            subjects,
                            groups,
                            entries,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    AppTransaction t,
    List<Subject> subjects,
    List<Group> groups,
    List<Entry> entries,
  ) {
    String title = '';
    if (t.type == TransactionType.transfer) {
      final from = _findSubject(subjects, t.fromSubjectId);
      final to = _findSubject(subjects, t.toSubjectId);
      title = 'Trasferimento: ${from.name} → ${to.name}';
    } else {
      final subject = _findSubject(subjects, t.subjectId);
      title = '${subject.name}: ${t.note ?? "Senza nota"}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          t.type == TransactionType.income
              ? Icons.trending_up
              : t.type == TransactionType.expense
                  ? Icons.trending_down
                  : Icons.swap_horiz,
          color: t.type == TransactionType.income
              ? AppColors.incomeColor
              : t.type == TransactionType.expense
                  ? AppColors.expenseColor
                  : AppColors.transferColor,
        ),
        title: Text(title),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(t.date)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '€ ${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: t.type == TransactionType.income
                    ? AppColors.incomeColor
                    : AppColors.expenseColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _confirmDelete(context, ref, t.id),
            ),
          ],
        ),
      ),
    );
  }

  Subject _findSubject(List<Subject> subjects, String? id) {
    if (id == null) return Subject(id: '', name: 'N/A', icon: 'person', createdAt: DateTime.now());
    final matching = subjects.where((s) => s.id == id);
    return matching.isEmpty
        ? Subject(id: '', name: 'N/A', icon: 'person', createdAt: DateTime.now())
        : matching.first;
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    List<Subject> subjects,
    List<Group> groups,
    List<Entry> entries,
  ) {
    TransactionType selectedType = TransactionType.expense;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedSubjectId;
    String? selectedFromSubjectId;
    String? selectedToSubjectId;
    String? selectedEntryId;
    DateTime selectedDate = DateTime.now();

    final outerContext = context;
    showDialog(
      context: outerContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final filteredGroups = groups.where((g) {
            if (selectedType == TransactionType.income) return g.type == GroupType.income;
            if (selectedType == TransactionType.expense || selectedType == TransactionType.anticipi) return g.type == GroupType.expense;
            return true;
          }).toList();

          final filteredEntries = entries.where((e) {
            return filteredGroups.any((g) => g.id == e.groupId);
          }).toList();

          return AlertDialog(
            title: const Text('Nuovo Movimento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<TransactionType>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: TransactionType.income, child: Text('Entrata')),
                      DropdownMenuItem(value: TransactionType.expense, child: Text('Uscita')),
                      DropdownMenuItem(value: TransactionType.transfer, child: Text('Trasferimento')),
                      DropdownMenuItem(value: TransactionType.anticipi, child: Text('Anticipo')),
                    ],
                    onChanged: (value) => setState(() => selectedType = value!),
                  ),
                  const SizedBox(height: 12),
                  // Date picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: AppStrings.amount),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  if (selectedType != TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedSubjectId,
                      isExpanded: true,
                      hint: const Text('Seleziona soggetto'),
                      items: subjects.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedSubjectId = value),
                    ),
                    const SizedBox(height: 16),
                    if (filteredGroups.isNotEmpty)
                      DropdownButton<String>(
                        value: selectedEntryId,
                        isExpanded: true,
                        hint: const Text('Seleziona voce'),
                        items: filteredEntries.map((e) {
                          final matching = filteredGroups.where((g) => g.id == e.groupId);
                          final group = matching.isEmpty ? null : matching.first;
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.name} (${group?.name ?? ""})'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedEntryId = value),
                      ),
                  ],
                  if (selectedType == TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedFromSubjectId,
                      isExpanded: true,
                      hint: const Text('Da soggetto'),
                      items: subjects.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedFromSubjectId = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButton<String>(
                      value: selectedToSubjectId,
                      isExpanded: true,
                      hint: const Text('A soggetto'),
                      items: subjects.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedToSubjectId = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: AppStrings.note),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () {
                  final amountText = amountController.text.trim();
                  final amount = double.tryParse(amountText);

                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inserisci un importo valido'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (selectedType == TransactionType.transfer) {
                    if (selectedFromSubjectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona il soggetto di origine'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (selectedToSubjectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona il soggetto di destinazione'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (selectedFromSubjectId == selectedToSubjectId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('I soggetti di origine e destinazione devono essere diversi'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                  } else {
                    if (selectedSubjectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona un soggetto'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (selectedEntryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona una voce'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                  }

                  final repo = ref.read(transactionRepositoryProvider);
                  final newTransaction = AppTransaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: selectedType,
                    amount: amount,
                    date: selectedDate,
                    note: noteController.text.isEmpty ? null : noteController.text,
                    subjectId: selectedType != TransactionType.transfer ? selectedSubjectId : null,
                    entryId: selectedType != TransactionType.transfer ? selectedEntryId : null,
                    fromSubjectId: selectedType == TransactionType.transfer ? selectedFromSubjectId : null,
                    toSubjectId: selectedType == TransactionType.transfer ? selectedToSubjectId : null,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newTransaction);
                  Navigator.pop(dialogContext);
                },
                child: const Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(transactionRepositoryProvider).delete(id);
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
