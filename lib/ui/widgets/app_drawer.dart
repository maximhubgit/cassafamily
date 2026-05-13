import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/logic/providers/theme_provider.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/data/services/export_service.dart';
import 'package:cassa1/data/services/import_service.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/ui/widgets/voice_transaction_dialog.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? [];
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];

    // Filtro transazioni mese corrente
    final now = DateTime.now();
    final currentTx = transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();

    // Calcola saldo di un soggetto (solo mese corrente)
    double subjectBalance(Subject s) {
      final sTx = currentTx.where((t) {
        if (t.type == TransactionType.transfer) {
          return t.fromSubjectId == s.id || t.toSubjectId == s.id;
        }
        return t.subjectId == s.id;
      }).toList();

      final sIncome = sTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sExpense = sTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sTransferIn = sTx
          .where((t) => t.type == TransactionType.transfer && t.toSubjectId == s.id)
          .fold(0.0, (acc, t) => acc + t.amount);
      final sTransferOut = sTx
          .where((t) => t.type == TransactionType.transfer && t.fromSubjectId == s.id)
          .fold(0.0, (acc, t) => acc + t.amount);

      return sIncome - sExpense + sTransferIn - sTransferOut;
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  AppStrings.appName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Chiusura mensile'),
            onTap: () => context.go('/monthly-closing'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Soggetti - ${DateFormat('MMMM yyyy').format(now)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ...subjects.map((s) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(s.name),
                trailing: Text(
                  '€ ${subjectBalance(s).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: subjectBalance(s) >= 0
                        ? AppColors.incomeColor
                        : AppColors.expenseColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/subjects/${s.id}');
                },
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Nuova transazione vocale'),
            onTap: () async {
              Navigator.pop(context);
              final subjectsList = ref.read(subjectsProvider).valueOrNull ?? [];
              final entries = ref.read(entriesProvider).valueOrNull ?? [];
              final groups = ref.read(groupsProvider).valueOrNull ?? [];
              if (subjectsList.isEmpty) return;
              final defaultSubjectId = ref.read(defaultSubjectProvider);
              final result = await showDialog<VoiceTransactionResult>(
                context: context,
                builder: (dialogContext) => VoiceTransactionDialog(
                  subjects: subjectsList,
                  entries: entries,
                  groups: groups,
                  defaultSubjectId: defaultSubjectId,
                ),
              );
              if (result != null && !result.isError && context.mounted) {
                _showVoiceConfirmation(context, ref, result);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Esporta CSV'),
            onTap: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final transactions =
                    await ref.read(transactionsProvider.future);
                final subjects = await ref.read(subjectsProvider.future);
                final entries = await ref.read(entriesProvider.future);
                final groups = await ref.read(groupsProvider.future);
                await ExportService.exportAndShare(
                  messenger: messenger,
                  transactions: transactions,
                  subjects: subjects,
                  entries: entries,
                  groups: groups,
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Errore: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Importa CSV'),
            onTap: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final subjects = await ref.read(subjectsProvider.future);
                final entries = await ref.read(entriesProvider.future);
                final groups = await ref.read(groupsProvider.future);
                final firebaseService = ref.read(firebaseServiceProvider);
                await ImportService.pickAndImport(
                  messenger: messenger,
                  subjects: subjects,
                  entries: entries,
                  groups: groups,
                  firebaseService: firebaseService,
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Errore: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Tema scuro'),
            value: isDark,
            onChanged: (_) {
              ref.read(themeModeProvider.notifier).setTheme(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showVoiceConfirmation(
    BuildContext context,
    WidgetRef ref,
    VoiceTransactionResult voiceResult,
  ) {
    final amountController =
        TextEditingController(text: voiceResult.amount.toString());
    final noteController =
        TextEditingController(text: voiceResult.note ?? '');
    TransactionType selectedType = voiceResult.type;
    String? selectedEntryId = voiceResult.entryId;
    String? selectedFromSubjectId = voiceResult.fromSubjectId;
    String? selectedToSubjectId = voiceResult.toSubjectId;
    String? selectedSubjectId = voiceResult.subjectId;
    DateTime selectedDate;

    if (voiceResult.date != null) {
      selectedDate = voiceResult.date!;
    } else {
      final now = DateTime.now();
      selectedDate = DateTime(now.year, now.month, now.day);
    }

    final entries = ref.read(entriesProvider).valueOrNull ?? [];
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final firebaseService = ref.read(firebaseServiceProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final filteredGroups = groups.where((g) {
            if (selectedType == TransactionType.income) {
              return g.type == GroupType.income;
            }
            if (selectedType == TransactionType.expense ||
                selectedType == TransactionType.anticipi) {
              return g.type == GroupType.expense;
            }
            return true;
          }).toList();

          final filteredEntries = entries.where((e) {
            if (selectedType == TransactionType.transfer) return true;
            return filteredGroups.any((g) => g.id == e.groupId);
          }).toList();

          return AlertDialog(
            title: const Text('Conferma transazione'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<TransactionType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo*'),
                    items: const [
                      DropdownMenuItem(
                        value: TransactionType.income,
                        child: Text('Entrata'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.expense,
                        child: Text('Uscita'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.transfer,
                        child: Text('Trasferimento'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.anticipi,
                        child: Text('Anticipo'),
                      ),
                    ],
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType == TransactionType.transfer) ...[
                    DropdownButtonFormField<String>(
                      value: selectedFromSubjectId,
                      decoration:
                          const InputDecoration(labelText: 'Da soggetto*'),
                      items: ref
                          .watch(subjectsProvider)
                          .valueOrNull
                          ?.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList() ??
                          [],
                      onChanged: (v) =>
                          setState(() => selectedFromSubjectId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedToSubjectId,
                      decoration:
                          const InputDecoration(labelText: 'A soggetto*'),
                      items: ref
                          .watch(subjectsProvider)
                          .valueOrNull
                          ?.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList() ??
                          [],
                      onChanged: (v) =>
                          setState(() => selectedToSubjectId = v),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: selectedSubjectId,
                      decoration:
                          const InputDecoration(labelText: 'Soggetto*'),
                      items: ref
                          .watch(subjectsProvider)
                          .valueOrNull
                          ?.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList() ??
                          [],
                      onChanged: (v) => setState(() => selectedSubjectId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedEntryId,
                      decoration:
                          const InputDecoration(labelText: 'Voce*'),
                      items: filteredEntries
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        selectedEntryId = v;
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Importo*',
                      suffixText: '€',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opzionale)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(amountController.text.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inserisci un importo valido'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (selectedType == TransactionType.transfer) {
                    if (selectedFromSubjectId == null ||
                        selectedToSubjectId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Seleziona entrambi i soggetti'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  } else {
                    if (selectedSubjectId == null || selectedEntryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Seleziona soggetto e voce'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  final transaction = AppTransaction(
                    id: FirebaseFirestore.instance.collection('transactions').doc().id,
                    type: selectedType,
                    amount: amount,
                    date: selectedDate,
                    subjectId: selectedType == TransactionType.transfer
                        ? null
                        : selectedSubjectId,
                    fromSubjectId: selectedType == TransactionType.transfer
                        ? selectedFromSubjectId
                        : null,
                    toSubjectId: selectedType == TransactionType.transfer
                        ? selectedToSubjectId
                        : null,
                    entryId: selectedType == TransactionType.transfer
                        ? null
                        : selectedEntryId,
                    note: noteController.text.isNotEmpty
                        ? noteController.text
                        : null,
                    createdAt: DateTime.now(),
                  );

                  await firebaseService.addTransaction(transaction);
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transazione salvata'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }
}
