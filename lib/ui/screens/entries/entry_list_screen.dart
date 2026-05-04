import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/utils/icon_helper.dart';
import 'package:cassa1/data/models/entry.dart';
import 'package:cassa1/data/models/group.dart';

class EntryListScreen extends ConsumerWidget {
  const EntryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.entries),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: AppStrings.add,
            onPressed: () {
              final groups = ref.read(groupsProvider).asData?.value ?? [];
              if (groups.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crea prima un gruppo')),
                );
                return;
              }
              _showEditDialog(context, ref, null, groups);
            },
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (entries) {
          return groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Errore: $error')),
            data: (groups) {
              if (entries.isEmpty) {
                return Center(child: Text('Nessuna voce. Aggiungine una!', style: Theme.of(context).textTheme.bodyLarge));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  final matching = groups.where((g) => g.id == e.groupId);
                  final group = matching.isEmpty ? null : matching.first;
                  return Card(
                    child: ListTile(
                      leading: Icon(IconHelper.getIconData(e.icon)),
                      title: Text(e.name),
                      subtitle: Text('Gruppo: ${group?.name ?? "N/A"} (${group?.type == GroupType.income ? "Entrata" : "Uscita"})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(context, ref, e, groups),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, e.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Entry? entry, List<Group> groups) {
    final nameController = TextEditingController(text: entry?.name ?? '');
    String selectedGroupId = entry?.groupId ?? (groups.isNotEmpty ? groups.first.id : '');
    String selectedIcon = entry?.icon ?? 'receipt';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(entry == null ? AppStrings.add : AppStrings.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: AppStrings.name),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: selectedGroupId,
                  isExpanded: true,
                  items: groups.map((g) {
                    return DropdownMenuItem(
                      value: g.id,
                      child: Text('${g.name} (${g.type == GroupType.income ? "Entrata" : "Uscita"})'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedGroupId = value!),
                ),
                const SizedBox(height: 16),
                const Text('Icona'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: IconHelper.availableIcons.map((iconName) {
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = iconName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedIcon == iconName ? AppColors.primary : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(IconHelper.getIconData(iconName)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () {
                final repo = ref.read(entryRepositoryProvider);
                if (entry == null) {
                  final newEntry = Entry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    groupId: selectedGroupId,
                    name: nameController.text,
                    icon: selectedIcon,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newEntry);
                } else {
                  final updated = entry.copyWith(
                    name: nameController.text,
                    groupId: selectedGroupId,
                    icon: selectedIcon,
                  );
                  repo.update(updated);
                }
                Navigator.pop(context);
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(transactionRepositoryProvider);
              final linked = await repo.isEntryLinked(id);
              if (!context.mounted) return;
              if (linked) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Impossibile eliminare: questa voce è collegata a dei movimenti')),
                );
                return;
              }
              ref.read(entryRepositoryProvider).delete(id);
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
