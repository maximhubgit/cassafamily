import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';
import 'package:cassa1/ui/widgets/voice_transaction_dialog.dart';
import 'package:cassa1/ui/widgets/entry_picker.dart';

class SubjectDetailScreen extends ConsumerWidget {
  final String subjectId;
  const SubjectDetailScreen({required this.subjectId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    return subjectsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (subjects) {
        final subject = subjects.firstWhere(
          (s) => s.id == subjectId,
          orElse: () => Subject(id: '', name: 'N/A', icon: '', createdAt: DateTime.now()),
        );
        if (subject.id.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Non trovato')),
            body: const Center(child: Text('Soggetto non trovato')),
          );
        }

        return transactionsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(subject.name)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: Text(subject.name)),
            body: Center(child: Text('Errore: $e')),
          ),
          data: (transactions) {
            return groupsAsync.when(
              loading: () => Scaffold(
                appBar: AppBar(title: Text(subject.name)),
                body: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Scaffold(
                appBar: AppBar(title: Text(subject.name)),
                body: Center(child: Text('Errore: $e')),
              ),
              data: (groups) => entriesAsync.when(
                loading: () => Scaffold(
                  appBar: AppBar(title: Text(subject.name)),
                  body: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Scaffold(
                  appBar: AppBar(title: Text(subject.name)),
                  body: Center(child: Text('Errore: $e')),
                ),
                data: (entries) {
                  return _SubjectDetailContent(
                    subject: subject,
                    allTransactions: transactions,
                    subjects: subjects,
                    groups: groups,
                    entries: entries,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _SubjectDetailContent extends ConsumerStatefulWidget {
  final Subject subject;
  final List<AppTransaction> allTransactions;
  final List<Subject> subjects;
  final List<Group> groups;
  final List<Entry> entries;

  const _SubjectDetailContent({
    required this.subject,
    required this.allTransactions,
    required this.subjects,
    required this.groups,
    required this.entries,
  });

  @override
  _SubjectDetailContentState createState() => _SubjectDetailContentState();
}

class _SubjectDetailContentState extends ConsumerState<_SubjectDetailContent> {
  late DateTime _selectedMonth;
  final _scrollController = ScrollController();
  var _showAnticipi = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    // Scrolla in modo che il mese corrente sia visibile (è il terzo nella lista: indice 2)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(2 * 80.0); // 2 future months * ~80px each
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> get _availableMonths {
    final months = <DateTime>[];
    final now = DateTime.now();
    // Mesi futuri (max 2)
    for (int i = 2; i >= 1; i--) {
      int year = now.year;
      int month = now.month + i;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      months.add(DateTime(year, month));
    }
    // Mese corrente
    months.add(DateTime(now.year, now.month));
    // Mesi passati (12)
    for (int i = 1; i <= 12; i++) {
      int year = now.year;
      int month = now.month - i;
      while (month < 1) {
        month += 12;
        year -= 1;
      }
      months.add(DateTime(year, month));
    }
    return months;
  }

  List<AppTransaction> get _filteredTransactions {
    return widget.allTransactions.where((t) {
      final isRelevant = t.type == TransactionType.transfer
          ? t.fromSubjectId == widget.subject.id || t.toSubjectId == widget.subject.id
          : t.subjectId == widget.subject.id;
      if (!isRelevant) return false;
      return t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month;
    }).toList();
  }

  List<AppTransaction> get _listTransactions {
    final txs = _filteredTransactions;
    if (!_showAnticipi) {
      return txs.where((t) => t.type != TransactionType.anticipi).toList();
    }
    return txs;
  }

  @override
  Widget build(BuildContext context) {
    // Transazioni filtrate per mese selezionato (per i totali)
    final subjectTxs = _filteredTransactions;
    // Lista transazioni (con filtro anticipi)
    final listTxs = _listTransactions;

    final income = subjectTxs
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = subjectTxs
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final transferIn = subjectTxs
        .where((t) => t.type == TransactionType.transfer && t.toSubjectId == widget.subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final transferOut = subjectTxs
        .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == widget.subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final anticipi = subjectTxs
        .where((t) => t.type == TransactionType.anticipi)
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = income - expense + transferIn - transferOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Nuova transazione vocale',
            onPressed: () => _showVoiceDialog(context, ref, widget.subject),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuova transazione',
            onPressed: () => _showAddDialog(context, ref, widget.subject, widget.groups, widget.entries),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthPicker(context),
          _buildMonthBalanceHeader(context, income, expense, transferIn, transferOut, anticipi, balance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Movimenti (${listTxs.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'Mese: € ${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor,
                  ),
                ),
              ],
            ),
          ),
          // Switch per mostrare/nascondere anticipi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Mostra anticipi',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Switch(
                  value: _showAnticipi,
                  onChanged: (v) => setState(() => _showAnticipi = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: listTxs.isEmpty
                ? Center(
                    child: Text(
                      _showAnticipi
                          ? 'Nessun movimento in questo mese'
                          : 'Nessun movimento. Attiva "Mostra anticipi" per vederli.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: listTxs.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionTile(
                        context,
                        ref,
                        listTxs[index],
                        widget.subject,
                        widget.groups,
                        widget.entries,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    final months = _availableMonths;
    final monthFormat = DateFormat('MMM yy', 'it_IT');

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected = month.year == _selectedMonth.year && month.month == _selectedMonth.month;
          return Center(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMonth = month),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthFormat.format(month),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthBalanceHeader(
    BuildContext context,
    double income,
    double expense,
    double transferIn,
    double transferOut,
    double anticipi,
    double balance,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBalanceItem(context, 'Entrate', income, AppColors.incomeColor),
          _buildBalanceItem(context, 'Uscite', expense, AppColors.expenseColor),
          _buildBalanceItem(context, 'Trasf.', transferIn - transferOut, AppColors.transferColor),
          _buildBalanceItem(context, 'Anticipi', anticipi, AppColors.transferColor),
          _buildBalanceItem(context, 'Saldo', balance, balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(BuildContext context, String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '€ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    AppTransaction t,
    Subject subject,
    List<Group> groups,
    List<Entry> entries,
  ) {
    Color amountColor;
    IconData icon;

    if (t.type == TransactionType.transfer) {
      icon = Icons.swap_horiz;
      amountColor = AppColors.transferColor;
    } else if (t.type == TransactionType.anticipi) {
      icon = Icons.payment;
      amountColor = AppColors.anticipiColor;
    } else {
      icon = t.type == TransactionType.income ? Icons.trending_up : Icons.trending_down;
      amountColor = t.type == TransactionType.income ? AppColors.incomeColor : AppColors.expenseColor;
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(t.date);

    String subjectDisplay;
    if (t.type == TransactionType.transfer) {
      final fromName = t.fromSubjectId == subject.id ? 'Questo soggetto' : _findSubjectName(t.fromSubjectId);
      final toName = t.toSubjectId == subject.id ? 'Questo soggetto' : _findSubjectName(t.toSubjectId);
      subjectDisplay = '$fromName → $toName';
    } else {
      subjectDisplay = _findSubjectName(t.subjectId);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _showEditDialog(context, ref, t, subject, groups, entries),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: amountColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subjectDisplay,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '€ ${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (t.type != TransactionType.transfer) ...[
                      const SizedBox(height: 4),
                      _buildEntryGroupRow(context, t, entries, groups),
                    ],
                    if (t.note != null && t.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryGroupRow(BuildContext context, AppTransaction t, List<Entry> entries, List<Group> groups) {
    final entry = _findEntry(entries, t.entryId);
    if (entry == null) {
      return Text(
        'Voce eliminata',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final group = _findGroup(groups, entry.groupId);
    if (group == null) {
      return Text(
        entry.name,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      children: [
        Text(
          entry.name,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          ' - ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Expanded(
          child: Text(
            group.name,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _findSubjectName(String? id) {
    if (id == null) return '?';
    final matching = widget.subjects.where((s) => s.id == id);
    return matching.isEmpty ? '?' : matching.first.name;
  }

  Entry? _findEntry(List<Entry> entries, String? id) {
    if (id == null) return null;
    final matching = entries.where((e) => e.id == id);
    return matching.isEmpty ? null : matching.first;
  }

  Group? _findGroup(List<Group> groups, String? id) {
    if (id == null) return null;
    final matching = groups.where((g) => g.id == id);
    return matching.isEmpty ? null : matching.first;
  }

  String _entryLabel(String? entryId, List<Entry> entries, List<Group> groups) {
    if (entryId == null) return 'Seleziona voce *';
    final entry = entries.where((e) => e.id == entryId).firstOrNull;
    if (entry == null) return 'Voce eliminata';
    final group = groups.where((g) => g.id == entry.groupId).firstOrNull;
    return '${entry.name}${group != null ? ' (${group.name})' : ''}';
  }

  Widget _buildEntryPickerButton({
    required BuildContext dialogContext,
    required TransactionType selectedType,
    required String? selectedEntryId,
    required void Function(String) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final entryId = await showEntryPicker(
          context: dialogContext,
          groups: widget.groups,
          entries: widget.entries,
          selectedType: selectedType,
          selectedEntryId: selectedEntryId,
        );
        if (entryId != null) {
          onChanged(entryId);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(dialogContext).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _entryLabel(selectedEntryId, widget.entries, widget.groups),
                style: TextStyle(
                  fontSize: 14,
                  color: selectedEntryId != null
                      ? Theme.of(dialogContext).colorScheme.onSurface
                      : Theme.of(dialogContext).hintColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
    List<Group> groups,
    List<Entry> entries,
  ) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    TransactionType selectedType = TransactionType.expense;
    String? selectedEntryId;
        String? selectedFromSubjectId;
    String? selectedToSubjectId;
    String? selectedSubjectId = subject.id;
    final now = DateTime.now();
    DateTime selectedDate = (_selectedMonth.year == now.year && _selectedMonth.month == now.month)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text('Nuovo movimento - ${subject.name}'),
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
                      decoration: const InputDecoration(labelText: 'Data *'),
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
                    decoration: InputDecoration(labelText: '${AppStrings.amount} *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Transfer: from/to subject selectors
                  if (selectedType == TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedFromSubjectId,
                      isExpanded: true,
                      hint: const Text('Da soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedFromSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: selectedToSubjectId,
                      isExpanded: true,
                      hint: const Text('A soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedToSubjectId = value),
                    ),
                  ],
                  // Income/Expense/Anticipi: subject + entry selectors
                  if (selectedType != TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedSubjectId,
                      isExpanded: true,
                      hint: const Text('Soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryPickerButton(
                      dialogContext: dialogContext,
                      selectedType: selectedType,
                      selectedEntryId: selectedEntryId,
                      onChanged: (value) => setState(() => selectedEntryId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                  final newTx = AppTransaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: selectedType,
                    amount: amount,
                    date: selectedDate,
                    note: noteController.text.isEmpty ? null : noteController.text,
                    subjectId: selectedType != TransactionType.transfer ? selectedSubjectId : null,
                    entryId: selectedEntryId,
                    fromSubjectId: selectedType == TransactionType.transfer ? selectedFromSubjectId : null,
                    toSubjectId: selectedType == TransactionType.transfer ? selectedToSubjectId : null,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newTx);
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

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AppTransaction t,
    Subject subject,
    List<Group> groups,
    List<Entry> entries,
  ) {
    final amountController = TextEditingController(text: t.amount.toString());
    final noteController = TextEditingController(text: t.note ?? '');
    String? selectedEntryId = t.entryId;
    DateTime selectedDate = t.date;
    String? selectedFromSubjectId = t.fromSubjectId;
    String? selectedToSubjectId = t.toSubjectId;
    String? selectedSubjectId = t.subjectId ?? subject.id;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Modifica movimento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      decoration: const InputDecoration(labelText: 'Data *'),
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
                    decoration: InputDecoration(labelText: '${AppStrings.amount} *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Transfer: from/to subject selectors
                  if (t.type == TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedFromSubjectId,
                      isExpanded: true,
                      hint: const Text('Da soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedFromSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: selectedToSubjectId,
                      isExpanded: true,
                      hint: const Text('A soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedToSubjectId = value),
                    ),
                  ],
                  // Income/Expense/Anticipi: subject + entry selectors
                  if (t.type != TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedSubjectId,
                      isExpanded: true,
                      hint: const Text('Soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryPickerButton(
                      dialogContext: dialogContext,
                      selectedType: t.type,
                      selectedEntryId: selectedEntryId,
                      onChanged: (value) => setState(() => selectedEntryId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: AppStrings.note),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Elimina',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: dialogContext,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Conferma eliminazione'),
                      content: const Text('Sei sicuro di voler eliminare questa transazione?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(AppStrings.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Elimina', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    if (!dialogContext.mounted) return;
                    final repo = ref.read(transactionRepositoryProvider);
                    repo.delete(t.id);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
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

                  if (t.type == TransactionType.transfer) {
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
                  final updated = AppTransaction(
                    id: t.id,
                    type: t.type,
                    amount: amount,
                    date: selectedDate,
                    note: noteController.text.isEmpty ? null : noteController.text,
                    subjectId: t.type != TransactionType.transfer ? selectedSubjectId : null,
                    entryId: selectedEntryId,
                    fromSubjectId: t.type == TransactionType.transfer ? selectedFromSubjectId : null,
                    toSubjectId: t.type == TransactionType.transfer ? selectedToSubjectId : null,
                    createdAt: t.createdAt,
                  );
                  repo.update(updated);
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

  void _showVoiceDialog(BuildContext context, WidgetRef ref, Subject subject) async {
    final defaultSubjectId = ref.read(defaultSubjectProvider);
    final result = await showDialog<VoiceTransactionResult>(
      context: context,
      builder: (dialogContext) => VoiceTransactionDialog(
        subjects: widget.subjects,
        entries: widget.entries,
        groups: widget.groups,
        defaultSubjectId: defaultSubjectId,
      ),
    );

    if (result != null && !result.isError && mounted) {
      _showAddDialogFromVoice(context, ref, result);
    }
  }

  void _showAddDialogFromVoice(
    BuildContext context,
    WidgetRef ref,
    VoiceTransactionResult voiceResult,
  ) {
    final amountController = TextEditingController(text: voiceResult.amount.toString());
    final noteController = TextEditingController(text: voiceResult.note ?? '');
    TransactionType selectedType = voiceResult.type;
    String? selectedEntryId = voiceResult.entryId;
    String? selectedFromSubjectId = voiceResult.fromSubjectId;
    String? selectedToSubjectId = voiceResult.toSubjectId;
    String? selectedSubjectId = voiceResult.subjectId ?? widget.subject.id;
    DateTime selectedDate;
    if (voiceResult.date != null) {
      selectedDate = voiceResult.date!;
    } else {
      final now = DateTime.now();
      selectedDate = (_selectedMonth.year == now.year && _selectedMonth.month == now.month)
          ? DateTime(now.year, now.month, now.day)
          : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
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
                      decoration: const InputDecoration(labelText: 'Data *'),
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
                    decoration: InputDecoration(labelText: '${AppStrings.amount} *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  if (selectedType == TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedFromSubjectId,
                      isExpanded: true,
                      hint: const Text('Da soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedFromSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: selectedToSubjectId,
                      isExpanded: true,
                      hint: const Text('A soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedToSubjectId = value),
                    ),
                  ],
                  if (selectedType != TransactionType.transfer) ...[
                    DropdownButton<String>(
                      value: selectedSubjectId,
                      isExpanded: true,
                      hint: const Text('Soggetto *'),
                      items: widget.subjects.map((s) {
                        return DropdownMenuItem(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (value) => setState(() => selectedSubjectId = value),
                    ),
                    const SizedBox(height: 12),
                    _buildEntryPickerButton(
                      dialogContext: dialogContext,
                      selectedType: selectedType,
                      selectedEntryId: selectedEntryId,
                      onChanged: (value) => setState(() => selectedEntryId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                  final newTx = AppTransaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: selectedType,
                    amount: amount,
                    date: selectedDate,
                    note: noteController.text.isEmpty ? null : noteController.text,
                    subjectId: selectedType != TransactionType.transfer ? selectedSubjectId : null,
                    entryId: selectedEntryId,
                    fromSubjectId: selectedType == TransactionType.transfer ? selectedFromSubjectId : null,
                    toSubjectId: selectedType == TransactionType.transfer ? selectedToSubjectId : null,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newTx);
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
}
