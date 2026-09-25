// Supabase Edge Function: sincroniza la carta de los restaurantes con Toteat.
//
// Dos formas de llamarla:
//  1) Desde la app (admin con sesión):  POST { location_id, aplicar }
//     aplicar=false → solo muestra qué cambiaría; true → guarda.
//  2) Automática (pg_cron, cada madrugada): POST { cron_token }
//     Sincroniza todos los restaurantes con credenciales y aplica, salvo que algo se vea raro
//     (Toteat vacío o demasiados productos a desactivar): en ese caso no toca nada y lo deja en el log.
//
// Credenciales de Toteat: secretos de Supabase por restaurante, uno por dato (ej. para el slug dos-santos):
// TOTEAT_DOS_SANTOS_XIR, TOTEAT_DOS_SANTOS_XIL, TOTEAT_DOS_SANTOS_XIU y TOTEAT_DOS_SANTOS_TOKEN.
// Nunca van en el código ni en la app.
//
// La verificación de JWT del gateway va DESACTIVADA: la función valida por su cuenta
// (sesión de usuario admin, o el token interno del cron guardado en la base).
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// Compara nombres sin tildes, mayúsculas ni espacios de más.
const norm = (s: unknown) =>
  String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase().replace(/\s+/g, " ").trim();

// En modo automático no se aplica si se desactivaría más de esta fracción de la carta activa.
const MAX_DESACTIVAR_AUTO = 0.2;

class ErrorSync extends Error {
  constructor(msg: string, public status = 400) { super(msg); }
}

// Lee las credenciales del secreto combinado (formato libre o JSON).
function leerCredenciales(raw: string): Record<string, string> {
  const texto = raw.replace(/[“”„″«»]/g, '"').replace(/[‘’′]/g, "'").trim();
  try {
    const obj = JSON.parse(texto);
    if (obj && typeof obj === "object") {
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(obj)) out[k.trim().toLowerCase()] = String(v ?? "").trim();
      return out;
    }
  } catch { /* formato libre: se lee abajo */ }
  const out: Record<string, string> = {};
  for (const k of ["xir", "xil", "xiu", "token"]) {
    const m = texto.match(new RegExp(`["']?\\s*${k}\\s*["']?\\s*[:=]\\s*["']?\\s*([^"',;\\s{}]+)`, "i"));
    if (m) out[k] = m[1].trim();
  }
  return out;
}

const prefijoSecreto = (slug: string) => "TOTEAT_" + String(slug).toUpperCase().replace(/[^A-Z0-9]/g, "_");

