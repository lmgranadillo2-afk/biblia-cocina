// Supabase Edge Function: sincroniza la carta de un restaurante con Toteat.
//
// Llamada desde la app (usuario admin con sesión):
//   POST { location_id, aplicar }   aplicar=false → solo muestra qué cambiaría; true → guarda.
//
// Credenciales de Toteat: un secreto por restaurante, con nombre TOTEAT_<SLUG> (ej. TOTEAT_DOS_SANTOS)
// y valor JSON: {"xir":"...","xil":"...","xiu":"...","token":"..."}. Nunca van en el código ni en la app.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) Quién llama: tiene que tener sesión, acceso al punto y ser admin.
    const userClient = createClient(url, anon, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ ok: false, error: "Sesión inválida. Volvé a entrar a la app." }, 401);

    const { location_id, aplicar } = await req.json();
    const { data: loc } = await userClient.from("locations").select("id, slug, name").eq("id", location_id).maybeSingle();
    if (!loc) return json({ ok: false, error: "No tenés acceso a ese restaurante." }, 403);
    const { data: prof } = await userClient.from("profiles").select("role, is_super_admin").eq("id", user.id).maybeSingle();
    if (!prof || (prof.role !== "admin" && !prof.is_super_admin)) return json({ ok: false, error: "Solo un admin puede sincronizar con Toteat." }, 403);

    // 2) Credenciales del restaurante.
    const secreto = "TOTEAT_" + String(loc.slug).toUpperCase().replace(/[^A-Z0-9]/g, "_");
    const raw = Deno.env.get(secreto);
    if (!raw) return json({ ok: false, error: `Falta el secreto ${secreto} en Supabase (Edge Functions → Secrets).` }, 400);
    let cred: Record<string, unknown>;
    try { cred = JSON.parse(raw); } catch { return json({ ok: false, error: `El secreto ${secreto} no tiene el formato correcto (JSON).` }, 400); }
    for (const k of ["xir", "xil", "xiu", "token"]) {
      if (!cred[k]) return json({ ok: false, error: `Al secreto ${secreto} le falta el dato "${k}".` }, 400);
    }

    // 3) Carta activa en Toteat (máximo 3 consultas por minuto).
    const qs = new URLSearchParams({ xir: String(cred.xir), xil: String(cred.xil), xiu: String(cred.xiu), xapitoken: String(cred.token) });
    const r = await fetch("https://api.toteat.com/mw/or/1.0/products?" + qs.toString());
    const body = await r.json().catch(() => null);
    if (r.status === 429) return json({ ok: false, error: "Toteat permite 3 consultas por minuto. Esperá un minuto y probá de nuevo." }, 429);
    if (!r.ok || !body || body.ok === false) {
      return json({ ok: false, error: "Toteat rechazó la consulta: " + (body?.msg ?? `error ${r.status}`) + ". Revisá las credenciales y que la ruta 'products' esté habilitada en Seguridad." }, 502);
    }
    const productos = (body.data ?? []).filter((p: any) => !p.isModifier);

    // 4) Comparar con la carta de la app.
    const svc = createClient(url, service);
    const { data: carta, error: cErr } = await svc.from("carta_items").select("*").eq("location_id", loc.id);
    if (cErr) return json({ ok: false, error: "No se pudo leer la carta: " + cErr.message }, 500);

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
        const cambios: Record<string, unknown> = { toteat_sync_at: ahora };
        if (!c.toteat_id) { cambios.toteat_id = tid; vinculados++; porNombre.delete(norm(c.nombre)); }
        if (Math.round(Number(c.precio) || 0) !== precio) {
          cambios.precio = precio;
          cambiosPrecio.push({ nombre: c.nombre, antes: Math.round(Number(c.precio) || 0), despues: precio });
        }
        if (!c.activo) cambios.activo = true;
        actualizaciones.push({ id: c.id, cambios });
      } else if (!c) {
        nuevos.push({
          location_id: loc.id, toteat_id: tid, toteat_sync_at: ahora,
          categoria: String(p.category ?? "SIN CATEGORÍA").trim().toUpperCase() || "SIN CATEGORÍA",
          nombre: nombre.toUpperCase(), precio, activo: true, orden: ++orden,
        });
      }
    }
    // Lo que está activo en la app pero ya no está activo en Toteat se desactiva (no se borra).
    const desactivar = (carta ?? []).filter((c: any) => c.activo && !vistos.has(c.id));

    const resumen = {
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
    if (!aplicar) return json(resumen);

    // 5) Guardar.
    for (const a of actualizaciones) {
      const { error } = await svc.from("carta_items").update(a.cambios).eq("id", a.id);
      if (error) return json({ ok: false, error: "Error actualizando la carta: " + error.message }, 500);
    }
    if (nuevos.length) {
      const { error } = await svc.from("carta_items").upsert(nuevos, { onConflict: "location_id,categoria,nombre", ignoreDuplicates: true });
      if (error) return json({ ok: false, error: "Error agregando productos nuevos: " + error.message }, 500);
    }
    if (desactivar.length) {
      const { error } = await svc.from("carta_items").update({ activo: false }).in("id", desactivar.map((c: any) => c.id));
      if (error) return json({ ok: false, error: "Error desactivando productos: " + error.message }, 500);
    }
    return json({ ...resumen, aplicado: true });
  } catch (e) {
    return json({ ok: false, error: "Error inesperado: " + (e instanceof Error ? e.message : String(e)) }, 500);
  }
});
