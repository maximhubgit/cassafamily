import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';

class MonthlyClosingScreen extends ConsumerWidget {
  const MonthlyClosingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return subjectsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (subjects) => transactionsAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
        data: (transactions) => _MonthlyClosingContent(
          subjects: subjects,
          transactions: transactions,
        ),
      ),
    );
  }
}

class _MonthlyClosingContent extends StatefulWidget {
  final List<Subject> subjects;
  final List<AppTransaction> transactions;

  const _MonthlyClosingContent({
    required this.subjects,
    required this.transactions,
  });

  @override
  _MonthlyClosingContentState createState() => _MonthlyClosingContentState();
}

class _MonthlyClosingContentState extends State<_MonthlyClosingContent> {
  late DateTime _selectedMonth;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(2 * 80.0);
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
    for (int i = 2; i >= 1; i--) {
      int year = now.year;
      int month = now.month + i;
      while (month > 12) {
        month -= 12;
        year += 1;
      }
      months.add(DateTime(year, month));
    }
    months.add(DateTime(now.year, now.month));
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

  List<AppTransaction> get _monthTransactions {
    return widget.transactions.where((t) {
      return t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month;
    }).toList();
  }

  _SubjectBalance _calcBalance(Subject subject, List<AppTransaction> txs) {
    final income = txs
        .where((t) => t.type == TransactionType.income && t.subjectId == subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = txs
        .where((t) => t.type == TransactionType.expense && t.subjectId == subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final transferIn = txs
        .where((t) => t.type == TransactionType.transfer && t.toSubjectId == subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final transferOut = txs
        .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final anticipi = txs
        .where((t) => t.type == TransactionType.anticipi && t.subjectId == subject.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = income - expense + transferIn - transferOut;
    return _SubjectBalance(
      subject: subject,
      income: income,
      expense: expense,
      transferIn: transferIn,
      transferOut: transferOut,
      anticipi: anticipi,
      balance: balance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthTxs = _monthTransactions;
    final monthFormat = DateFormat('MMMM yyyy', 'it_IT');

    final balances = widget.subjects
        .map((s) => _calcBalance(s, monthTxs))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chiusura mensile'),
      ),
      body: Column(
        children: [
          _buildMonthPicker(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Riepilogo per ${monthFormat.format(_selectedMonth)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (balances.length >= 2)
                  _buildClosingResult(context, balances),
              ],
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
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

  Widget _buildClosingResult(BuildContext context, List<_SubjectBalance> balances) {
    final sorted = [...balances];
    sorted.sort((a, b) => a.balance.compareTo(b.balance));
    final spentMore = sorted.first;
    final spentLess = sorted.last;

    final diff = spentMore.balance.abs() - spentLess.balance.abs();
    final subtotal = diff / 2;
    final result = subtotal - spentMore.anticipi + spentLess.anticipi;

    final String payer, receiver;
    if (result >= 0) {
      payer = spentLess.subject.name;
      receiver = spentMore.subject.name;
    } else {
      payer = spentMore.subject.name;
      receiver = spentLess.subject.name;
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calcolo chiusura',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildCalcRow(context, '${spentMore.subject.name} ha speso piu (saldo piu negativo)'),
            const SizedBox(height: 8),
            _buildCalcRow(context, 'Valore assoluto saldo ${spentMore.subject.name}',
                '|${spentMore.balance.toStringAsFixed(2)}| = € ${spentMore.balance.abs().toStringAsFixed(2)}'),
            _buildCalcRow(context, 'Valore assoluto saldo ${spentLess.subject.name}',
                '|${spentLess.balance.toStringAsFixed(2)}| = € ${spentLess.balance.abs().toStringAsFixed(2)}'),
            const Divider(),
            _buildCalcRow(context, 'Differenza (|${spentMore.subject.name}| - |${spentLess.subject.name}|)',
                '€ ${diff.toStringAsFixed(2)}'),
            _buildCalcRow(context, 'Divisione per 2', '€ ${subtotal.toStringAsFixed(2)}'),
            _buildCalcRow(context, 'Aggiungi anticipi ${spentMore.subject.name} (€ ${spentMore.anticipi.toStringAsFixed(2)})',
                '+ € ${spentMore.anticipi.toStringAsFixed(2)}'),
            _buildCalcRow(context, 'Sottrai anticipi ${spentLess.subject.name} (€ ${spentLess.anticipi.toStringAsFixed(2)})',
                '- € ${spentLess.anticipi.toStringAsFixed(2)}'),
            const Divider(),
            _buildCalcRow(
              context,
              'Risultato',
              '€ ${result.toStringAsFixed(2)}',
              true,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$payer deve dare a $receiver: € ${result.abs().toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcRow(BuildContext context, String label, [String? value, bool isTotal = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (value != null)
            Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 14 : 12,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectBalance {
  final Subject subject;
  final double income;
  final double expense;
  final double transferIn;
  final double transferOut;
  final double anticipi;
  final double balance;

  _SubjectBalance({
    required this.subject,
    required this.income,
    required this.expense,
    required this.transferIn,
    required this.transferOut,
    required this.anticipi,
    required this.balance,
  });
}
