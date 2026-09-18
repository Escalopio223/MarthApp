import 'package:flutter/foundation.dart';

/// Modelo inmutable que representa un recordatorio programado de una tarea
/// (tabla `planificador_tarea_recordatorios`).
@immutable
class RecordatorioTareaModel {
  final String id;
  final String tareaId;
  final DateTime fechaNotificacion;
  final String? horaNotificacion; // Formato "HH:mm" (ej: "09:30") o null si es ciclo 8h
  final bool enviado;
  final DateTime? ultimoEnvioAt;
  final DateTime? createdAt;

  const RecordatorioTareaModel({
    required this.id,
    required this.tareaId,
    required this.fechaNotificacion,
    this.horaNotificacion,
    this.enviado = false,
    this.ultimoEnvioAt,
    this.createdAt,
  });

  /// Indica si el recordatorio tiene una hora específica programada
  bool get tieneHoraFija =>
      horaNotificacion != null && horaNotificacion!.trim().isNotEmpty;

  /// Retorna un texto formateado amigable para el usuario
  String get textoDescriptivo {
    final diaStr =
        '${fechaNotificacion.day.toString().padLeft(2, '0')}/${fechaNotificacion.month.toString().padLeft(2, '0')}/${fechaNotificacion.year}';
    if (tieneHoraFija) {
      return '$diaStr a las $horaNotificacion';
    }
    return '$diaStr - Todo el día (cada 8h)';
  }

  /// Calcula el texto de antelación respecto a una fecha límite dada
  String calcularAntelacionTexto(DateTime? fechaLimite) {
    if (fechaLimite == null) return textoDescriptivo;

    final dFecha = DateTime(
      fechaNotificacion.year,
      fechaNotificacion.month,
      fechaNotificacion.day,
    );
    final dLimite = DateTime(
      fechaLimite.year,
      fechaLimite.month,
      fechaLimite.day,
    );

    final diffDias = dLimite.difference(dFecha).inDays;
    String antelacion;
    if (diffDias == 0) {
      antelacion = 'El mismo día';
    } else if (diffDias == 1) {
      antelacion = 'El día antes';
    } else if (diffDias == 3) {
      antelacion = '3 días antes';
    } else if (diffDias == 7) {
      antelacion = '1 semana antes';
    } else if (diffDias == 14) {
      antelacion = '2 semanas antes';
    } else if (diffDias > 0) {
      antelacion = '$diffDias días antes';
    } else {
      antelacion = textoDescriptivo;
    }

    if (tieneHoraFija) {
      return '$antelacion ($horaNotificacion)';
    }
    return '$antelacion (cada 8h)';
  }

  RecordatorioTareaModel copyWith({
    String? id,
    String? tareaId,
    DateTime? fechaNotificacion,
    String? horaNotificacion,
    bool clearHoraNotificacion = false,
    bool? enviado,
    DateTime? ultimoEnvioAt,
    bool clearUltimoEnvioAt = false,
    DateTime? createdAt,
  }) {
    return RecordatorioTareaModel(
      id: id ?? this.id,
      tareaId: tareaId ?? this.tareaId,
      fechaNotificacion: fechaNotificacion ?? this.fechaNotificacion,
      horaNotificacion: clearHoraNotificacion
          ? null
          : (horaNotificacion ?? this.horaNotificacion),
      enviado: enviado ?? this.enviado,
      ultimoEnvioAt: clearUltimoEnvioAt
          ? null
          : (ultimoEnvioAt ?? this.ultimoEnvioAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory RecordatorioTareaModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedFecha = DateTime.now();
    if (json['fecha_notificacion'] != null) {
      parsedFecha = DateTime.tryParse(json['fecha_notificacion'].toString()) ??
          DateTime.now();
    }

    String? parsedHora = json['hora_notificacion']?.toString();
    if (parsedHora != null && parsedHora.length > 5) {
      // Normalizar "HH:mm:ss" a "HH:mm"
      parsedHora = parsedHora.substring(0, 5);
    }

    return RecordatorioTareaModel(
      id: json['id'] as String? ?? '',
      tareaId: json['tarea_id'] as String? ?? '',
      fechaNotificacion: parsedFecha,
      horaNotificacion: parsedHora,
      enviado: json['enviado'] as bool? ?? false,
      ultimoEnvioAt: json['ultimo_envio_at'] != null
          ? DateTime.tryParse(json['ultimo_envio_at'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'tarea_id': tareaId,
      'fecha_notificacion':
          '${fechaNotificacion.year}-${fechaNotificacion.month.toString().padLeft(2, '0')}-${fechaNotificacion.day.toString().padLeft(2, '0')}',
      'hora_notificacion': horaNotificacion,
      'enviado': enviado,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    if (ultimoEnvioAt != null) {
      map['ultimo_envio_at'] = ultimoEnvioAt!.toIso8601String();
    }
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordatorioTareaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tareaId == other.tareaId &&
          fechaNotificacion == other.fechaNotificacion &&
          horaNotificacion == other.horaNotificacion &&
          enviado == other.enviado &&
          ultimoEnvioAt == other.ultimoEnvioAt;

  @override
  int get hashCode =>
      id.hashCode ^
      tareaId.hashCode ^
      fechaNotificacion.hashCode ^
      horaNotificacion.hashCode ^
      enviado.hashCode ^
      ultimoEnvioAt.hashCode;
}
