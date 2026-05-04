import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';

class ExportService {
  static String _transactionTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Entrata';
      case TransactionType.expense:
        return 'Uscita';
      case TransactionType.transfer:
        return 'Trasferimento';
      case TransactionType.anticipi:
        return 'Anticipo';
    }
  }

  static Subject? _findSubject(List<Subject> subjects, String? id) {
    if (id == null) return null;
    final matches = subjects.where((s) => s.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  static Entry? _findEntry(List<Entry> entries, String? id) {
    if (id == null) return null;
    final matches = entries.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  static Group? _findGroup(List<Group> groups, String? id) {
    if (id == null) return null;
    final matches = groups.where((g) => g.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  static Future<String> generateCsv({
    required List<AppTransaction> transactions,
    required List<Subject> subjects,
    required List<Entry> entries,
    required List<Group> groups,
  }) async {
    final dateFormat = DateFormat('dd/MM/yyyy');

    final rows = <List<dynamic>>[
      [
        'Data',
        'Tipo',
        'Soggetto',
        'Da soggetto',
        'A soggetto',
        'Voce',
        'Gruppo',
        'Importo',
        'Nota',
      ],
    ];

    for (final t in transactions) {
      final subject = _findSubject(subjects, t.subjectId);
      final fromSubject = _findSubject(subjects, t.fromSubjectId);
      final toSubject = _findSubject(subjects, t.toSubjectId);
      final entry = _findEntry(entries, t.entryId);
      final group = entry != null ? _findGroup(groups, entry.groupId) : null;

      rows.add([
        dateFormat.format(t.date),
        _transactionTypeLabel(t.type),
        subject?.name ?? '',
        fromSubject?.name ?? '',
        toSubject?.name ?? '',
        entry?.name ?? '',
        group?.name ?? '',
        t.amount.toStringAsFixed(2),
        t.note ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static Future<void> exportAndShare({
    required BuildContext context,
    required List<AppTransaction> transactions,
    required List<Subject> subjects,
    required List<Entry> entries,
    required List<Group> groups,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final csv = await generateCsv(
        transactions: transactions,
        subjects: subjects,
        entries: entries,
        groups: groups,
      );

      final dir = await getTemporaryDirectory();
      final fileName = 'cassa_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Export Cassa1',
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Errore durante l\'esportazione: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
