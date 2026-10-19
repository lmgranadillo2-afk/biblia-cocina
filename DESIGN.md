# DESIGN.md — Biblia de Cocina (propuesta de rediseño v2)

> Estado: **APLICADO** — fases 1 a 4 aprobadas por Miguel módulo por módulo (oct 2026).
> Este documento manda sobre cualquier decisión visual. Si un cambio de UI contradice algo de aquí, se pregunta antes.

## 1. Dirección

**"Libreta de cocina profesional"**: se mantiene lo que ya le da identidad a la app (papel crema, Playfair para títulos, IBM Plex Mono para códigos y cantidades, el sello de rendimiento) y se le agrega orden: tokens consistentes, colores de estado fijos, botones más grandes para usar en cocina y una navegación que aguante 9 módulos.

Principios:

1. **Se usa de pie, con prisa y a veces con las manos mojadas.** Todo lo que se toca mide mínimo 44 px de alto; las acciones principales de Producción, Pedidos, Bajas e Inventario, 48 px.
2. **El acento es del punto; el estado es del sistema.** El color de cada restaurante (`color_accent`) identifica la marca. Verde/amarillo/rojo de estados (aprobado, pendiente, rechazado, semáforo) son **fijos y nunca cambian por punto**.
3. **Números en mono, siempre.** Cantidades, códigos, precios y fechas en IBM Plex Mono con cifras tabulares, alineados a la derecha en tablas.
4. **Cero colores sueltos.** Todo color sale de un token de la sección 2. Nada de `#fff`, `rgba(226,87,43,…)` ni hex escritos a mano dentro de componentes.

## 2. Tokens

### 2.1 Neutros (iguales en todos los puntos)

```css
--bg:            #F7F2E8;  /* papel */
--surface:       #FFFDF8;  /* tarjetas */
--surface-2:     #F0E9DB;  /* inputs, filas alternas, chips */
--surface-3:     #E4D9C3;  /* pressed, scrollbar */
--border:        #DDD0B6;
--border-strong: #C4B392;  /* foco suave, separadores de sección */
--text:          #1F1810;
--text-muted:    #62564A;
--text-dim:      #8A7D68;  /* solo metadatos, nunca texto que haya que leer para operar */
```

### 2.2 Acento del punto (vienen de `locations`, calculados en `applyLocationTheme()`)

```css
--accent:        <color_accent>;
--accent-strong: color-mix(in srgb, var(--accent) 80%, #000);   /* pressed / hover */
--accent-soft:   color-mix(in srgb, var(--accent) 12%, var(--surface)); /* fondos seleccionados, sello */
--accent-text:   pickTextColor(color_accent);
--accent-2:      <color_accent_2 ajustado>;  /* SOLO decorativo: rendimientos, detalles de marca */
```

Uso del acento: botón primario, pestaña activa, foco de inputs, elemento seleccionado, sello de rendimiento. **No** se usa para indicar estados.

### 2.3 Estados (fijos)

| Token | Texto/borde | Fondo (`-bg`) | Uso |
|---|---|---|---|
| `--ok` | `#2F7A45` | `#E2EFE3` | Aprobado, ingresado, completo, semáforo verde (<2 h) |
| `--warn` | `#A4660A` | `#F7EAD0` | Pendiente, variación, semáforo amarillo (2–5 h) |
| `--danger` | `#B0382A` | `#F6DDD8` | Rechazado/denegado, anulado, semáforo rojo (>5 h), borrar |
| `--info` | `#2D628C` | `#DDE7F0` | Urgente, enviado, avisos neutros |

Texto sobre botón sólido de estado: `#FFFDF8` (`--on-state`).

Íconos de estado sobre fondo oscuro (toasts), versión clara de cada estado: `--ok-on-dark: #7FC08F`, `--warn-on-dark: #E9B45C`, `--danger-on-dark: #EE8F82`.

### 2.4 Tipografía

| Rol | Fuente | Tamaño / peso | Ejemplo |
|---|---|---|---|
| Display | Playfair Display | 30 px / 700 (móvil 26) | Título de receta |
| Título de sección | Playfair Display | 22 px / 700 | "Producción de hoy" |
| Subtítulo | Inter | 16 px / 700 | Nombre en tarjeta |
| Cuerpo | Inter | 15 px / 400 | Texto general |
| Pequeño | Inter | 13 px / 500 | Ayudas, metadatos largos |
| Etiqueta | IBM Plex Mono | 11 px / 600, MAYÚSCULAS, tracking 1.2 px | `INGREDIENTES`, labels de campos |
| Dato | IBM Plex Mono | 14 px / 600, `font-variant-numeric: tabular-nums` | `2,500 kg`, `PED-0042`, `$17.000` |

