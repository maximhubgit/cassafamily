import 'package:flutter/material.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/utils/icon_helper.dart';

/// Shows a modal bottom sheet with a group→entry picker.
/// Returns the selected entry ID, or null if cancelled.
Future<String?> showEntryPicker({
  required BuildContext context,
  required List<Group> groups,
  required List<Entry> entries,
  required TransactionType selectedType,
  String? selectedEntryId,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: _EntryPickerSheet(
        groups: groups,
        entries: entries,
        selectedType: selectedType,
        selectedEntryId: selectedEntryId,
      ),
    ),
  );
}

class _EntryPickerSheet extends StatefulWidget {
  final List<Group> groups;
  final List<Entry> entries;
  final TransactionType selectedType;
  final String? selectedEntryId;

  const _EntryPickerSheet({
    required this.groups,
    required this.entries,
    required this.selectedType,
    this.selectedEntryId,
    super.key,
  });

  @override
  State<_EntryPickerSheet> createState() => _EntryPickerSheetState();
}

class _EntryPickerSheetState extends State<_EntryPickerSheet> {
  String? _expandedGroupId;
  Entry? _selectedEntry;

  @override
  void initState() {
    super.initState();
    if (widget.selectedEntryId != null) {
      _selectedEntry = widget.entries
          .where((e) => e.id == widget.selectedEntryId)
          .firstOrNull;
      if (_selectedEntry != null) {
        _expandedGroupId = _selectedEntry!.groupId;
      }
    }
  }

  List<Entry> get _filteredEntries {
    return widget.entries.where((e) {
      if (widget.selectedType == TransactionType.income) {
        return widget.groups
            .where((g) => g.id == e.groupId && g.type == GroupType.income)
            .isNotEmpty;
      }
      return widget.groups
          .where((g) => g.id == e.groupId && g.type == GroupType.expense)
          .isNotEmpty;
    }).toList();
  }

  Map<String, List<Entry>> get _groupedEntries {
    final map = <String, List<Entry>>{};
    final filtered = _filteredEntries;
    for (final e in filtered) {
      map.putIfAbsent(e.groupId, () => <Entry>[]).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedEntries;
    final sortedGroupIds = grouped.keys.toList()
      ..sort((a, b) {
        final ga = widget.groups.where((g) => g.id == a).firstOrNull;
        final gb = widget.groups.where((g) => g.id == b).firstOrNull;
        return (ga?.name ?? '').compareTo(gb?.name ?? '');
      });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seleziona una voce',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _selectedEntry != null
                ? 'Selezionato: ${_selectedEntry!.name}'
                : 'Tocca un gruppo, poi una voce',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sortedGroupIds.isEmpty
              ? const Center(child: Text('Nessuna voce disponibile'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedGroupIds.length,
                  itemBuilder: (context, index) {
                    final groupId = sortedGroupIds[index];
                    final group = widget.groups
                        .where((g) => g.id == groupId)
                        .firstOrNull;
                    final entries = grouped[groupId]!;
                    final isExpanded = _expandedGroupId == groupId;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _expandedGroupId =
                                isExpanded ? null : groupId;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  IconHelper.getIconData(group?.icon ?? 'f0f2'),
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    group?.name ?? 'Gruppo eliminato',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '${entries.length}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          ...entries.map((e) => InkWell(
                                onTap: () {
                                  Navigator.pop(context, e.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 10),
                                  color: _selectedEntry?.id == e.id
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1)
                                      : null,
                                  child: Row(
                                    children: [
                                      Icon(
                                        IconHelper.getIconData(e.icon ?? 'f0f2'),
                                        size: 18,
                                        color: _selectedEntry?.id == e.id
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          e.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                _selectedEntry?.id == e.id
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                            color:
                                                _selectedEntry?.id == e.id
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : null,
                                          ),
                                        ),
                                      ),
                                      if (_selectedEntry?.id == e.id)
                                        Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                    ],
                                  ),
                                ),
                              )),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
