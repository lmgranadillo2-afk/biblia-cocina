// Supabase Edge Function "usuarios-admin": crear usuarios y cambiar contraseñas desde Admin → Usuarios.
//
// Solo la puede usar un super admin (se comprueba con la sesión que manda la app).
// Acciones:
//   { accion: "crear", cedula?, correo?, nombre, password, rol: "cocina"|"admin", location_id, area_ids: [] }
//     Si viene cédula, la cuenta entra con "<cédula>@biblia-cocina.vercel.app" (correo interno: la persona solo
//     escribe su cédula en la pantalla de entrada). Queda confirmada; no se manda ningún correo.
//   { accion: "password", user_id, password }
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → nombre "usuarios-admin" → pegar este código.
// "Verify JWT" puede quedar ENCENDIDO. No necesita secretos nuevos.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const DOMINIO_CEDULA = "biblia-cocina.vercel.app";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: quien } = await admin.auth.getUser(jwt);
    if (!quien?.user) return json({ error: "Inicia sesión en la app primero" }, 401);
    const { data: yo } = await admin.from("profiles").select("is_super_admin").eq("id", quien.user.id).maybeSingle();
    if (!yo?.is_super_admin) return json({ error: "Solo el super admin puede crear usuarios o cambiar contraseñas" }, 403);

    const b = await req.json().catch(() => ({}));
    const password = String(b.password ?? "");
    if (password.length < 8) return json({ error: "La contraseña debe tener al menos 8 caracteres" }, 400);

    if (b.accion === "password") {
      if (!b.user_id) return json({ error: "Falta la persona" }, 400);
      const { error } = await admin.auth.admin.updateUserById(String(b.user_id), { password });
      if (error) return json({ error: "No se pudo cambiar: " + error.message }, 400);
      return json({ ok: true });
    }

    if (b.accion !== "crear") return json({ error: "Acción desconocida" }, 400);
    const cedula = String(b.cedula ?? "").replace(/\D/g, "");
    const correo = String(b.correo ?? "").trim().toLowerCase();
    const nombre = String(b.nombre ?? "").trim();
    const rol = b.rol === "admin" ? "admin" : "cocina";
    if (!nombre) return json({ error: "Escribe el nombre" }, 400);
    if (!cedula && !correo) return json({ error: "Escribe la cédula o el correo" }, 400);
    if (cedula && !/^[0-9]{5,12}$/.test(cedula)) return json({ error: "La cédula debe tener de 5 a 12 números" }, 400);
    if (!cedula && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) return json({ error: "Ese correo no es válido" }, 400);
    const email = cedula ? `${cedula}@${DOMINIO_CEDULA}` : correo;

    const { data: creado, error: e1 } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { name: nombre } });
    if (e1 || !creado?.user) {
      const msg = /already|registered|exists/i.test(e1?.message ?? "") ? `Ya existe una cuenta con esa ${cedula ? "cédula" : "dirección de correo"}` : "No se pudo crear: " + (e1?.message ?? "");
      return json({ error: msg }, 400);
    }
    const id = creado.user.id;
    // El disparador handle_new_user crea el perfil; aquí se completa nombre, correo y rol.
    const { data: perfil } = await admin.from("profiles").select("id").eq("id", id).maybeSingle();
    if (perfil) await admin.from("profiles").update({ name: nombre, email, role: rol }).eq("id", id);
    else await admin.from("profiles").insert({ id, name: nombre, email, role: rol });
    // Usuario nuevo: no tiene accesos todavía, así que se insertan directo.
    if (b.location_id) await admin.from("user_locations").insert({ user_id: id, location_id: b.location_id });
    const areas: string[] = Array.isArray(b.area_ids) ? b.area_ids : [];
    if (areas.length) await admin.from("user_areas").insert(areas.map((a) => ({ user_id: id, area_id: a })));
    return json({ ok: true, id, acceso: cedula ? "cedula" : "correo" });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
