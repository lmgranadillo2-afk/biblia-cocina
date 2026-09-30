# Biblia de Cocina — Grupo Junín

Herramienta interna de gestión de cocina, multi-restaurante, multi-usuario, para el Grupo Junín (Colombia).

## Stack y despliegue

- **Frontend**: un solo archivo `index.html` (HTML + CSS + JavaScript vanilla, sin build step). Fuentes: Playfair Display, IBM Plex Mono, Inter (Google Fonts).
- **Backend**: Supabase (Postgres + Auth + RLS + Realtime). Proyecto: `rwsmscggszaogalmwsrj.supabase.co`.
- **Hosting**: Vercel, conectado a este repo de GitHub. Cada push a `main` (o el commit de `index.html`) redespliega solo.
- **Producción**: https://biblia-cocina.vercel.app/

### Cómo desplegar un cambio
1. Editar `index.html` directamente (contiene placeholders `PEGA_AQUI_TU_SUPABASE_URL` y `PEGA_AQUI_TU_SUPABASE_ANON_KEY` en el código fuente original — en este repo ya deben estar con los valores reales).
2. `git add`, `git commit`, `git push` — Vercel se encarga del resto.
3. Los cambios de base de datos van como scripts `.sql` sueltos que se corren a mano en el SQL Editor de Supabase (no hay migraciones versionadas todavía — ver sección de mejoras pendientes).

## Arquitectura de datos

```
Grupo Junín
 └── Punto (locations)              — restaurante físico: Cantina Dos Santos, Canta Corazón, Rúnico, Dos Santos Cali...
      └── Área (areas)              — Cocina, Barra, Servicio... cada una con sus módulos habilitados (jsonb)
           └── módulos: recetario, produccion, cronograma, pedidos, bajas, inventario
```

- **Aislamiento por ÁREA** (no solo por punto) en: `recipes`, `observations`, `productions`, `schedule_items`, `orders`/`order_items`, `inventory_catalog`, `inventory_sessions`/`inventory_items`.
- **Aislamiento por PUNTO únicamente** (compartido entre áreas del mismo punto) en: `bajas`, el catálogo de insumos de Pedidos (`group_ingredients` + `location_ingredient_activation`), `catalog_items`.
- **Compartido a nivel de TODO EL GRUPO**: `group_ingredients` (catálogo maestro de insumos), `proveedores` (catálogo de proveedores), activables por punto o por área según la tabla.
- **Usuarios**: acceso explícito por punto (`user_locations`) y por área (`user_areas`) — el admin no ve todo automáticamente, salvo `is_super_admin` que tiene bypass total vía la función `has_location_access()` / `has_area_access()`.

### Todas las tablas (public schema)
`profiles`, `locations`, `user_locations`, `areas`, `user_areas`, `recipes`, `observations`, `productions`, `schedule_items`, `orders`, `order_items`, `bajas`, `inventory_catalog`, `inventory_sessions`, `inventory_items`, `group_ingredients`, `location_ingredient_activation`, `catalog_items`, `proveedores`, `area_proveedores`, `group_ingredient_proveedores`, `costeo_platos` (por área), `costeo_cargos`, `carta_items`, `costeo_eventos` (por punto).

- **Costeo**: subpestañas Platos / Eventos / Carta / Cargos / Food cost. Mano de obra = valor hora del cargo (salario mínimo `SALARIO_MINIMO_CO` × (1 + 8 % prestacional) + auxilio de transporte, ÷ horas/mes). Eventos: menú por tiempos + carta + personal (costo + margen %) + otros ítems − descuento + servicio 10 % (sobre todo) + anticipo; el ICO 8 % va INCLUIDO en los precios de carta y solo se desglosa (TOTAL, TOTAL SIN ICO, ICO, SERVICIO, TOTAL A PAGAR); costos/ganancia/comisión solo admin. Cotización PDF con plantilla por restaurante en `plantillas/<slug>/` (`PLANTILLAS_COTIZACION`).
- **Puntos centrales** (`esHub()`): **Admin** (slug `admin`: eventos, cartas, cargos de eventos y food cost de todos los restaurantes) y **Eventos** (slug `eventos`: eventos y cartas). Los eventos tienen `restaurante_id`; las políticas usan `is_eventos_user()`. Tablas extra: `toteat_sync_log`, `toteat_cron_config`, `foodcost_grupos`.
- **Toteat**: Edge Function en `supabase/functions/toteat-sync`, desplegada en Supabase con el nombre **`dynamic-endpoint`** (const `TOTEAT_FUNCION`) y **verificación JWT apagada** (valida sesión admin o el token del cron). Se despliega pegando el código en Supabase → Edge Functions → dynamic-endpoint → Code → Deploy. Credenciales como secretos `TOTEAT_<SLUG>_XIR/_XIL/_XIU/_TOKEN` (las carga el usuario; nunca pedirlas en el chat). Acciones: carta (products), costos (sales, solo "nuevo Toteat"), foodcost (sales + inventorystate). Cron `toteat-sync-diario` 4 a. m. COL. Límite de Toteat: 3 consultas/minuto, 15 días por consulta.
- **Bajas**: Pendiente → Ingresada / Denegada (en la base siguen `aprobado` / `rechazado`); los admin resuelven desde el módulo Bajas o Admin → Bajas.
- Si una tabla nueva no aparece en la app: correr `notify pgrst, 'reload schema';` en el SQL Editor.

