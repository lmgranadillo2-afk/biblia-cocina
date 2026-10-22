// Supabase Edge Function "chat-push": manda la notificación de un mensaje nuevo del chat a los celulares suscritos.
//
// La llama la base de datos (disparador chat_enviar_push, sql/chat_paso2_push.sql) con { token, mensaje_id }.
// El token vive solo en la tabla chat_push_config; la verificación de JWT del gateway va DESACTIVADA.
//
// Secretos (Supabase → Edge Functions → Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT.
// Nunca van en el código ni en la app (la app solo lleva la llave pública).
//
// Quién recibe: grupo del punto → todos los que tienen el punto asignado (user_locations); directo → la otra persona.
// Nunca quien escribió. Los dispositivos que ya no existen (404/410) se borran.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  try {
    const { token, mensaje_id } = await req.json().catch(() => ({}));
    const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: cfg } = await svc.from("chat_push_config").select("token").eq("id", 1).maybeSingle();
    if (!cfg || !token || cfg.token !== token) return json({ ok: false, error: "Token inválido" }, 401);

    const pub = Deno.env.get("VAPID_PUBLIC_KEY"), priv = Deno.env.get("VAPID_PRIVATE_KEY");
    if (!pub || !priv) return json({ ok: false, error: "Faltan los secretos VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY" }, 500);
    webpush.setVapidDetails(Deno.env.get("VAPID_SUBJECT") || "https://biblia-cocina.vercel.app", pub, priv);

    const { data: m } = await svc.from("chat_mensajes").select("*").eq("id", mensaje_id).maybeSingle();
    if (!m) return json({ ok: false, error: "Mensaje no encontrado" }, 404);
    const { data: c } = await svc.from("chat_conversaciones").select("*").eq("id", m.conversacion_id).maybeSingle();
    if (!c) return json({ ok: false, error: "Conversación no encontrada" }, 404);

    // Destinatarios
    let destinatarios: string[] = [];
    let titulo = m.autor_nombre || "Mensaje nuevo";
    if (c.tipo === "punto") {
      const { data: us } = await svc.from("user_locations").select("user_id").eq("location_id", c.location_id);
      destinatarios = (us ?? []).map((u: any) => u.user_id);
      const { data: loc } = await svc.from("locations").select("name").eq("id", c.location_id).maybeSingle();
      titulo = loc?.name || "Grupo del punto";
    } else {
      destinatarios = [c.usuario_a, c.usuario_b];
    }
    destinatarios = [...new Set(destinatarios)].filter((u) => u && u !== m.autor_id);
    if (!destinatarios.length) return json({ ok: true, enviados: 0 });

    const { data: subs } = await svc.from("push_suscripciones").select("id, endpoint, p256dh, auth").in("user_id", destinatarios);
    const texto = (m.texto && String(m.texto).trim()) ? String(m.texto).trim() : "📷 Foto";
    const cuerpo = c.tipo === "punto" ? `${(m.autor_nombre || "Alguien").split(" ")[0]}: ${texto}` : texto;
    const payload = JSON.stringify({
      titulo,
      cuerpo: cuerpo.length > 180 ? cuerpo.slice(0, 177) + "…" : cuerpo,
      conversacion_id: c.id,
      location_id: c.location_id,
      url: "/?chat=" + c.id,
    });

    let enviados = 0;
    const vencidos: string[] = [];
    await Promise.all((subs ?? []).map(async (s: any) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 60 * 60 * 12, urgency: "high" });
        enviados++;
      } catch (e: any) {
        if (e?.statusCode === 404 || e?.statusCode === 410) vencidos.push(s.id);
      }
    }));
    if (vencidos.length) await svc.from("push_suscripciones").delete().in("id", vencidos);
    return json({ ok: true, destinatarios: destinatarios.length, dispositivos: (subs ?? []).length, enviados, borrados: vencidos.length });
  } catch (e) {
    return json({ ok: false, error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
