import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/utils/icon_helper.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String? groupId;
  final String? entryId;

  const ReportDetailScreen({this.groupId, this.entryId, super.key})
      : assert(
          (groupId != null) ^ (entryId != null),
          'Pass exactly one of groupId or entryId',
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    return transactionsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Caricamento...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (transactions) => subjectsAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Caricamento...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Errore')),
          body: Center(child: Text('Errore: $e')),
        ),
        data: (subjects) => groupsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Caricamento...')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Errore')),
            body: Center(child: Text('Errore: $e')),
          ),
          data: (groups) => entriesAsync.when(
            loading: () => Scaffold(
              appBar: AppBar(title: const Text('Caricamento...')),
              body: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Scaffold(
              appBar: AppBar(title: const Text('Errore')),
              body: Center(child: Text('Errore: $e')),
            ),
            data: (entries) {
              final title = _buildTitle(groups, entries);
              final filteredTxs = transactions.where((t) {
                if (groupId != null) {
                  if (t.entryId == null) return false;
                  final entry = entries.where((e) => e.id == t.entryId).firstOrNull;
                  return entry?.groupId == groupId;
                }
                if (entryId != null) {
                  return t.entryId == entryId;
                }
                return false;
              }).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              final total = filteredTxs.fold(0.0, (sum, t) => sum + t.amount);

              return Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Text(
                          '€ ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                body: filteredTxs.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna transazione',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTxs.length,
                        itemBuilder: (context, index) {
                          final t = filteredTxs[index];
                          return _buildTransactionTile(
                            context,
                            t,
                            subjects,
                            entries,
                            groups,
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _buildTitle(List<Group> groups, List<Entry> entries) {
    if (entryId != null) {
      final entry = entries.where((e) => e.id == entryId).firstOrNull;
      return entry?.name ?? 'Voce eliminata';
    }
    if (groupId != null) {
      final group = groups.where((g) => g.id == groupId).firstOrNull;
      return group?.name ?? 'Gruppo eliminato';
    }
    return 'Dettaglio';
  }

  Widget _buildTransactionTile(
    BuildContext context,
    AppTransaction t,
    List<Subject> subjects,
    List<Entry> entries,
    List<Group> groups,
  ) {
    IconData icon;
    Color color;

    if (t.type == TransactionType.transfer) {
      icon = Icons.swap_horiz;
      color = AppColors.transferColor;
    } else if (t.type == TransactionType.anticipi) {
      icon = Icons.payment;
      color = AppColors.anticipiColor;
    } else if (t.type == TransactionType.income) {
      icon = Icons.trending_up;
      color = AppColors.incomeColor;
    } else {
      icon = Icons.trending_down;
      color = AppColors.expenseColor;
    }

    String subjectName = '';
    if (t.type == TransactionType.transfer) {
      final from = subjects.where((s) => s.id == t.fromSubjectId).firstOrNull;
      final to = subjects.where((s) => s.id == t.toSubjectId).firstOrNull;
      subjectName = '${from?.name ?? '?'} → ${to?.name ?? '?'}';
    } else {
      final s = subjects.where((s) => s.id == t.subjectId).firstOrNull;
      subjectName = s?.name ?? 'N/D';
    }

    String? entryLabel;
    if (t.entryId != null) {
      final entry = entries.where((e) => e.id == t.entryId).firstOrNull;
      if (entry != null) {
        final group = groups.where((g) => g.id == entry.groupId).firstOrNull;
        entryLabel = entry.name + (group != null ? ' (${group.name})' : '');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          entryLabel ?? (t.note?.isNotEmpty == true ? t.note! : 'Trasferimento'),
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(t.date)} - $subjectName',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '€ ${t.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