Todas tienen RLS activo. Los helpers `public.is_admin()`, `public.is_super_admin()`, `public.has_location_access(location_id)`, `public.has_area_access(area_id)` son `security definer` y se usan en casi todas las políticas.

## Reglas de negocio clave (no romper sin preguntar)

- **Recetas**: código único por ÁREA (no por punto). Solo lectura para `cocina`; solo admin edita.
- **Producción**: alerta de "misma receta el mismo día" compara solo dentro de la misma área (`check_same_day_production(p_recipe_code, p_fecha, p_area_id)`). Solo se puede anular (nunca borrar), con motivo obligatorio. Campo `ingresado` (booleano) marca si ya se sumó al inventario físico — separado de anular.
- **Pedidos**: categoría → insumo (buscador dentro de esa categoría) → cantidad → presentación de compra (definida por insumo en `unidades_compra`, texto libre tipo "Bidón x 20 litros"). Si el proveedor elegido tiene insumos vinculados (`group_ingredient_proveedores`), el buscador se filtra SOLO a esos; si no tiene ninguno, se ve el catálogo completo. Código automático `PED-0001...` por área (trigger `set_order_codigo`). Estados: Pendiente → Aprobado/Rechazado (o auto-aprobado si se marca "Urgente"). Una vez Aprobado, el creador ve botones de enviar (WhatsApp abre `wa.me/?text=...` SIN número fijo — deja elegir el chat/grupo destino; Correo sigue necesitando el correo del proveedor). Al enviar, campo `enviado=true` bloquea reenvío. Semáforo visual en pedidos aprobados sin enviar según horas transcurridas (verde <2h, amarillo 2-5h, rojo >5h).
- **Bajas**: mismo patrón que Pedidos (código `BAJ-0001...`), pero a nivel de PUNTO. Tipo: Insumo o Receta preparada, siempre del catálogo existente.
- **Inventario**: catálogo fijo por área (`inventory_catalog`), NO se deriva automáticamente del catálogo de Pedidos — se carga a mano/por script. Un día se cuenta, se guarda, y queda bloqueado; admin puede desbloquear.
- **Consolidado**: Admin → Consolidado junta pedidos aprobados y sin enviar de varias áreas de un mismo punto para un proveedor específico, en un solo mensaje.
- **Tema visual**: fondo crema fijo (`#F8F4EC`) para toda la app; solo el color de acento (`color_accent`/`color_accent_2` en `locations`) cambia por punto. El color de texto sobre botones de acento se calcula dinámicamente (claro u oscuro) según la luminosidad del acento — ver función `pickTextColor()`.

## Estilo de trabajo con el usuario (Miguel / chef@cantinadossantos.com, super admin)

- No hace falta explicarle para qué sirve cada módulo una vez ya está definido — ir directo a la propuesta/cambio, sin justificaciones de más.
- Para cambios grandes o ambiguos, proponer el diseño concreto y pedir confirmación **antes** de tocar código — varias veces en el historial de este proyecto un cambio mal alcanzado tocó rehacerse.
- Cuando un cambio toca la base de datos, generar el script `.sql` como archivo aparte (nunca pedirle que ejecute SQL a mano dictado en el chat) y ser explícito sobre el ORDEN si hay más de un script.
- El usuario no tiene backups automáticos (Supabase plan gratuito) — para cualquier operación destructiva (`DELETE`, `DROP`, reinicios), confirmar el alcance exacto por escrito antes de generar el script, y recordar que no hay forma de deshacerlo.

## Mejoras pendientes / deuda técnica conocida

- Sin migraciones versionadas — los cambios de esquema son scripts `.sql` sueltos corridos a mano. Si se pasa a un flujo más formal (Supabase CLI + migraciones), documentar el cambio.
- `index.html` es un solo archivo de +300 KB. Si crece mucho más, considerar separar en módulos (aunque sea manteniendo el build simple).
- Reportes/analítica (comparar Pedidos vs Inventario para estimar consumo semanal) — en pausa hasta tener varias semanas de datos reales de uso.
- Servicio (Canta Corazón) sin catálogo de inventario cargado. Rúnico sin recetas ni inventario cargados aún; logo provisional sacado de una captura de Instagram.
