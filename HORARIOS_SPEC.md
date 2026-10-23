# Módulo Horarios — especificación (para implementar)

Diseño acordado en chat con Miguel el 23 oct 2026. Seguir CLAUDE.md y DESIGN.md. Confirmar con Miguel los "Pendientes de decidir" antes de escribir código.

## Alcance
Nuevo módulo `horarios` por ÁREA (mismo patrón que Pedidos/Bajas: `area_id`, RLS con `has_area_access()`), activable en `areas.modulos`. Arrancar con Cocina de Cantina Dos Santos Medellín, pero dejarlo genérico para cualquier punto/área.

## Partes
1. **Personal** (`horario_personal`): nombre, estación, cargo, descanso fijo (día 1-7), es_produccion (bool), activo, user_id opcional.
   - Estaciones y mínimos por estación/día editables en Admin (`horario_estaciones`: nombre, color, minimo_por_dia int[7]).
2. **Turnos** (`horario_turnos`, por área): código (ej. "4-12"), horas efectivas, cubre_manana, cubre_cierre.
3. **Semana** (`horario_semanas` + `horario_asignaciones`): grilla L-D por persona, estado borrador/publicada, publicada_por/at. Envío por WhatsApp (`wa.me/?text=` sin número, igual que pedidos).
4. **Novedades** (`horario_novedades`): persona, tipo (incapacidad / vacaciones / permiso / vacante / retardo), desde, hasta, nota. Sobrescriben la asignación en la vista.
5. **Registro del día** (`horario_registro_dia`): por persona y fecha, horas reales, asistió (bool), nota. Lo cierra el líder.
6. **Demanda**: ventas netas por día (y n.º de clientes si Toteat lo trae) desde `toteat-sync` → tabla `horario_demanda_dia` (punto, fecha, ventas, clientes). Agregar acción al cron diario existente.
7. **Asistente IA**: Edge Function nueva `horarios-ia` (JWT de sesión, valida acceso al área). Botón "Proponer semana": manda a Claude (API Anthropic, secreto `ANTHROPIC_API_KEY` en Supabase — lo carga Miguel, nunca pedirlo en chat) las reglas, personal, turnos, últimas ~8 semanas de demanda, novedades, horas reales y coberturas pasadas; devuelve JSON con la grilla propuesta + explicación + riesgos. Se carga como borrador; el usuario aprueba/edita antes de publicar.

## Reglas de validación (marcar en rojo en la grilla)
- 1 descanso fijo por semana, siempre el día establecido de cada persona. El domingo trabajado NO cuenta como descanso.
- Viernes, sábado y domingo no descansa nadie, excepto producción (Dolca, Nubia — descansan domingo).
- Máximo 1 persona de la misma estación descansando el mismo día.
- Cobertura por estación ≥ mínimo del día.
- Horas semanales ≤ jornada máxima (42 h desde 15 jul 2026, Ley 2101; parámetro editable).
- Lunes y martes el servicio abre a las 4 p. m. → ahí se concentran los descansos; también se usa el jueves.
- Domingo: por estación un turno de salida temprano 11-5 y uno que recibe y cierra 5-1; rotar semanalmente quién sale temprano.

## Datos iniciales — Cocina Medellín
Turnos: 6-1 (7 h, mañana), 4-12 (8 h, cierre), 11,30-4-7-11 (8,5 h, mañana+cierre), 1-4-7-12 (8 h, mañana+cierre), 3-11 (8 h, cierre), 5-1 (8 h, cierre), 11-5 (6 h, mañana). Horas efectivas a confirmar con Miguel (pausas no remuneradas).

| Persona | Estación | Descanso fijo |
|---|---|---|
| Dolca | Producción | Domingo |
| Nubia | Producción | Domingo |
| Jany | Líder | Lunes |
| Cocinero (nuevo) | Líder | Martes |
| Edinnson | Parrilla | Martes |
| Mauricio | Parrilla | Lunes |
| Verónica | Fría | Lunes |
| José Rod | Fría | Jueves |
| Auxiliar (nuevo) | Fría | Miércoles |
| Omar | Tacos | Lunes |
| Jesús | Tacos | Martes |
| Martha | Steward | Martes |
| Victoria | Steward | Jueves |

Mínimos sugeridos por día (L-D): Producción 2,2,2,2,2,2,0 · Líder 1 · Parrilla 1 · Fría 1,1,1,1,2,2,2 · Tacos 1 · Steward 1.
Fila "Bunker" (préstamo de personal a otro punto) en el horario original — preguntar si se mantiene.

## Entregables
- `sql/horarios_1_tablas.sql` (tablas + RLS + RPC), `sql/horarios_2_datos_cocina_medellin.sql` (carga inicial). Indicar el orden.
- `supabase/functions/horarios-ia/index.ts`.
- Pestaña Horarios en `index.html` siguiendo DESIGN.md.
- Actualizar CLAUDE.md con el módulo.

## Decisiones (Miguel, 23 oct 2026)
1. Editan admin + usuarios marcados como "Líder de horarios" por área (Admin → Usuarios). El resto solo ve semanas publicadas.
2. Sí a la API de Anthropic, en la fase 3.
3. Solo Cocina de Cantina Dos Santos Medellín por ahora (genérico para activar otras áreas).
4. Horas de los turnos tal cual (son efectivas). "Bunker" = aseo del vestier/lugar donde se cambian: es una tarea diaria asignada a una persona, no un préstamo de personal.

5. Jornada máxima (42 h): se avisa siempre (amarillo, con las horas de más por persona y en el resumen), pero NUNCA bloquea publicar. Con los turnos actuales 10 de 13 personas quedan en 46–49 h.
6. El horario publicado se envía también como IMAGEN (PNG generado en canvas: grilla por estación, descansos, novedades, Bunker; sin horas). En celular usa el menú de compartir (`navigator.share` con archivo) para elegir WhatsApp; en computador descarga el PNG. El texto por `wa.me` queda como segunda opción.

## Orden de fases
1. Tablas + configuración + grilla manual con validaciones + publicar/WhatsApp + tarea Bunker.
2. Novedades + registro del día.
3. Proponer semana SIN IA (reglas en la app, sin costo). Miguel decidió el 23 oct no pagar la API de Anthropic por ahora; el asistente con IA queda opcional para después.
4. Demanda desde Toteat (bloqueada hasta resolver ventas en 0 de Dos Santos).
