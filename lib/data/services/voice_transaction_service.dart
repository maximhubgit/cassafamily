import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/transaction.dart';

class VoiceTransactionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final String openRouterApiKey;

  VoiceTransactionService({required this.openRouterApiKey});

  Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: _handleStatusChange,
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
      return false;
    }
  }

    bool get isListening => _speech.isListening;

  Timer? _statusCheckTimer;
  Timer? _maxTimer;
  bool _completed = false;
  bool _isActive = false;
  Function()? _onComplete;
  Function(String)? _onResultCallback;

  Future<void> startListening({
    required Function(String) onResult,
    required Function() onComplete,
  }) async {
    _completed = false;
    _isActive = true;
    _onComplete = onComplete;
    _onResultCallback = onResult;
    _statusCheckTimer?.cancel();
    _maxTimer?.cancel();

    await _speech.listen(
      onResult: (result) {
        if (_completed || !_isActive) return;
        _onResultCallback?.call(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );

    // Check every 500ms: on web/Edge the plugin may stop without calling onStatus
    _statusCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_completed) {
        _statusCheckTimer?.cancel();
        return;
      }
      if (!_speech.isListening && _isActive) {
        debugPrint('Voice: isListening became false, completing');
        _statusCheckTimer?.cancel();
        _completed = true;
        _isActive = false;
        _maxTimer?.cancel();
        _onComplete?.call();
      }
    });

    // Safety net: auto-stop after 60 seconds
    _maxTimer = Timer(const Duration(seconds: 60), () {
      if (!_completed && _isActive) {
        debugPrint('Voice: 60s timeout, stopping');
        _completed = true;
        _isActive = false;
        _statusCheckTimer?.cancel();
        _speech.stop();
        _onComplete?.call();
      }
    });
  }

  Future<void> stopListening() async {
    if (!_isActive) return;
    _completed = true;
    _isActive = false;
    _statusCheckTimer?.cancel();
    _maxTimer?.cancel();
    await _speech.stop();
    _onComplete?.call();
  }

  Future<void> cancelListening() async {
    _completed = true;
    _isActive = false;
    _statusCheckTimer?.cancel();
    _maxTimer?.cancel();
    await _speech.cancel();
  }

  void _handleStatusChange(String status) {
    debugPrint('Speech status: $status');
    if ((status == 'notListening' || status == 'done') && _isActive && !_completed) {
      debugPrint('Voice: status-based completion');
      _completed = true;
      _isActive = false;
      _statusCheckTimer?.cancel();
      _maxTimer?.cancel();
      _onComplete?.call();
    }
  }

  Future<VoiceTransactionResult> processVoiceTransaction({
    required String transcribedText,
    required List<Subject> subjects,
    required List<Entry> entries,
    required List<Group> groups,
    String? defaultSubjectId,
  }) async {
    if (transcribedText.isEmpty) {
      return VoiceTransactionResult.error('Nessun testo trascritto');
    }

    try {
      final response = await _callOpenRouter(
        transcribedText: transcribedText,
        subjects: subjects,
        entries: entries,
        groups: groups,
        defaultSubjectId: defaultSubjectId,
      );
      return response;
    } catch (e) {
      return VoiceTransactionResult.error('Errore elaborazione: $e');
    }
  }

  Future<VoiceTransactionResult> _callOpenRouter({
    required String transcribedText,
    required List<Subject> subjects,
    required List<Entry> entries,
    required List<Group> groups,
    String? defaultSubjectId,
  }) async {
    final subjectsJson = subjects.map((s) => '{"id": "${s.id}", "name": "${s.name}"}').join(',\n    ');
    final entriesJson = entries.map((e) {
      final group = groups.where((g) => g.id == e.groupId).firstOrNull;
      return '{"id": "${e.id}", "name": "${e.name}", "group": "${group?.name ?? ""}", "groupType": "${group?.type.name ?? ""}"}';
    }).join(',\n    ');

    final prompt = '''
Sei un assistente che analizza comandi vocali per una app di gestione budget familiare (Cassa Famiglia).

Tipi di transazione disponibili: "income" (entrata), "expense" (uscita), "transfer" (trasferimento), "anticipi" (anticipo).

Soggetti disponibili:
[
  $subjectsJson
]

Voci disponibili (raggruppate per gruppo):
[
  $entriesJson
]

Testo trascritto dall'utente: "$transcribedText"

Analizza il testo e restituisci ESCLUSIVAMENTE un oggetto JSON valido con questi campi:
- "type": uno di "income", "expense", "transfer", "anticipi"
- "amount": importo numerico (estrai dal testo, converti parole come "quindici" in 15.0)
- "date": data in formato YYYY-MM-DD (opzionale)
- "entryName": nome della voce (per income/expense/anticipi, opzionale)
- "note": nota libera (opzionale, includi dettagli come luogo, motivo)
- "confidence": numero da 0.0 a 1.0 indicante la confidenza del parsing

REGOLE:
1. NON includere mai "subjectName", "fromSubjectName", "toSubjectName" - il soggetto verrà assegnato automaticamente
2. "entrata" o "incasso" → type: "income"
3. "uscita", "spesa", "pagato" → type: "expense"
4. "trasferisco", "giro", "passo" → type: "transfer"
5. "anticipo", "anticipato" → type: "anticipi"
6. L'importo può essere detto come numero ("15") o parola ("quindici", "venti")
7. Se il testo menziona un gruppo (es. "spese casa") cerca voci in quel gruppo
8. Per la data: "oggi" = data odierna, "ieri" = ieri, "15 aprile" = data specifica

Esempio output: {"type": "expense", "amount": 30.0, "date": "2026-05-12", "entryName": "Danza", "note": "acconto per saggio all'operà di Parigi", "confidence": 0.9}
''';

    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $openRouterApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openai/gpt-oss-120b:free',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode != 200) {
      return VoiceTransactionResult.error(
        'Errore API (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['choices'][0]['message']['content'] as String;

    // Extract JSON from response (handle cases where model wraps in markdown)
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    if (jsonMatch == null) {
      return VoiceTransactionResult.error('Risposta non valida dall\'AI: $content');
    }

    final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

    // Map names to IDs
    final typeStr = parsed['type'] as String? ?? 'expense';
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );

    final amount = (parsed['amount'] as num?)?.toDouble() ?? 0.0;

    String? subjectId;
    String? fromSubjectId;
    String? toSubjectId;
    String? entryId;
    final note = parsed['note'] as String? ?? '';
    final confidence = (parsed['confidence'] as num?)?.toDouble() ?? 0.5;

    // Parse date
    DateTime? date;
    final dateStr = parsed['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    // Usa il soggetto predefinito per income/expense/anticipi
    // Per i transfer, non vengono più parsati i soggetti dal testo vocale
    if (type != TransactionType.transfer && defaultSubjectId != null) {
      subjectId = defaultSubjectId;
    }

    // Match from/to subjects for transfer (rimosso parsing vocale)
    // I transfer vocale dovrebbero essere gestiti manualmente

    // Match entry
    final entryName = parsed['entryName'] as String?;
    if (entryName != null && entryName.isNotEmpty) {
      final match = _fuzzyFindEntry(entryName, entries);
      entryId = match?.id;
    }

    return VoiceTransactionResult(
      type: type,
      amount: amount,
      date: date,
      subjectId: subjectId,
      fromSubjectId: fromSubjectId,
      toSubjectId: toSubjectId,
      entryId: entryId,
      note: note.isNotEmpty ? note : null,
      confidence: confidence,
      rawText: transcribedText,
    );
  }

  Subject? _fuzzyFindSubject(String name, List<Subject> subjects) {
    final lowerName = name.toLowerCase();
    // Exact match first
    var match = subjects.where((s) => s.name.toLowerCase() == lowerName);
    if (match.isNotEmpty) return match.first;
    // Contains match
    match = subjects.where((s) => s.name.toLowerCase().contains(lowerName) || lowerName.contains(s.name.toLowerCase()));
    if (match.isNotEmpty) return match.first;
    // First word match
    match = subjects.where((s) => s.name.toLowerCase().startsWith(lowerName) || lowerName.startsWith(s.name.toLowerCase()));
    if (match.isNotEmpty) return match.first;
    return null;
  }

  Entry? _fuzzyFindEntry(String name, List<Entry> entries) {
    final lowerName = name.toLowerCase();
    // Exact match first
    var match = entries.where((e) => e.name.toLowerCase() == lowerName);
    if (match.isNotEmpty) return match.first;
    // Contains match
    match = entries.where((e) => e.name.toLowerCase().contains(lowerName) || lowerName.contains(e.name.toLowerCase()));
    if (match.isNotEmpty) return match.first;
    return null;
  }
}

class VoiceTransactionResult {
  final TransactionType type;
  final double amount;
  final DateTime? date;
  final String? subjectId;
  final String? fromSubjectId;
  final String? toSubjectId;
  final String? entryId;
  final String? note;
  final double confidence;
  final String rawText;
  final String? error;

  VoiceTransactionResult({
    required this.type,
    required this.amount,
    this.date,
    this.subjectId,
    this.fromSubjectId,
    this.toSubjectId,
    this.entryId,
    this.note,
    required this.confidence,
    required this.rawText,
    this.error,
  });

  VoiceTransactionResult.error(String error)
      : this(
          type: TransactionType.expense,
          amount: 0,
          confidence: 0,
          rawText: '',
          error: error,
        );

  bool get isError => error != null;
}
