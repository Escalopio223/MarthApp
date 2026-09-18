// ==============================================================================
// Servicio de Reparto Equitativo de Tareas (TypeScript / Deno)
// Heurística Greedy para el Partition Problem (LPT: Longest Processing Time First)
// ==============================================================================

export interface TareaPendiente {
  id: string;
  tiempo_estimado_minutos: number;
  asignado_a?: string | null;
  titulo?: string;
  [key: string]: unknown;
}

export interface ItemAsignado {
  tarea_id: string;
  usuario_asignado_inicial: string;
  usuario_asignado_final: string;
  tiempo_minutos: number;
  titulo?: string;
}

export interface ResultadoRepartoEquitativo {
  sesion_id: string;
  entorno_id: string;
  fecha_sesion: string;
  usuarios_participantes: string[];
  minutos_totales: number;
  cargas_por_usuario: Record<string, number>;
  items: ItemAsignado[];
}

/**
 * Heurística Greedy determinista para el Partition Problem:
 * 1. Ordena las tareas de mayor a menor tiempo_estimado_minutos.
 *    Desempate determinista por ID de la tarea (lexicográfico).
 * 2. Mantiene la carga acumulada en minutos para cada usuario participante (inicia en 0).
 * 3. Asigna cada tarea al usuario que tenga menor carga acumulada en ese instante.
 *    Desempate determinista por el orden de aparición en `usuariosParticipantes`.
 */
export function calcularRepartoEquitativo(
  entornoId: string,
  usuariosParticipantes: string[],
  tareas: TareaPendiente[]
): ResultadoRepartoEquitativo {
  if (!usuariosParticipantes || usuariosParticipantes.length === 0) {
    throw new Error('Debe indicarse al menos un usuario participante para el reparto.');
  }
  if (!tareas || tareas.length === 0) {
    throw new Error('No hay tareas pendientes para repartir.');
  }

  // 1. Ordenación determinista: mayor duración primero; si empatan, ordenar por id ASC
  const tareasOrdenadas = [...tareas].sort((a, b) => {
    if (b.tiempo_estimado_minutos !== a.tiempo_estimado_minutos) {
      return b.tiempo_estimado_minutos - a.tiempo_estimado_minutos;
    }
    return a.id.localeCompare(b.id);
  });

  // 2. Inicializar acumuladores de tiempo en minutos por usuario
  const cargas: Record<string, number> = {};
  for (const userId of usuariosParticipantes) {
    cargas[userId] = 0;
  }

  const items: ItemAsignado[] = [];
  let minutosTotales = 0;

  // 3. Asignación voraz (Greedy)
  for (const tarea of tareasOrdenadas) {
    const minutos = tarea.tiempo_estimado_minutos;
    minutosTotales += minutos;

    // Encontrar el usuario con menor carga acumulada
    // El orden del array rompe empates de manera determinista
    let mejorUsuario = usuariosParticipantes[0];
    let menorCarga = cargas[mejorUsuario];

    for (let i = 1; i < usuariosParticipantes.length; i++) {
      const uId = usuariosParticipantes[i];
      if (cargas[uId] < menorCarga) {
        menorCarga = cargas[uId];
        mejorUsuario = uId;
      }
    }

    // Actualizar la carga acumulada del usuario elegido
    cargas[mejorUsuario] += minutos;

    // Usuario inicial asignado (o el elegido si no tenía ninguno)
    const usuarioInicial = tarea.asignado_a || mejorUsuario;

    items.push({
      tarea_id: tarea.id,
      usuario_asignado_inicial: usuarioInicial,
      usuario_asignado_final: mejorUsuario,
      tiempo_minutos: minutos,
      titulo: tarea.titulo,
    });
  }

  return {
    sesion_id: crypto.randomUUID(),
    entorno_id: entornoId,
    fecha_sesion: new Date().toISOString().split('T')[0],
    usuarios_participantes: [...usuariosParticipantes],
    minutos_totales: minutosTotales,
    cargas_por_usuario: cargas,
    items,
  };
}
