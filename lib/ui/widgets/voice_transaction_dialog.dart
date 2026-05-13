import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/services/voice_transaction_service.dart';

class VoiceTransactionDialog extends ConsumerStatefulWidget {
  final List<Subject> subjects;
  final List<Entry> entries;
  final List<Group> groups;
  final String? defaultSubjectId;

  const VoiceTransactionDialog({
    required this.subjects,
    required this.entries,
    required this.groups,
    this.defaultSubjectId,
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
      defaultSubjectId: widget.defaultSubjectId,
    );

    if (!mounted) return;

    if (result.isError) {
      setState(() {
        _status = _VoiceStatus.error;
        _errorMessage = result.error;
      });
    } else {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Nuovo movimento', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(
              'es. ( Danza 30€ acconto per saggio a l\'operà di Parigi )',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
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

      case _VoiceStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Errore sconosciuto', style: const TextStyle(color: Colors.red)),
            if (_transcribedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Testo: "$_transcribedText"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ],
        );
    }
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
        ];

      case _VoiceStatus.processing:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ];
    }
  }
}

enum _VoiceStatus { idle, listening, processing, error }
