import 'package:flutter/foundation.dart';
import 'evento_model.dart';
import 'tarea_model.dart';

enum AgendaItemType {
  eventoGeneral,
  cumpleanos,
  tarea,
}

/// Modelo polimórfico unificado para la Agenda / Calendario.
/// Permite renderizar homogéneamente tanto eventos como tareas con fecha límite.
@immutable
class AgendaItemModel implements Comparable<AgendaItemModel> {
  final String id;
  final AgendaItemType tipo;
  final String titulo;
  final String? descripcion;
  final DateTime fecha;
  final DateTime? fechaFin;
  final bool esTodoElDia;
  final EventoModel? eventoOriginal;
  final TareaModel? tareaOriginal;

  const AgendaItemModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.descripcion,
    required this.fecha,
    this.fechaFin,
    this.esTodoElDia = false,
    this.eventoOriginal,
    this.tareaOriginal,
  });

  bool get esTarea => tipo == AgendaItemType.tarea;
  bool get esCumpleanos => tipo == AgendaItemType.cumpleanos;
  bool get esEventoGeneral => tipo == AgendaItemType.eventoGeneral;

  bool get estaCompletada => tareaOriginal?.estaCompletada ?? false;
  int? get tiempoEstimadoMinutos => tareaOriginal?.tiempoEstimadoMinutos;
  String? get ideasRegalo => eventoOriginal?.ideasRegalo;
  String? get personaCumpleanos => eventoOriginal?.personaCumpleanos;

  factory AgendaItemModel.fromEvento(EventoModel evento) {
    return AgendaItemModel(
      id: evento.id,
      tipo: evento.esCumpleanos
          ? AgendaItemType.cumpleanos
          : AgendaItemType.eventoGeneral,
      titulo: evento.titulo,
      descripcion: evento.descripcion,
      fecha: evento.fechaInicio,
      fechaFin: evento.fechaFin,
      esTodoElDia: evento.esTodoElDia,
      eventoOriginal: evento,
    );
  }

  factory AgendaItemModel.fromTarea(TareaModel tarea) {
    return AgendaItemModel(
      id: tarea.id,
      tipo: AgendaItemType.tarea,
      titulo: tarea.titulo,
      descripcion: tarea.descripcion,
      fecha: tarea.fechaLimite ?? DateTime.now(),
      esTodoElDia: true,
      tareaOriginal: tarea,
    );
  }

  @override
  int compareTo(AgendaItemModel other) {
    return fecha.compareTo(other.fecha);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AgendaItemModel &&
        other.id == id &&
        other.tipo == tipo &&
        other.fecha == fecha;
  }

  @override
  int get hashCode => Object.hash(id, tipo, fecha);

  @override
  String toString() =>
      'AgendaItemModel(id: $id, tipo: $tipo, titulo: $titulo, fecha: $fecha)';
}
