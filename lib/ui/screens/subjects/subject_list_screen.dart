import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/utils/icon_helper.dart';
import 'package:cassa1/data/models/subject.dart';

class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.subjects),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: AppStrings.add,
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (subjects) => subjects.isEmpty
            ? Center(child: Text('Nessun soggetto. Aggiungine uno!', style: Theme.of(context).textTheme.bodyLarge))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final s = subjects[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(IconHelper.getIconData(s.icon)),
                      title: Text(s.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(context, ref, s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, s.id),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, Subject? subject) {
    final nameController = TextEditingController(text: subject?.name ?? '');
    String selectedIcon = subject?.icon ?? 'person';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(subject == null ? AppStrings.add : AppStrings.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: AppStrings.name),
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
                final repo = ref.read(subjectRepositoryProvider);
                if (subject == null) {
                  final newSubject = Subject(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    icon: selectedIcon,
                    createdAt: DateTime.now(),
                  );
                  repo.add(newSubject);
                } else {
                  final updated = subject.copyWith(name: nameController.text, icon: selectedIcon);
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
              ref.read(subjectRepositoryProvider).delete(id);
              Navigator.pop(context);
            },
            child: const Text(AppStrings.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