Labels de formulario pasan de Inter a la etiqueta mono, para que todo el "sistema de fichas" se lea igual.

### 2.5 Espaciado, radios y sombras

```css
--space-1: 4px;  --space-2: 8px;  --space-3: 12px; --space-4: 16px;
--space-5: 20px; --space-6: 24px; --space-8: 32px; --space-12: 48px;

--radius-sm: 6px;    /* chips, badges */
--radius-md: 10px;   /* botones, inputs, tarjetas */
--radius-lg: 16px;   /* modales, hojas inferiores, paneles */
--radius-pill: 999px;

--shadow-1: 0 1px 2px rgba(31,24,16,.06);                 /* tarjetas */
--shadow-2: 0 8px 24px rgba(31,24,16,.12);                /* modales, menús, sugerencias */
--focus-ring: 0 0 0 3px color-mix(in srgb, var(--accent) 35%, transparent);
              /* en código: hex del acento + alfa 59 (≈35 %), para tablets sin color-mix */
--overlay: rgba(31,24,16,.45);                            /* fondo detrás de modales y hojas */
```

## 3. Layout y navegación

Hoy hay 9 pestañas repartidas con `flex:1` en una sola fila: en celular no caben. Se cambia a:

**Celular (< 800 px)**

- Header compacto y fijo (56 px): logo del punto · selector **Punto / Área** (un solo botón que abre hoja inferior) · menú de usuario (nombre, rol, Salir).
- **Barra inferior fija** (64 px + safe-area) con 4 módulos + **Más**. Los 4 visibles se eligen según rol: cocina → Recetario, Producción, Pedidos, Inventario; admin → Recetario, Pedidos, Costeo, Admin. El resto va en "Más" (hoja inferior con lista).
- Ícono (trazo 1.75 px, 22 px) + texto 11 px. Activo: color `--accent` + barra superior de 3 px.

**Escritorio (≥ 1024 px)**

- **Barra lateral izquierda** de 232 px: logo, selector Punto/Área, módulos en lista vertical con ícono, usuario abajo.
- Contenido con `max-width: 1200px`, padding 32 px.
- Recetario y Costeo mantienen el patrón lista (340 px) + detalle.

**Entre 800 y 1023 px:** barra lateral colapsada a íconos (72 px).

Los botones conservan sus `id` actuales (`tab-recetario`, `tab-produccion`, …) para no romper la lógica JS; solo cambia dónde se pintan.

## 4. Componentes

### Botones

| Variante | Estilo |
|---|---|
| `.btn-accent` (primario) | Fondo `--accent`, texto `--accent-text`, pressed `--accent-strong` |
| `.btn-secondary` (nuevo) | Fondo `--surface`, borde `--border-strong`, texto `--text` |
| `.btn-ghost` | Sin borde, fondo transparente, texto `--text-muted`; pressed `--surface-2` |
| `.btn-danger` | Fondo `--danger`, texto `#FFFDF8` |
| `.btn-ok` (nuevo) | Fondo `--ok`, texto `#FFFDF8` (aprobar, ingresar) |

Alto: 44 px (normal), 36 px (`.btn-small`, solo en tablas/escritorio), 52 px (`.btn-lg`, acción principal de un formulario de cocina). Radio `--radius-md`. Una sola acción primaria por pantalla.

### Inputs y selects

44 px de alto, fondo `--surface`, borde `--border`, radio `--radius-md`. Foco: borde `--accent` + `--focus-ring`. Flecha del select con color `--text-muted` (hoy está en gris azulado `#9BA3A8`, que viene de un tema viejo). Inputs numéricos con fuente mono y alineados a la derecha.

### Tarjetas

- **Base** (`.card`): `--surface`, borde `--border`, radio `--radius-md`, `--shadow-1`, padding 16 px.
- **Con estado** (pedidos, bajas, producción, kanban): franja izquierda de 4 px con el color de estado (`--ok` / `--warn` / `--danger` / `--info`), **no** con el acento.
- **Seleccionada:** borde `--accent` + fondo `--accent-soft`.

### Badges de estado

Pastilla (`--radius-pill`), 22 px de alto, mono 10.5 px mayúsculas, punto de color de 6 px + texto. Fondo `--{estado}-bg`, texto `--{estado}`. Un solo componente (`.badge.ok|warn|danger|info|neutral`) reemplaza `.oe-status-badge`, `.di-status`, `.cal-badge` y `.role-badge`.

### Semáforo de pedidos aprobados sin enviar

Badge con el tiempo transcurrido (`3 h 20 m`) usando `ok`/`warn`/`danger`, más la franja izquierda de la tarjeta en el mismo color. Rojo con un pulso suave (opacidad 1 → .6, 2 s) solo si pasan las 5 h.