// Credenciales de un restaurante: un secreto por dato (recomendado) o todo junto en TOTEAT_<SLUG>.
function credenciales(slug: string): { cred: Record<string, string>; faltan: string[]; prefijo: string } {
  const prefijo = prefijoSecreto(slug);
  const raw = Deno.env.get(prefijo);
  const cred: Record<string, string> = raw ? leerCredenciales(raw) : {};
  for (const k of ["xir", "xil", "xiu", "token"]) {
    const suelto = Deno.env.get(`${prefijo}_${k.toUpperCase()}`);
    if (suelto && suelto.trim()) cred[k] = suelto.trim().replace(/^["'“”]+|["'“”]+$/g, "");
  }
  return { cred, faltan: ["xir", "xil", "xiu", "token"].filter((k) => !cred[k]), prefijo };
}

// Compara la carta de Toteat con la de la app y, si aplicar=true, guarda los cambios.
async function sincronizar(svc: SupabaseClient, loc: { id: string; slug: string; name: string }, aplicar: boolean, automatico: boolean) {
  const { cred, faltan, prefijo } = credenciales(loc.slug);
  if (faltan.length) {
    throw new ErrorSync(`Faltan credenciales de Toteat: ${faltan.map((k) => `${prefijo}_${k.toUpperCase()}`).join(", ")}. Crealos en Supabase → Edge Functions → Secrets.`);
  }

  // Carta activa en Toteat (máximo 3 consultas por minuto).
  const qs = new URLSearchParams({ xir: cred.xir, xil: cred.xil, xiu: cred.xiu, xapitoken: cred.token });
  const r = await fetch("https://api.toteat.com/mw/or/1.0/products?" + qs.toString());
  const body = await r.json().catch(() => null);
  if (r.status === 429) throw new ErrorSync("Toteat permite 3 consultas por minuto. Esperá un minuto y probá de nuevo.", 429);
  if (!r.ok || !body || body.ok === false) {
    throw new ErrorSync("Toteat rechazó la consulta: " + (body?.msg ?? `error ${r.status}`) + ". Revisá las credenciales y que la ruta 'products' esté habilitada en Seguridad.", 502);
  }
  const productos = (body.data ?? []).filter((p: any) => !p.isModifier);

  const { data: carta, error: cErr } = await svc.from("carta_items").select("*").eq("location_id", loc.id);
  if (cErr) throw new ErrorSync("No se pudo leer la carta: " + cErr.message, 500);

  const porToteat = new Map<string, any>();
  const porNombre = new Map<string, any>();
  for (const c of carta ?? []) {
    if (c.toteat_id) porToteat.set(String(c.toteat_id), c);
    else if (!porNombre.has(norm(c.nombre))) porNombre.set(norm(c.nombre), c);
  }

  const ahora = new Date().toISOString();
  let orden = (carta ?? []).reduce((m: number, c: any) => Math.max(m, c.orden ?? 0), 0);
  const vistos = new Set<string>();
  const actualizaciones: { id: string; cambios: Record<string, unknown> }[] = [];
  const cambiosPrecio: { nombre: string; antes: number; despues: number }[] = [];
  const nuevos: any[] = [];
  let vinculados = 0;

  for (const p of productos) {
    const tid = String(p.id);
    const nombre = String(p.name ?? "").trim();
    if (!nombre) continue;
    const precio = Math.round(Number(p.price) || 0);
    const c = porToteat.get(tid) ?? porNombre.get(norm(nombre));
    if (c && !vistos.has(c.id)) {
      vistos.add(c.id);
      const cambios: Record<string, unknown> = {};
      if (!c.toteat_id) { cambios.toteat_id = tid; vinculados++; porNombre.delete(norm(c.nombre)); }
      if (Math.round(Number(c.precio) || 0) !== precio) {
        cambios.precio = precio;
        cambiosPrecio.push({ nombre: c.nombre, antes: Math.round(Number(c.precio) || 0), despues: precio });
      }
      if (!c.activo) cambios.activo = true;
      if (Object.keys(cambios).length) actualizaciones.push({ id: c.id, cambios });
    } else if (!c) {
      nuevos.push({
        location_id: loc.id, toteat_id: tid, toteat_sync_at: ahora,
        categoria: String(p.category ?? "SIN CATEGORÍA").trim().toUpperCase() || "SIN CATEGORÍA",
        nombre: nombre.toUpperCase(), precio, activo: true, orden: ++orden,
      });
    }
  }
  // Lo que está activo en la app pero ya no está activo en Toteat se desactiva (no se borra).
  const activos = (carta ?? []).filter((c: any) => c.activo);
  const desactivar = activos.filter((c: any) => !vistos.has(c.id));

  const resumen: Record<string, unknown> = {
    ok: true,
    restaurante: loc.name,
    productos_toteat: productos.length,
    carta_app: (carta ?? []).length,
    vinculados_por_nombre: vinculados,
    cambios_precio: cambiosPrecio,
    nuevos: nuevos.map((n) => ({ nombre: n.nombre, categoria: n.categoria, precio: n.precio })),
    desactivados: desactivar.map((c: any) => ({ nombre: c.nombre, categoria: c.categoria })),
    aplicado: false,
  };

  // Protección del modo automático: ante algo raro, no toca nada y lo deja para revisión manual.
  if (automatico) {
    if (!productos.length) { resumen.revision = "Toteat devolvió la carta vacía."; return resumen; }
    if (activos.length && desactivar.length > activos.length * MAX_DESACTIVAR_AUTO) {
      resumen.revision = `Se desactivarían ${desactivar.length} de ${activos.length} productos activos.`;
      return resumen;
    }
  }
  if (!aplicar) return resumen;

  for (const a of actualizaciones) {
    const { error } = await svc.from("carta_items").update(a.cambios).eq("id", a.id);
    if (error) throw new ErrorSync("Error actualizando la carta: " + error.message, 500);
  }
  if (vistos.size) {
    const { error } = await svc.from("carta_items").update({ toteat_sync_at: ahora }).in("id", [...vistos]);
    if (error) throw new ErrorSync("Error marcando la sincronización: " + error.message, 500);
  }
  if (nuevos.length) {
    const { error } = await svc.from("carta_items").upsert(nuevos, { onConflict: "location_id,categoria,nombre", ignoreDuplicates: true });
    if (error) throw new ErrorSync("Error agregando productos nuevos: " + error.message, 500);
  }
  if (desactivar.length) {
    const { error } = await svc.from("carta_items").update({ activo: false }).in("id", desactivar.map((c: any) => c.id));
    if (error) throw new ErrorSync("Error desactivando productos: " + error.message, 500);
  }
  resumen.aplicado = true;
  return resumen;
}

// Fecha YYYYMMDD en hora de Colombia (UTC-5), desplazada `dias` hacia atrás.
function fechaToteat(dias: number) {
  const d = new Date(Date.now() - 5 * 3600 * 1000 - dias * 86400 * 1000);
  return d.toISOString().slice(0, 10).replace(/-/g, "");
}

// Costos por producto desde las ventas de los últimos 15 días (campo unitCost, solo "nuevo Toteat").
// Toma el costo más reciente de cada producto vendido; lo no vendido conserva su costo.
async function sincronizarCostos(svc: SupabaseClient, loc: { id: string; slug: string; name: string }, aplicar: boolean) {
  const { cred, faltan, prefijo } = credenciales(loc.slug);
  if (faltan.length) throw new ErrorSync(`Faltan credenciales de Toteat: ${faltan.map((k) => `${prefijo}_${k.toUpperCase()}`).join(", ")}.`);

  const ini = fechaToteat(14), end = fechaToteat(0);
  const qs = new URLSearchParams({ xir: cred.xir, xil: cred.xil, xiu: cred.xiu, xapitoken: cred.token, ini, end });
  const r = await fetch("https://api.toteat.com/mw/or/1.0/sales?" + qs.toString());
  const body = await r.json().catch(() => null);
  if (r.status === 429) throw new ErrorSync("Toteat permite 3 consultas por minuto. Esperá un minuto y probá de nuevo.", 429);
  if (!r.ok || !body || body.ok === false) {
    throw new ErrorSync("Toteat rechazó la consulta de ventas: " + (typeof body?.msg === "string" ? body.msg : JSON.stringify(body?.msg ?? r.status)) + ". Revisá que la ruta 'sales' esté habilitada en Seguridad.", 502);
  }
  const ventas = (body.data ?? []).filter((t: any) => t.fiscalType !== "NC")
    .sort((a: any, b: any) => String(a.dateClosed ?? "").localeCompare(String(b.dateClosed ?? "")));

  // Último costo unitario conocido de cada producto (por ID y por nombre).
  const porId = new Map<string, number>(), porNombre = new Map<string, number>();
  const vendidos = new Map<string, { id: string; name: string; unitCost: number }>();
  let lineas = 0, lineasConCosto = 0;
  for (const t of ventas) {
    for (const p of t.products ?? []) {
      lineas++;
      const costo = Number(p.unitCost ?? p["unitCost*"]);
      const id = String(p.id ?? ""), nombre = String(p.name ?? "");
      vendidos.set(id || norm(nombre), { id, name: nombre, unitCost: costo || 0 });
      if (!(costo > 0) || !(Number(p.quantity) > 0)) continue;
      lineasConCosto++;
      if (id) porId.set(id, costo);
      if (nombre) porNombre.set(norm(nombre), costo);
    }
  }

  const { data: carta, error: cErr } = await svc.from("carta_items").select("id, nombre, categoria, costo, toteat_id").eq("location_id", loc.id);
  if (cErr) throw new ErrorSync("No se pudo leer la carta: " + cErr.message, 500);

  const cambios: { id: string; nombre: string; antes: number | null; despues: number }[] = [];
  let conCostoToteat = 0;
  for (const c of carta ?? []) {
    const nuevo = (c.toteat_id && porId.get(String(c.toteat_id))) ?? porNombre.get(norm(c.nombre));
    if (!nuevo) continue;
    conCostoToteat++;
    const redondo = Math.round(nuevo * 100) / 100;
    const antes = c.costo === null || c.costo === undefined ? null : Math.round(Number(c.costo) * 100) / 100;
    if (antes !== redondo) cambios.push({ id: c.id, nombre: c.nombre, antes, despues: redondo });
  }

  const resumen: Record<string, unknown> = {
    ok: true, tipo: "costos", restaurante: loc.name, periodo: `${ini}-${end}`,
    ventas: ventas.length, lineas_vendidas: lineas, lineas_con_costo: lineasConCosto,
    productos_vendidos: vendidos.size, carta_con_costo_toteat: conCostoToteat,
    cambios_costo: cambios.map(({ nombre, antes, despues }) => ({ nombre, antes, despues })),
    // Diagnóstico: algunos productos vendidos tal como los manda Toteat (sin datos sensibles).
    muestra_vendidos: [...vendidos.values()].slice(0, 8),
    aplicado: false,
  };
  if (!aplicar) return resumen;
  for (const c of cambios) {
    const { error } = await svc.from("carta_items").update({ costo: c.despues }).eq("id", c.id);
    if (error) throw new ErrorSync("Error guardando costos: " + error.message, 500);
  }
  resumen.aplicado = true;
  return resumen;
}

// Consulta genérica a la API de Toteat (GET) con las credenciales del restaurante.
async function toteatGet(cred: Record<string, string>, ruta: string, extra: Record<string, string>) {
  const qs = new URLSearchParams({ xir: cred.xir, xil: cred.xil, xiu: cred.xiu, xapitoken: cred.token, ...extra });
  const r = await fetch(`https://api.toteat.com/mw/or/1.0/${ruta}?` + qs.toString());
  const body = await r.json().catch(() => null);
  if (r.status === 429) throw new ErrorSync("Toteat permite 3 consultas por minuto. Esperá un minuto y probá de nuevo.", 429);
  if (!r.ok || !body || body.ok === false) {
    throw new ErrorSync(`Toteat rechazó la consulta '${ruta}': ` + (typeof body?.msg === "string" ? body.msg : JSON.stringify(body?.msg ?? r.status)) + `. Revisá que la ruta '${ruta}' esté habilitada en Seguridad.`, 502);
  }
  return body;
}
const sumarDia = (yyyymmdd: string, dias: number) => {
  const d = new Date(Date.UTC(+yyyymmdd.slice(0, 4), +yyyymmdd.slice(4, 6) - 1, +yyyymmdd.slice(6, 8)) + dias * 86400000);
  return d.toISOString().slice(0, 10).replace(/-/g, "");
};

// Food cost de un período (máx. 15 días):
//  - Ventas netas y costo teórico (recetas de Toteat) desde las ventas.
//  - Merma desde el inventario: entre la primera y la última toma física del período,
//    lo esperado (inicial + compras + transformaciones + uso por ventas) contra lo contado.
async function foodCost(loc: { id: string; slug: string; name: string }, ini: string, end: string) {
  const { cred, faltan, prefijo } = credenciales(loc.slug);
  if (faltan.length) throw new ErrorSync(`Faltan credenciales de Toteat: ${faltan.map((k) => `${prefijo}_${k.toUpperCase()}`).join(", ")}.`);
  if (!/^\d{8}$/.test(ini) || !/^\d{8}$/.test(end) || end < ini) throw new ErrorSync("Fechas inválidas.");

  // ---- Ventas ----
  const ventasBody = await toteatGet(cred, "sales", { ini, end });
  let ventasNetas = 0, costoTeorico = 0, ventasSinCosto = 0, pagos = 0;
  const porCategoria = new Map<string, { ventas: number; costo: number }>();
  const porProducto = new Map<string, { nombre: string; categoria: string; cantidad: number; ventas: number; costo: number }>();
  for (const t of ventasBody.data ?? []) {
    pagos++;
    for (const p of t.products ?? []) {
      const cant = Number(p.quantity) || 0;
      const neto = (Number(p.payed) || 0) - (Number(p.taxes) || 0);
      const costo = Number(p.totalCost ?? p["totalCost*"]) || (Number(p.unitCost ?? p["unitCost*"]) || 0) * cant;
      ventasNetas += neto; costoTeorico += costo;
      if (!costo && neto > 0) ventasSinCosto += neto;
      const cat = String(p.hierarchyName ?? "Sin categoría");
      const c = porCategoria.get(cat) ?? { ventas: 0, costo: 0 };
      c.ventas += neto; c.costo += costo; porCategoria.set(cat, c);
      const key = String(p.id ?? p.name);
      const pr = porProducto.get(key) ?? { nombre: String(p.name ?? ""), categoria: cat, cantidad: 0, ventas: 0, costo: 0 };
      pr.cantidad += cant; pr.ventas += neto; pr.costo += costo; porProducto.set(key, pr);
    }
  }

  // ---- Inventario (se pide un día más para tener la toma de cierre) ----
  const invBody = await toteatGet(cred, "inventorystate", { initial_date: ini, final_date: sumarDia(end, 1) });
  let mermaValor = 0, ingredientesConTomas = 0, ingredientesSinTomas = 0;
  let primeraToma: string | null = null, ultimaToma: string | null = null;
  const mermas: { ingrediente: string; unidad: string; cantidad: number; valor: number }[] = [];
  for (const ing of invBody.data ?? []) {
    let cantMerma = 0, costoUnit = 0, tuvoVentana = false;
    for (const w of ing.warehouses ?? []) {
      const dias = [...(w.inventories ?? [])].sort((a: any, b: any) => String(a.date).localeCompare(String(b.date)));
      for (const d of dias) if (Number(d.cost) > 0) costoUnit = Number(d.cost);
      const tomas = dias.map((d: any, i: number) => ({ d, i })).filter((x: any) => x.d.is_taken);
      if (tomas.length < 2) continue;
      const a = tomas[0], b = tomas[tomas.length - 1];
      tuvoVentana = true;
      let esperado = Number(a.d.initial_inventory) || 0;
      for (let i = a.i; i < b.i; i++) {
        const d = dias[i];
        esperado += (Number(d.purchase) || 0) + (Number(d.transformed) || 0) + (Number(d.use) || 0);
      }
      cantMerma += esperado - (Number(b.d.initial_inventory) || 0); // positivo = falta producto
      const fa = String(a.d.date), fb = String(b.d.date);
      if (!primeraToma || fa < primeraToma) primeraToma = fa;
      if (!ultimaToma || fb > ultimaToma) ultimaToma = fb;
    }
    if (!tuvoVentana) { ingredientesSinTomas++; continue; }
    ingredientesConTomas++;
    const valor = cantMerma * costoUnit;
    mermaValor += valor;
    if (Math.abs(valor) >= 1) mermas.push({ ingrediente: String(ing.product ?? ""), unidad: String(ing.unit ?? ""), cantidad: Math.round(cantMerma * 1000) / 1000, valor: Math.round(valor) });
  }
  mermas.sort((x, y) => y.valor - x.valor);

  const pct = (a: number, b: number) => (b ? Math.round((a / b) * 1000) / 10 : null);
  const productos = [...porProducto.values()].filter((p) => p.ventas > 0 && p.costo > 0)
    .map((p) => ({ ...p, ventas: Math.round(p.ventas), costo: Math.round(p.costo), foodcost: pct(p.costo, p.ventas) }));
  return {
    ok: true, tipo: "foodcost", restaurante: loc.name, ini, end,
    pagos, ventas_netas: Math.round(ventasNetas), costo_teorico: Math.round(costoTeorico),
    foodcost_teorico: pct(costoTeorico, ventasNetas),
    ventas_sin_costo: Math.round(ventasSinCosto),
    merma_valor: Math.round(mermaValor),
    costo_real: Math.round(costoTeorico + mermaValor),
    foodcost_real: ingredientesConTomas ? pct(costoTeorico + mermaValor, ventasNetas) : null,
    tomas: { primera: primeraToma, ultima: ultimaToma, ingredientes_con_tomas: ingredientesConTomas, ingredientes_sin_tomas: ingredientesSinTomas },
    categorias: [...porCategoria.entries()].map(([categoria, v]) => ({ categoria, ventas: Math.round(v.ventas), costo: Math.round(v.costo), foodcost: pct(v.costo, v.ventas) }))
      .sort((a, b) => b.ventas - a.ventas),
    peores_productos: productos.filter((p) => p.cantidad >= 3).sort((a, b) => (b.foodcost ?? 0) - (a.foodcost ?? 0)).slice(0, 12),
    mas_vendidos: productos.sort((a, b) => b.ventas - a.ventas).slice(0, 12),
    top_mermas: mermas.slice(0, 15),
    top_sobrantes: mermas.filter((m) => m.valor < 0).sort((a, b) => a.valor - b.valor).slice(0, 5),
  };
}

async function registrar(svc: SupabaseClient, locationId: string, origen: string, resumen: Record<string, unknown> | null, error: string | null) {
  await svc.from("toteat_sync_log").insert({
    location_id: locationId, origen,
    aplicado: !!resumen?.aplicado,
    resumen: resumen ? {
      productos_toteat: resumen.productos_toteat,
      cambios_precio: (resumen.cambios_precio as unknown[])?.length ?? 0,
      nuevos: (resumen.nuevos as unknown[])?.length ?? 0,
      desactivados: (resumen.desactivados as unknown[])?.length ?? 0,
      revision: resumen.revision ?? null,
    } : null,
    error,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const svc = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  try {
    const payload = await req.json().catch(() => ({}));

    // ---- Modo automático (pg_cron) ----
    if (payload.cron_token) {
      const { data: cfg } = await svc.from("toteat_cron_config").select("token").eq("id", 1).maybeSingle();
      if (!cfg || cfg.token !== payload.cron_token) return json({ ok: false, error: "Token de cron inválido." }, 401);
      const { data: locs } = await svc.from("locations").select("id, slug, name").eq("activo", true);
      const resultados: Record<string, unknown>[] = [];
      for (const loc of locs ?? []) {
        if (credenciales(loc.slug).faltan.length === 4) continue; // restaurante sin Toteat configurado
        try {
          const res = await sincronizar(svc, loc, true, true);
          await registrar(svc, loc.id, "automatico", res, null);
          resultados.push({ restaurante: loc.name, aplicado: res.aplicado, revision: res.revision ?? null });
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          await registrar(svc, loc.id, "automatico", null, msg);
          resultados.push({ restaurante: loc.name, error: msg });
        }
        // Costos desde las ventas (solo cambian costos; lo no vendido conserva el suyo).
        try {
          const rc = await sincronizarCostos(svc, loc, true);
          await svc.from("toteat_sync_log").insert({
            location_id: loc.id, origen: "automatico-costos", aplicado: true,
            resumen: { ventas: rc.ventas, cambios_costo: (rc.cambios_costo as unknown[]).length },
          });
        } catch (e) {
          await svc.from("toteat_sync_log").insert({ location_id: loc.id, origen: "automatico-costos", aplicado: false, error: e instanceof Error ? e.message : String(e) });
        }
      }
      return json({ ok: true, resultados });
    }

    // ---- Modo manual (app) ----
    const userClient = createClient(url, anon, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ ok: false, error: "Sesión inválida. Volvé a entrar a la app." }, 401);

    const { location_id, aplicar, accion } = payload;
    const { data: loc } = await userClient.from("locations").select("id, slug, name").eq("id", location_id).maybeSingle();
    if (!loc) return json({ ok: false, error: "No tenés acceso a ese restaurante." }, 403);
    const { data: prof } = await userClient.from("profiles").select("role, is_super_admin").eq("id", user.id).maybeSingle();
    if (!prof || (prof.role !== "admin" && !prof.is_super_admin)) return json({ ok: false, error: "Solo un admin puede sincronizar con Toteat." }, 403);

    try {
      if (accion === "foodcost") {
        return json(await foodCost(loc, String(payload.ini ?? ""), String(payload.end ?? "")));
      }
      if (accion === "costos") {
        const res = await sincronizarCostos(svc, loc, !!aplicar);
        return json(res);
      }
      const res = await sincronizar(svc, loc, !!aplicar, false);
      if (aplicar) await registrar(svc, loc.id, "manual", res, null);
      return json(res);
    } catch (e) {
      if (e instanceof ErrorSync) return json({ ok: false, error: e.message }, e.status);
      throw e;
    }
  } catch (e) {
    return json({ ok: false, error: "Error inesperado: " + (e instanceof Error ? e.message : String(e)) }, 500);
  }
});
