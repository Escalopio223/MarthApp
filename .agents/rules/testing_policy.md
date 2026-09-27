# Política de Testing y Flujo de Desarrollo

1. **Sin testing en desarrollo continuo**:
   - NO escribir nuevas pruebas ni modificar archivos en `test/` durante tareas de desarrollo, nuevas pantallas o correcciones de interfaz/lógica, a menos que el usuario lo solicite explícitamente.
   - NO ejecutar suites de pruebas automatizadas (`flutter test`) de forma automática tras cada tarea.

2. **Testing reservado para lanzamientos**:
   - El proceso de testing se reserva exclusivamente para cuando el usuario indique explícitamente que se va a publicar o congelar una versión de producción / release.

3. **Eficiencia y enfoque**:
   - Centrarse directamente en el código de producción (`lib/`, `supabase/`, etc.).
   - Hacer cambios precisos y concisos de una sola pasada para maximizar la velocidad y optimizar el consumo de tokens y tiempo.
