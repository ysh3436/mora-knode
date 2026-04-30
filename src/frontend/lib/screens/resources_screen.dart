import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/resource.dart';
import '../state/providers.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(resourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(resourcesProvider),
          ),
        ],
      ),
      body: resources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = items[i];
            return ListTile(
              title: Text(r.name),
              subtitle: Text([
                if (r.role != null) r.role!,
                '${r.capacityPercent}%',
              ].join(' · ')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete ${r.name}?'),
                      content: const Text('Existing assignments will still reference this id.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true && r.id != null) {
                    await ref.read(apiClientProvider).deleteResource(r.id!);
                    ref.invalidate(resourcesProvider);
                  }
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add resource'),
        onPressed: () => _openCreate(context, ref),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final nameC = TextEditingController();
    final roleC = TextEditingController();
    final capC = TextEditingController(text: '100');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New resource'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name *'), autofocus: true),
              TextField(controller: roleC, decoration: const InputDecoration(labelText: 'Role')),
              TextField(
                controller: capC,
                decoration: const InputDecoration(labelText: 'Capacity percent', suffixText: '%'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameC.text.trim().isEmpty) return;
              await ref.read(apiClientProvider).createResource(Resource(
                    name: nameC.text.trim(),
                    role: roleC.text.trim().isEmpty ? null : roleC.text.trim(),
                    capacityPercent: int.tryParse(capC.text) ?? 100,
                  ));
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (saved == true) ref.invalidate(resourcesProvider);
  }
}
