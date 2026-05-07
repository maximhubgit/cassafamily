import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/services/firebase_service.dart';

class ImportService {
  static Future<void> pickAndImport({
    required ScaffoldMessengerState messenger,
    required List<Subject> subjects,
    required List<Entry> entries,
    required List<Group> groups,
    required FirebaseService firebaseService,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Impossibile leggere il file (bytes non disponibili)');
      }
      var bytes = file.bytes!;

      // Rimuovi BOM UTF-8 se presente
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }

      // Decode: prova UTF-8, se fallisce usa Latin-1 (copre Windows-1252)
      String csvContent;
      try {
        csvContent = utf8.decode(bytes, allowMalformed: false);
      } on FormatException {
        csvContent = latin1.decode(bytes);
      }

      // CsvToListConverter: non forzare eol, lascia che rilevi automaticamente
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvContent);

      if (rows.length < 2) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Il file CSV è vuoto'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final dataRows = rows.skip(1);

      final colIdx = _mapColumns(header);
      if (colIdx['tipo'] == null || colIdx['amount'] == null || colIdx['data'] == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Intestazioni colonne non valide. Servono: Data, Tipo, Soggetto, Importo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int imported = 0;
      int skipped = 0;
      final skipReasons = <String>[];

      for (final row in dataRows) {
        if (row.isEmpty || row.first.toString().trim().isEmpty) {
          skipped++;
          skipReasons.add('Riga vuota');
          continue;
        }

        try {
          final tipoRaw = _cell(row, colIdx['tipo']!);
          final tipo = _parseType(tipoRaw);
          if (tipo == null) {
            skipped++;
            skipReasons.add('Tipo non valido: "$tipoRaw"');
            continue;
          }

          final dateRaw = _cell(row, colIdx['data']!);
          final date = _parseDate(dateRaw);
          if (date == null) {
            skipped++;
            skipReasons.add('Data non valida: "$dateRaw"');
            continue;
          }

          final amountRaw = _cell(row, colIdx['amount']!);
          final amount = double.tryParse(amountRaw.replaceAll(',', '.'));
          if (amount == null || amount <= 0) {
            skipped++;
            skipReasons.add('Importo non valido: "$amountRaw"');
            continue;
          }

          String? subjectId;
          String? fromSubjectId;
          String? toSubjectId;
          String? entryId;

          if (tipo == TransactionType.transfer) {
            fromSubjectId = await _findOrCreateSubject(
              subjects,
              _cell(row, colIdx['fromSubject']!),
              firebaseService,
            );
            toSubjectId = await _findOrCreateSubject(
              subjects,
              _cell(row, colIdx['toSubject']!),
              firebaseService,
            );
            if (fromSubjectId == null || toSubjectId == null) { skipped++; continue; }
          } else {
            final subjectName = _cell(row, colIdx['subject']!);
            subjectId = await _findOrCreateSubject(
              subjects,
              subjectName,
              firebaseService,
            );
            if (subjectId == null) {
              skipped++;
              skipReasons.add('Soggetto non valido: "$subjectName"');
              continue;
            }

            final groupName = _cell(row, colIdx['group']!);
            if (groupName.isEmpty) { skipped++; continue; }

            Group? group = _findGroup(groups, groupName);
            if (group == null) {
              final groupType = (tipo == TransactionType.income)
                  ? GroupType.income
                  : GroupType.expense;
              group = Group(
                id: FirebaseFirestore.instance.collection('groups').doc().id,
                name: groupName,
                type: groupType,
                icon: 'folder',
                createdAt: DateTime.now(),
              );
              await firebaseService.addGroup(group);
              groups.add(group);
            }

            final entryName = _cell(row, colIdx['entry']!);
            if (entryName.isEmpty) { skipped++; continue; }

            Entry? entry = _findEntry(entries, entryName, group.id);
            if (entry == null) {
              entry = Entry(
                id: FirebaseFirestore.instance.collection('entries').doc().id,
                groupId: group.id,
                name: entryName,
                icon: 'receipt',
                createdAt: DateTime.now(),
              );
              await firebaseService.addEntry(entry);
              entries.add(entry);
            }
            entryId = entry.id;
          }

          final transaction = AppTransaction(
            id: FirebaseFirestore.instance.collection('transactions').doc().id,
            type: tipo,
            amount: amount,
            date: date,
            subjectId: subjectId,
            fromSubjectId: fromSubjectId,
            toSubjectId: toSubjectId,
            entryId: entryId,
            note: (colIdx.containsKey('note') && colIdx['note']! < row.length)
                ? _cell(row, colIdx['note']!)
                : null,
            createdAt: DateTime.now(),
          );

          await firebaseService.addTransaction(transaction);
          imported++;
        } catch (e) {
          skipped++;
        }
      }

      // Mostra i primi 3 motivi di scarto nel SnackBar
      var skipSummary = '';
      if (skipReasons.isNotEmpty) {
        final shown = skipReasons.toSet().take(3).join('; ');
        skipSummary = '\nMotivi: $shown';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Importate $imported transazioni'
              '${skipped > 0 ? ', saltate $skipped' : ''}'
              '$skipSummary'),
          backgroundColor: imported > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Errore durante l\'importazione: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  static Map<String, int> _mapColumns(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final h = header[i];
      if (h == 'data') {
        map['data'] = i;
      } else if (h == 'tipo' || h == 'tipologia') {
        map['tipo'] = i;
      } else if (h == 'soggetto' || h == 'soggetti') {
        map['subject'] = i;
      } else if (h == 'da soggetto' || h == 'da' || h == 'from') {
        map['fromSubject'] = i;
      } else if (h == 'a soggetto' || h == 'a' || h == 'to') {
        map['toSubject'] = i;
      } else if (h == 'voce' || h == 'voci' || h == 'entry') {
        map['entry'] = i;
      } else if (h == 'gruppo' || h == 'gruppi' || h == 'group') {
        map['group'] = i;
      } else if (h == 'importo' || h == 'import' || h == 'amount' || h == 'euro') {
        map['amount'] = i;
      } else if (h == 'nota' || h == 'note' || h == 'note') {
        map['note'] = i;
      }
    }
    return map;
  }

  static String _cell(List<dynamic> row, int idx) {
    return idx < row.length ? row[idx].toString() : '';
  }

  static TransactionType? _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'entrata':
      case 'income':
        return TransactionType.income;
      case 'uscita':
      case 'expense':
        return TransactionType.expense;
      case 'trasferimento':
      case 'transfer':
        return TransactionType.transfer;
      case 'anticipo':
      case 'anticipi':
        return TransactionType.anticipi;
      default:
        return null;
    }
  }

  static DateTime? _parseDate(String dateStr) {
    final trimmed = dateStr.trim();

    // 6 cifre: aammgg (es. 260507 per 2026-05-07)
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      try {
        final year = 2000 + int.parse(trimmed.substring(0, 2));
        final month = int.parse(trimmed.substring(2, 4));
        final day = int.parse(trimmed.substring(4, 6));
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // 8 cifre: aaaammgg (es. 20260507)
    if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
      try {
        final year = int.parse(trimmed.substring(0, 4));
        final month = int.parse(trimmed.substring(4, 6));
        final day = int.parse(trimmed.substring(6, 8));
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // Prova con DateFormat per altri formati
    for (final fmt in ['dd/MM/yyyy', 'yyyy-MM-dd']) {
      try {
        return DateFormat(fmt).parse(trimmed);
      } catch (_) {}
    }

    return null;
  }

  static Group? _findGroup(List<Group> groups, String name) {
    final match = groups.where(
      (g) => g.name.toLowerCase() == name.toLowerCase(),
    );
    return match.isEmpty ? null : match.first;
  }

  static Entry? _findEntry(List<Entry> entries, String name, String groupId) {
    final match = entries.where(
      (e) => e.name.toLowerCase() == name.toLowerCase() && e.groupId == groupId,
    );
    return match.isEmpty ? null : match.first;
  }

  static Future<String?> _findOrCreateSubject(
    List<Subject> subjects,
    String name,
    FirebaseService firebaseService,
  ) async {
    if (name.isEmpty) return null;
    var match = subjects.where((s) => s.name.toLowerCase() == name.toLowerCase());
    if (match.isNotEmpty) return match.first.id;

    final subject = Subject(
      id: FirebaseFirestore.instance.collection('subjects').doc().id,
      name: name,
      icon: 'person',
      createdAt: DateTime.now(),
    );
    await firebaseService.addSubject(subject);
    subjects.add(subject);
    return subject.id;
  }
}
