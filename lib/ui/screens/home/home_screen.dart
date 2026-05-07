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
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/ui/widgets/voice_transaction_dialog.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    // Filtro transazioni mese corrente
    List<AppTransaction> currentMonthTx(List<AppTransaction> all) {
      final now = DateTime.now();
      return all.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
    }

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
                final currentTx = currentMonthTx(transactions);

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

                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
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
                                        final subjectTransactions = currentTx.where((t) {
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
                            Expanded(
                              flex: 2,
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
              Row(
                children: [
                  Text(
                    'Ultime transazioni',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '€ ${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor,
                    ),
                  ),
                ],
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(_getIconData(subject.icon), color: Theme.of(context).colorScheme.primary, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                subject.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '€ ${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: balance >= 0 ? AppColors.incomeColor : AppColors.expenseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
