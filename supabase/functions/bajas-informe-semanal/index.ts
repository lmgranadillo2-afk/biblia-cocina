// Supabase Edge Function "bajas-informe-semanal": arma el informe de bajas de la semana que
// acaba de terminar (lunes a domingo, todos los puntos) y lo deja guardado como CSV.
//
// La llama un cron de Supabase (pg_cron) cada lunes a las 11 a.m. hora Colombia (16:00 UTC),
// nunca una persona. Verificación: el mismo token que usa el cron de Toteat
// (public.toteat_cron_config), para no tener que configurar un secreto aparte.
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → nombre
// "bajas-informe-semanal" → pegar este código. "Verify JWT" debe quedar APAGADO (lo llama el
// cron, sin sesión). No necesita secretos nuevos.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = { "Access-Control-Allow-Origin": "*" };
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const BAJA_ESTADO: Record<string, string> = { aprobado: "Ingresada", rechazado: "Denegada", pendiente: "Pendiente" };

function csvCelda(v: unknown): string {
  const s = v === null || v === undefined ? "" : String(v);
  return /[";\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const b = await req.json().catch(() => ({}));

    const { data: cfg } = await admin.from("toteat_cron_config").select("token").eq("id", 1).maybeSingle();
    if (!cfg?.token || b.cron_token !== cfg.token) return json({ error: "No autorizado" }, 401);

    // "Hoy" en hora Colombia (UTC-5), para calcular la semana lunes→domingo que acaba de terminar.
    const ahoraCol = new Date(Date.now() - 5 * 60 * 60 * 1000);
    const hoyISO = ahoraCol.toISOString().slice(0, 10);
    const hoy = new Date(hoyISO + "T00:00:00Z");
    const diaSemana = hoy.getUTCDay(); // 0=domingo … 1=lunes
    const diasDesdeLunes = diaSemana === 0 ? 6 : diaSemana - 1;
    const lunesEsta = new Date(hoy); lunesEsta.setUTCDate(hoy.getUTCDate() - diasDesdeLunes);
    const lunesPasado = new Date(lunesEsta); lunesPasado.setUTCDate(lunesEsta.getUTCDate() - 7);
    const domingoPasado = new Date(lunesEsta); domingoPasado.setUTCDate(lunesEsta.getUTCDate() - 1);
    const semana_inicio = lunesPasado.toISOString().slice(0, 10);
    const semana_fin = domingoPasado.toISOString().slice(0, 10);

    const { data: bajas, error: e1 } = await admin
      .from("bajas")
      .select("fecha, codigo, tipo, item_name, cantidad, unidad, motivo, causa, causa_dato, status, creado_por_nombre, resuelto_por, location_id, area_id")
      .gte("fecha", semana_inicio)
      .lte("fecha", semana_fin)
      .order("location_id", { ascending: true })
      .order("fecha", { ascending: true });
    if (e1) throw e1;

    const { data: locations } = await admin.from("locations").select("id, name");
    const { data: areas } = await admin.from("areas").select("id, name, location_id");
    const locMap: Record<string, string> = Object.fromEntries((locations || []).map((l) => [l.id, l.name]));
    const areaMap: Record<string, string> = Object.fromEntries((areas || []).map((a) => [a.id, a.name]));

    const filas = (bajas || []).map((x) => [
      locMap[x.location_id] || "", areaMap[x.area_id] || "", x.fecha, x.codigo || "",
      x.tipo === "insumo" ? "Insumo" : "Receta preparada", x.item_name, x.cantidad, x.unidad,
      x.causa || "", x.causa_dato || "", x.motivo || "", BAJA_ESTADO[x.status] || x.status,
      x.creado_por_nombre || "", x.resuelto_por || "",
    ]);

    const encabezado = ["Punto", "Área", "Fecha", "Código", "Tipo", "Producto", "Cantidad", "Unidad", "Causa", "Detalle causa", "Motivo", "Estado", "Registró", "Resolvió"];
    const csv = "﻿" + [encabezado, ...filas].map((f) => f.map(csvCelda).join(";")).join("\r\n");

    const path = `${semana_inicio}.csv`;
    const { error: e2 } = await admin.storage.from("informes-bajas").upload(path, new TextEncoder().encode(csv), { contentType: "text/csv", upsert: true });
    if (e2) throw e2;

    const { error: e3 } = await admin.from("bajas_informes_semanales")
      .upsert({ semana_inicio, semana_fin, archivo_path: path, cantidad_bajas: filas.length }, { onConflict: "semana_inicio" });
    if (e3) throw e3;

    return json({ ok: true, semana_inicio, semana_fin, cantidad_bajas: filas.length });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