### Kanban de pedidos

Columnas con fondo `--surface-2`, radio `--radius-lg`, padding 12 px; encabezado con badge de conteo. En celular, en lugar de apilar las 3 columnas, **pestañas segmentadas** arriba (Pendientes · Aprobados · Rechazados) con conteo.

### Tablas (eventos, costeo, inventario)

Encabezado mono 10.5 px mayúsculas, fijo al hacer scroll. Filas de 44 px, separador `--border` continuo (no punteado). Números a la derecha en mono. Fila de total: fondo `--surface-2`, peso 700. En celular la tabla hace scroll horizontal dentro de su contenedor, nunca la página.

### Modales

Escritorio: centrado, `max-width: 480px`, radio `--radius-lg`, `--shadow-2`, overlay `rgba(31,24,16,.45)` (hoy es negro al 60 %, muy pesado). Celular: **hoja inferior** que sube desde abajo, con asa de 4×36 px y botones apilados al final (primario abajo, a mano del pulgar).

### Toasts

Abajo al centro, por encima de la barra inferior. Fondo `--text`, texto `--surface`, ícono de color según tipo (`ok`/`warn`/`danger`). Duración 3 s; errores se quedan hasta cerrarlos.

### Estados vacíos

Ícono de línea de 32 px en `--text-dim` + una frase + (si aplica) botón secundario con la acción. Borde punteado solo aquí.

### Sello de rendimiento (se mantiene)

Es la firma visual de la app. Igual que hoy (borde de 3 px, rotado −2°), pero con `--accent` y fondo `--accent-soft` en lugar de los `rgba(226,87,43,…)` fijos.

### Íconos

Un solo set de línea (Lucide, SVG inline), 20 px en botones y 22 px en navegación, `stroke-width` 1.75, `currentColor`. Sin emojis en la interfaz salvo los del mensaje de WhatsApp.

## 5. Movimiento

Transiciones de 150 ms `ease-out` para color, borde y fondo; 220 ms para hojas inferiores y modales. Respetar `prefers-reduced-motion` (sin pulso ni deslizamientos).

## 6. Accesibilidad mínima

- Contraste ≥ 4.5:1 en todo texto operativo; `--text-dim` solo para metadatos.
- `pickTextColor()` se mantiene para el texto sobre `--accent`. Verificar con Rúnico (`#152421`, oscuro) y Canta Corazón (`#C25B32`).
- Ningún estado se comunica solo con color: siempre va el texto del estado en el badge.
- Foco visible con `--focus-ring` en todo elemento interactivo.

## 7. Fuera de alcance

- Plantillas de cotización PDF (`plantillas/<slug>/`, `COTIZ_EXPORT_CSS`, `cotizDocCss()`): tienen su propio diseño por restaurante y no se tocan.
- Modo oscuro: no por ahora.
- Lógica de datos, Supabase, RLS: el rediseño es solo de presentación.

## 8. Cómo aplicarlo (instrucciones para Claude Code)

Hacerlo **por fases, un commit por fase**, mostrando el resultado antes de hacer push.

1. **Tokens.** Reemplazar el bloque `:root` por los tokens de la sección 2. Actualizar `applyLocationTheme()`: hoy fuerza los neutros viejos con `setProperty` (`--bg`, `--surface`, …); quitar esas líneas o ponerles los valores nuevos, y calcular `--accent-strong` y `--accent-soft`. Reemplazar todos los colores sueltos por tokens; buscar como mínimo `rgba(226,87,43`, `rgba(156,178,51`, `rgba(232,185,58`, `rgba(214,73,58`, `#9BA3A8` y `color:#fff`. Pasar los estados (aprobado, pendiente, rechazado, ingresado, semáforo) de `--accent`/`--accent-2` a `--ok`/`--warn`/`--danger`. Sin cambios de layout en esta fase.
2. **Componentes.** Botones, inputs, tarjetas, badge unificado, modales, toasts y estados vacíos según la sección 4. Mantener los nombres de clase que usa el JS; si se crea una clase nueva, dejar la vieja como alias hasta terminar.
3. **Navegación.** Barra inferior en celular y barra lateral en escritorio (sección 3). Conservar los `id` `tab-*` y la lógica de visibilidad por rol (`tab-admin`, `tab-calculadora`).
4. **Pulido por módulo.** Recetario → Producción → Pedidos (kanban + semáforo) → Bajas → Inventario → Costeo → Admin.

Verificar cada fase en 390 px (celular) y 1280 px (escritorio), con al menos Cantina Dos Santos y Rúnico. Al terminar, actualizar la línea de "Tema visual" en `CLAUDE.md` para que apunte a este archivo.
