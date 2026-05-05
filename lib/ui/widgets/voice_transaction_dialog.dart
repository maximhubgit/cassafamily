import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';

class VoiceTransactionDialog extends ConsumerStatefulWidget {
  final List<Subject> subjects;
  final List<Entry> entries;
  final List<Group> groups;
  final String? preselectedSubjectId;

  const VoiceTransactionDialog({
    required this.subjects,
    required this.entries,
    required this.groups,
    this.preselectedSubjectId,
    super.key,
  });

  @override
  ConsumerState<VoiceTransactionDialog> createState() => _VoiceTransactionDialogState();
}

class _VoiceTransactionDialogState extends ConsumerState<VoiceTransactionDialog> {
  final _service = VoiceTransactionService(
    openRouterApiKey: const String.fromEnvironment('OPENROUTER_API_KEY'),
  );

  var _status = _VoiceStatus.idle;
  var _transcribedText = '';
  VoiceTransactionResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _service.initialize();
    if (!ok && mounted) {
      setState(() => _errorMessage = 'Riconoscimento vocale non disponibile su questo dispositivo');
    }
  }

  Future<void> _toggleListening() async {
    if (_service.isListening) {
      await _service.stopListening();
      return;
    }

    setState(() {
      _status = _VoiceStatus.listening;
      _transcribedText = '';
      _errorMessage = null;
      _result = null;
    });

    await _service.startListening(
      onResult: (text) {
        if (mounted) setState(() => _transcribedText = text);
      },
      onComplete: _processText,
    );
  }

  Future<void> _processText() async {
    if (_transcribedText.isEmpty) {
      setState(() => _status = _VoiceStatus.idle);
      return;
    }

    setState(() => _status = _VoiceStatus.processing);

    final result = await _service.processVoiceTransaction(
      transcribedText: _transcribedText,
      subjects: widget.subjects,
      entries: widget.entries,
      groups: widget.groups,
    );

    if (!mounted) return;

    setState(() {
      _result = result;
      _status = result.isError ? _VoiceStatus.error : _VoiceStatus.confirm;
    });
  }

  void _confirm() {
    if (_result != null && !_result!.isError) {
      Navigator.pop(context, _result);
    }
  }

  void _retry() {
    setState(() {
      _status = _VoiceStatus.idle;
      _transcribedText = '';
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Nuovo movimento vocale'),
          const Spacer(),
          if (_status == _VoiceStatus.listening)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Text(_errorMessage!, style: const TextStyle(color: Colors.red));
    }

    switch (_status) {
      case _VoiceStatus.idle:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Tocca il microfono e di il comando,\n es: "uscita Massimo pranzo 15 euro"'),
          ],
        );

      case _VoiceStatus.listening:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Ti sto ascoltando...', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_transcribedText.isNotEmpty)
              Text(_transcribedText, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        );

      case _VoiceStatus.processing:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Elaborazione con AI...'),
          ],
        );

      case _VoiceStatus.confirm:
        return _buildConfirmation();

      case _VoiceStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_result?.error ?? 'Errore sconosciuto', style: const TextStyle(color: Colors.red)),
            if (_transcribedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Testo: "$_transcribedText"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ],
        );
    }
  }

  Widget _buildConfirmation() {
    final r = _result!;
    final typeStr = _typeToString(r.type);

    String subjectName = 'N/D';
    if (r.type == TransactionType.transfer) {
      final from = widget.subjects.where((s) => s.id == r.fromSubjectId).firstOrNull;
      final to = widget.subjects.where((s) => s.id == r.toSubjectId).firstOrNull;
      subjectName = '${from?.name ?? "?"} → ${to?.name ?? "?"}';
    } else {
      final s = widget.subjects.where((s) => s.id == r.subjectId).firstOrNull;
      subjectName = s?.name ?? 'N/D';
    }

    String entryName = '';
    if (r.entryId != null) {
      final e = widget.entries.where((e) => e.id == r.entryId).firstOrNull;
      entryName = e?.name ?? '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Testo: "$_transcribedText"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        const Text('Conferma i dati:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _infoRow('Tipo:', typeStr),
        _infoRow('Importo:', '€ ${r.amount.toStringAsFixed(2)}'),
        _infoRow('Soggetto:', subjectName),
        if (r.date != null) _infoRow('Data:', '${r.date!.day}/${r.date!.month}/${r.date!.year}'),
        if (entryName.isNotEmpty) _infoRow('Voce:', entryName),
        if (r.note != null) _infoRow('Nota:', r.note!),
        _infoRow('Confidenza:', '${(r.confidence * 100).toStringAsFixed(0)}%'),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    switch (_status) {
      case _VoiceStatus.idle:
      case _VoiceStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.red),
            onPressed: _toggleListening,
            tooltip: 'Inizia registrazione',
          ),
        ];

      case _VoiceStatus.listening:
        return [
          TextButton(
            onPressed: () {
              _service.cancelListening();
              setState(() => _status = _VoiceStatus.idle);
            },
            child: const Text('Annulla'),
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.red),
            onPressed: () => _service.stopListening(),
            tooltip: 'Ferma registrazione',
          ),
        ];

      case _VoiceStatus.processing:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ];

      case _VoiceStatus.confirm:
        return [
          TextButton(
            onPressed: _retry,
            child: const Text('Riprova'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: _confirm,
            child: const Text('Conferma'),
          ),
        ];
    }
  }

  String _typeToString(TransactionType type) {
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
}

enum _VoiceStatus { idle, listening, processing, confirm, error }
