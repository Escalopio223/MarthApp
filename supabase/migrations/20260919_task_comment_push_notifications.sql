-- ==============================================================================
-- MIGRACIÓN SUPABASE: NOTIFICACIONES PUSH PARA COMENTARIOS EN TAREAS
-- Fecha: 2026-09-19
-- ==============================================================================
-- Despacha automáticamente una notificación push a todos los demás miembros
-- del entorno cuando se añade un nuevo comentario en una tarea.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.trg_notif_task_comment_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_latest_comment JSONB;
  v_author_id TEXT;
  v_author_name TEXT;
  v_comment_text TEXT;
  v_task_title TEXT;
  v_recipients JSONB;
  v_old_count INT := 0;
  v_new_count INT := 0;
BEGIN
  IF NEW.comentarios IS NOT NULL THEN
    v_new_count := jsonb_array_length(NEW.comentarios);
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.comentarios IS NOT NULL THEN
    v_old_count := jsonb_array_length(OLD.comentarios);
  END IF;

  -- Solo se activa si hay más comentarios que antes
  IF v_new_count > v_old_count THEN
    v_latest_comment := NEW.comentarios -> (v_new_count - 1);
    v_author_id := v_latest_comment ->> 'autor_id';
    v_author_name := COALESCE(NULLIF(v_latest_comment ->> 'autor_nombre', ''), 'Un miembro');
    v_comment_text := COALESCE(v_latest_comment ->> 'texto', '');
    v_task_title := COALESCE(NULLIF(NEW.titulo, ''), 'una tarea');

    -- Obtener los IDs de los demás miembros del entorno (excluyendo al autor del comentario)
    SELECT COALESCE(jsonb_agg(user_id), '[]'::jsonb)
    INTO v_recipients
    FROM (
      SELECT em.user_id::text AS user_id
      FROM public.environment_members em
      WHERE em.environment_id = NEW.entorno_id
        AND (v_author_id IS NULL OR em.user_id::text != v_author_id)
      UNION
      SELECT eu.user_id::text AS user_id
      FROM public.entorno_usuarios eu
      WHERE eu.entorno_id = NEW.entorno_id
        AND (v_author_id IS NULL OR eu.user_id::text != v_author_id)
    ) sub;

    -- Si existen miembros a los que notificar, despachar la notificación push
    IF v_recipients IS NOT NULL AND jsonb_array_length(v_recipients) > 0 THEN
      -- Truncar comentario para la vista previa de la notificación si supera 120 caracteres
      IF length(v_comment_text) > 120 THEN
        v_comment_text := substring(v_comment_text from 1 for 117) || '...';
      END IF;

      PERFORM public.dispatch_push_notification(
        'immediate',
        jsonb_build_object(
          'user_ids', v_recipients,
          'title', '💬 ' || v_author_name || ' en "' || v_task_title || '"',
          'body', v_comment_text,
          'data', jsonb_build_object(
            'type', 'task_comment',
            'tarea_id', NEW.id::text,
            'entorno_id', NEW.entorno_id::text,
            'autor_id', COALESCE(v_author_id, '')
          )
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_task_comment ON public.planificador_tareas;
CREATE TRIGGER trg_notif_task_comment
  AFTER INSERT OR UPDATE OF comentarios ON public.planificador_tareas
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notif_task_comment_func();

COMMENT ON FUNCTION public.trg_notif_task_comment_func IS 'Despacha notificaciones push al resto de miembros del entorno cuando se añade un comentario en una tarea.';
