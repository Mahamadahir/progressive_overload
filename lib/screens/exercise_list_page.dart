import 'package:flutter/material.dart';

import 'package:fitness_app/database/database_provider.dart';
import 'package:fitness_app/repositories/drift_repository.dart';
import 'package:fitness_app/screens/create_exercise_page.dart';

enum _ExerciseAction { edit, delete }

class ExerciseListPage extends StatelessWidget {
  const ExerciseListPage({super.key});

  Future<void> _openCreate(BuildContext context, {String? exerciseId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateExercisePage(exerciseId: exerciseId),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExerciseDetail detail,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: Text(
          'This will remove "${detail.exercise.name}". '
          'Existing workouts that reference it will keep their historical data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await driftRepository.deleteExercise(detail.exercise.id);
      messenger.showSnackBar(const SnackBar(content: Text('Exercise deleted')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete exercise: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: StreamBuilder<List<ExerciseDetail>>(
        stream: driftRepository.watchExercises(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final exercises = snapshot.data ?? const [];
          if (exercises.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fitness_center, size: 48),
                  const SizedBox(height: 12),
                  Text('No exercises yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Create exercises to reuse across workouts.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create exercise'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final detail = exercises[index];
              final chips = detail.groups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: Chip(
                        label: Text(group.name),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )
                  .toList();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(detail.exercise.name),
                  subtitle: chips.isEmpty
                      ? const Text('No muscle groups assigned')
                      : Wrap(children: chips),
                  onTap: () =>
                      _openCreate(context, exerciseId: detail.exercise.id),
                  trailing: PopupMenuButton<_ExerciseAction>(
                    tooltip: 'Options',
                    onSelected: (action) {
                      switch (action) {
                        case _ExerciseAction.edit:
                          _openCreate(context, exerciseId: detail.exercise.id);
                          break;
                        case _ExerciseAction.delete:
                          _confirmDelete(context, detail);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<_ExerciseAction>(
                        value: _ExerciseAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem<_ExerciseAction>(
                        value: _ExerciseAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
