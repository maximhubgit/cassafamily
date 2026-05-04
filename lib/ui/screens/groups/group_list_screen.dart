import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/utils/icon_helper.dart';
import 'package:cassa1/data/models/group.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.groups),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: AppStrings.add,
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (groups) => groups.isEmpty
            ? Center(child: Text('Nessun gruppo. Aggiungine uno!', style: Theme.of(context).textTheme.bodyLarge))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final g = groups[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(IconHelper.getIconData(g.icon)),
                      title: Text(g.name),
                      subtitle: Text(g.type == GroupType.income ? 'Entrata' : 'Uscita'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(context, ref, g),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, g.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Group? group) {
    final nameController = TextEditingController(text: group?.name ?? '');
    GroupType selectedType = group?.type ?? GroupType.expense;
    String selectedIcon = group?.icon ?? 'folder';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(group == null ? AppStrings.add : AppStrings.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: AppStrings.name),
                ),
                const SizedBox(height: 16),
                DropdownButton<GroupType>(
                  value: selectedType,
                  isExpanded: true,
                  items: GroupType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type == GroupType.income ? 'Entrata' : 'Uscita'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedType = value!),
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
                final repo = ref.read(groupRepositoryProvider);
                if (group == null) {
                  final newGroup = Group(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    type: selectedType,
                    icon: selectedIcon,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newGroup);
                } else {
                  final updated = group.copyWith(
                    name: nameController.text,
                    type: selectedType,
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
            onPressed: () {
              ref.read(groupRepositoryProvider).delete(id);
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
