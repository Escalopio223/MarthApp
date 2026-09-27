import '../models/checklist_item_model.dart';

/// Funciones puras e inmutables para la manipulación y ordenamiento de subtareas.

/// Reordena de forma inmutable una lista de [ChecklistItemModel], garantizando
/// que los índices [orden] queden correlativos (0, 1, 2, ...) tras cualquier alteración.
List<ChecklistItemModel> reorderSubtasks(
  List<ChecklistItemModel> list,
  int oldIndex,
  int newIndex,
) {
  final copy = List<ChecklistItemModel>.from(list);
  if (oldIndex < 0 || oldIndex >= copy.length) return copy;

  if (oldIndex < newIndex) {
    newIndex -= 1;
  }
  if (newIndex < 0) newIndex = 0;
  if (newIndex >= copy.length) newIndex = copy.length - 1;

  final item = copy.removeAt(oldIndex);
  copy.insert(newIndex, item);

  // Normalizar índices correlativos de orden (0..N-1)
  return [
    for (int i = 0; i < copy.length; i++)
      copy[i].copyWith(orden: i),
  ];
}

/// Añade una nueva subtarea al final de la colección con orden determinista.
List<ChecklistItemModel> addSubtask(
  List<ChecklistItemModel> list,
  String titulo,
) {
  final clean = titulo.trim();
  if (clean.isEmpty) return list;

  final newItem = ChecklistItemModel(
    id: 'subtask_${DateTime.now().millisecondsSinceEpoch}_${list.length}',
    titulo: clean,
    completado: false,
    orden: list.length,
  );
  return [...list, newItem];
}

/// Elimina una subtarea por índice y re-indexa los elementos restantes.
List<ChecklistItemModel> removeSubtaskAt(
  List<ChecklistItemModel> list,
  int index,
) {
  if (index < 0 || index >= list.length) return list;
  final copy = List<ChecklistItemModel>.from(list)..removeAt(index);
  return [
    for (int i = 0; i < copy.length; i++)
      copy[i].copyWith(orden: i),
  ];
}

/// Alterna el estado de completado de una subtarea de forma inmutable.
List<ChecklistItemModel> toggleSubtaskCompletion(
  List<ChecklistItemModel> list,
  int index,
) {
  if (index < 0 || index >= list.length) return list;
  final item = list[index];
  final updated = List<ChecklistItemModel>.from(list);
  updated[index] = item.copyWith(completado: !item.completado);
  return updated;
}

/// Modifica el título de una subtarea existente.
List<ChecklistItemModel> editSubtaskTitle(
  List<ChecklistItemModel> list,
  int index,
  String newTitle,
) {
  final clean = newTitle.trim();
  if (clean.isEmpty || index < 0 || index >= list.length) return list;
  final updated = List<ChecklistItemModel>.from(list);
  updated[index] = updated[index].copyWith(titulo: clean);
  return updated;
}
