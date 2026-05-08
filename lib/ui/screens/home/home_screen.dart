import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/ui/widgets/app_drawer.dart';
import 'package:cassa1/ui/router/app_router.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/ui/widgets/voice_transaction_dialog.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = now.month;
      _selectedYear = now.year;
    });
  }

  Future<void> _pickMonthYear(BuildContext context) async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Seleziona mese e anno'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: tempMonth,
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      return DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat('MMMM', 'it_IT').format(DateTime(0, m))),
                      );
                    }),
                    onChanged: (v) => setDialogState(() => tempMonth = v!),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: tempYear,
                    items: List.generate(5, (i) {
                      final y = DateTime.now().year - 2 + i;
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }),
                    onChanged: (v) => setDialogState(() => tempYear = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _selectedMonth = tempMonth;
        _selectedYear = tempYear;
      });
    }
  }

  List<AppTransaction> _monthTx(List<AppTransaction> all, int year, int month) {
    return all.where((t) => t.date.year == year && t.date.month == month).toList();
  }

  double _computeMonthBalance(List<AppTransaction> allTransactions, List<Subject> subjects, int year, int month) {
    final monthTx = allTransactions.where((t) => t.date.year == year && t.date.month == month).toList();
    return subjects.fold<double>(0.0, (acc, s) {
      final subjectTransactions = monthTx.where((t) {
        if (t.type == TransactionType.transfer) {
          return t.fromSubjectId == s.id || t.toSubjectId == s.id;
        }
        return t.subjectId == s.id;
      }).toList();
      final sIncome = subjectTransactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sExpense = subjectTransactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sTransferIn = subjectTransactions
          .where((t) => t.type == TransactionType.transfer && t.toSubjectId == s.id)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sTransferOut = subjectTransactions
          .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == s.id)
          .fold(0.0, (acc, t) => acc + t.amount);
      return acc + sIncome - sExpense + sTransferIn - sTransferOut;
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (subjects) => transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (transactions) => groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Errore: $e')),
            data: (groups) => entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (entries) {
                final latest = transactions.take(5).toList();
                final currentTx = _monthTx(transactions, now.year, now.month);

                final income = currentTx
                    .where((t) => t.type == TransactionType.income)
                    .fold(0.0, (acc, t) => acc + t.amount);
                final expense = currentTx
                    .where((t) => t.type == TransactionType.expense)
                    .fold(0.0, (acc, t) => acc + t.amount);
                final anticipi = currentTx
                    .where((t) => t.type == TransactionType.anticipi)
                    .fold(0.0, (acc, t) => acc + t.amount);
                final balance = income - expense;

                final selectedTx = _monthTx(transactions, _selectedYear, _selectedMonth);
                final totalBalance = subjects.fold<double>(0.0, (acc, s) {
                  final subjectTransactions = selectedTx.where((t) {
                    if (t.type == TransactionType.transfer) {
                      return t.fromSubjectId == s.id || t.toSubjectId == s.id;
                    }
                    return t.subjectId == s.id;
                  }).toList();
                  final sIncome = subjectTransactions
                      .where((t) => t.type == TransactionType.income)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  final sExpense = subjectTransactions
                      .where((t) => t.type == TransactionType.expense)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  final sTransferIn = subjectTransactions
                      .where((t) => t.type == TransactionType.transfer && t.toSubjectId == s.id)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  final sTransferOut = subjectTransactions
                      .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == s.id)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  return acc + sIncome - sExpense + sTransferIn - sTransferOut;
                });

                final yearBalances = <double>[];
                for (int m = 1; m <= 12; m++) {
                  final bal = _computeMonthBalance(transactions, subjects, _selectedYear, m);
                  if (transactions.any((t) => t.date.year == _selectedYear && t.date.month == m)) {
                    yearBalances.add(bal);
                  }
                }
                final yearAvgBalance = yearBalances.isNotEmpty
                    ? yearBalances.fold(0.0, (a, b) => a + b) / yearBalances.length
                    : 0.0;

                final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
                final prevMonthYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;
                final prevMonthBalance = _computeMonthBalance(transactions, subjects, prevMonthYear, prevMonth);

                final twentyFourMonthBalances = <double>[];
                for (int i = 1; i <= 24; i++) {
                  int m = _selectedMonth - i;
                  int y = _selectedYear;
                  while (m <= 0) {
                    m += 12;
                    y -= 1;
                  }
                  if (transactions.any((t) => t.date.year == y && t.date.month == m)) {
                    twentyFourMonthBalances.add(_computeMonthBalance(transactions, subjects, y, m));
                  }
                }
                final twentyFourMonthAvg = twentyFourMonthBalances.isNotEmpty
                    ? twentyFourMonthBalances.fold(0.0, (a, b) => a + b) / twentyFourMonthBalances.length
                    : 0.0;

                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: subjects.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Nessun soggetto. Aggiungine uno!',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    )
                                  : GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: subjects.length,
                                      itemBuilder: (context, index) {
                                        final s = subjects[index];
                                        final subjectTransactions = selectedTx.where((t) {
                                          if (t.type == TransactionType.transfer) {
                                            return t.fromSubjectId == s.id || t.toSubjectId == s.id;
                                          }
                                          return t.subjectId == s.id;
                                        }).toList();
                                        final sIncome = subjectTransactions
                                            .where((t) => t.type == TransactionType.income)
                                            .fold(0.0, (acc, t) => acc + t.amount);
                                        final sExpense = subjectTransactions
                                            .where((t) => t.type == TransactionType.expense)
                                            .fold(0.0, (acc, t) => acc + t.amount);
                                        final sTransferIn = subjectTransactions
                                            .where((t) => t.type == TransactionType.transfer && t.toSubjectId == s.id)
                                            .fold(0.0, (acc, t) => acc + t.amount);
                                        final sTransferOut = subjectTransactions
                                            .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == s.id)
                                            .fold(0.0, (acc, t) => acc + t.amount);
                                        final subjectBalance = sIncome - sExpense + sTransferIn - sTransferOut;

                                        return _buildSubjectCard(context, s, subjectBalance, subjectTransactions.length);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _buildTotalBalanceCard(
                              context,
                              totalBalance,
                              yearAvgBalance,
                              prevMonthBalance,
                              twentyFourMonthAvg,
                              _selectedMonth,
                              _selectedYear,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              flex: 3,
                              child: _buildLatestTransactionsCard(
                                context,
                                latest,
                                transactions,
                                subjects,
                                entries,
                                groups,
                                income,
                                expense,
                                anticipi,
                                balance,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildQuickActions(context, ref),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestTransactionsCard(
    BuildContext context,
    List<AppTransaction> latest,
    List<AppTransaction> allTransactions,
    List<Subject> subjects,
    List<Entry> entries,
    List<Group> groups,
    double income,
    double expense,
    double anticipi,
    double balance,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => context.push('/all-transactions'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Ultime transazioni',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: latest.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: latest.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final t = latest[index];

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

                          String subjectName;
                          if (t.type == TransactionType.transfer) {
                            final from = subjects.where((s) => s.id == t.fromSubjectId).firstOrNull;
                            final to = subjects.where((s) => s.id == t.toSubjectId).firstOrNull;
                            subjectName = '${from?.name ?? "?"} → ${to?.name ?? "?"}';
                          } else {
                            final s = subjects.where((s) => s.id == t.subjectId).firstOrNull;
                            subjectName = s?.name ?? '?';
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: amountColor, size: 16),
                              const SizedBox(width: 6),
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
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            subjectName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '€ ${t.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: amountColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (t.type != TransactionType.transfer) ...[
                                      const SizedBox(height: 2),
                                      _buildHomeEntryGroupRow(context, t, entries, groups),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const Divider(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTotalItem(context, 'Entrate', income, AppColors.incomeColor),
                    const SizedBox(width: 12),
                    _buildTotalItem(context, 'Uscite', expense, AppColors.expenseColor),
                    const SizedBox(width: 12),
                    _buildTotalItem(context, 'Anticipi', anticipi, AppColors.anticipiColor),
                    const SizedBox(width: 12),
                    _buildTotalItem(context, 'Saldo', balance, balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalItem(BuildContext context, String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          '€ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeEntryGroupRow(BuildContext context, AppTransaction t, List<Entry> entries, List<Group> groups) {
    if (t.type == TransactionType.transfer) return const SizedBox.shrink();

    final entry = entries.where((e) => e.id == t.entryId).firstOrNull;
    if (entry == null) {
      return Text(
        'Voce eliminata',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final group = groups.where((g) => g.id == entry.groupId).firstOrNull;
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
        Text(entry.name, style: Theme.of(context).textTheme.bodySmall),
        Text(' - ', style: Theme.of(context).textTheme.bodySmall),
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

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickAction(icon: Icons.folder, label: AppStrings.groups, onTap: () => context.push('/groups')),
          _QuickAction(icon: Icons.receipt, label: AppStrings.entries, onTap: () => context.push('/entries')),
          _QuickAction(
            icon: Icons.mic,
            label: 'Voce',
            onTap: () async {
              final subjectsList = ref.read(subjectsProvider).valueOrNull ?? [];
              final entries = ref.read(entriesProvider).valueOrNull ?? [];
              final groups = ref.read(groupsProvider).valueOrNull ?? [];
              if (subjectsList.isEmpty) return;
              final result = await showDialog<VoiceTransactionResult>(
                context: context,
                builder: (_) => VoiceTransactionDialog(
                  subjects: subjectsList,
                  entries: entries,
                  groups: groups,
                  preselectedSubjectId: null,
                ),
              );
              if (result != null && !result.isError && context.mounted) {
                _saveVoiceTransaction(context, ref, result);
              }
            },
          ),
          _QuickAction(icon: Icons.bar_chart, label: AppStrings.reports, onTap: () => context.push('/reports')),
          _QuickAction(icon: Icons.list_alt, label: 'Movimenti', onTap: () => context.push('/all-transactions')),
        ],
      ),
    );
  }

  void _saveVoiceTransaction(
    BuildContext context,
    WidgetRef ref,
    VoiceTransactionResult voiceResult,
  ) {
    final firebaseService = ref.read(firebaseServiceProvider);
    final now = DateTime.now();
    final selectedDate = voiceResult.date ??
        ((now.year == DateTime.now().year && now.month == DateTime.now().month)
            ? DateTime(now.year, now.month, now.day)
            : DateTime(now.year, now.month + 1, 0));

    final transaction = AppTransaction(
      id: FirebaseFirestore.instance.collection('transactions').doc().id,
      type: voiceResult.type,
      amount: voiceResult.amount,
      date: selectedDate,
      subjectId: voiceResult.type == TransactionType.transfer ? null : voiceResult.subjectId,
      fromSubjectId: voiceResult.type == TransactionType.transfer ? voiceResult.fromSubjectId : null,
      toSubjectId: voiceResult.type == TransactionType.transfer ? voiceResult.toSubjectId : null,
      entryId: voiceResult.type == TransactionType.transfer ? null : voiceResult.entryId,
      note: voiceResult.note?.isNotEmpty == true ? voiceResult.note : null,
      createdAt: DateTime.now(),
    );

    firebaseService.addTransaction(transaction).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transazione salvata'), backgroundColor: Colors.green),
        );
      }
    });
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject, double balance, int txCount) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => context.push('/subjects/${subject.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(_getIconData(subject.icon), color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                subject.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '€ ${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              Text(
                '$txCount movimenti',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'person_outline':
        return Icons.person_outline;
      default:
        return Icons.person;
    }
  }

  Widget _buildTotalBalanceCard(
    BuildContext context,
    double totalBalance,
    double yearAvgBalance,
    double prevMonthBalance,
    double twentyFourMonthAvg,
    int selectedMonth,
    int selectedYear,
  ) {
    final monthName = DateFormat('MMM yyyy', 'it_IT').format(DateTime(selectedYear, selectedMonth));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _pickMonthYear(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        monthName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  Text(
                    '€ ${totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: totalBalance >= 0 ? AppColors.incomeColor : AppColors.expenseColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildPercIndicator(context, totalBalance, yearAvgBalance, 'Anno', Icons.calendar_today),
                  _buildPercIndicator(context, totalBalance, prevMonthBalance, 'Mese', Icons.arrow_back),
                  _buildPercIndicator(context, totalBalance, twentyFourMonthAvg, '24m', Icons.date_range),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPercIndicator(BuildContext context, double current, double reference, String label, IconData icon) {
    if (reference == 0) {
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          Text('N/A', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
        ],
      );
    }
    final perc = (current / reference.abs()) * 100;
    final isUp = current >= reference;
    final color = isUp ? AppColors.incomeColor : AppColors.expenseColor;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: color),
            Text(
              '${perc.abs().toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primary.withValues(alpha: 0.1),
              child: Icon(icon, color: primary),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
