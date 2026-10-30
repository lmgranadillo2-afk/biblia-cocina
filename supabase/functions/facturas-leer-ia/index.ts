// Supabase Edge Function "facturas-leer-ia": lee la foto de una factura con Claude (visión) y
// devuelve proveedor, número, monto y fecha para precargar el formulario de Facturas.
// No guarda nada; solo lee la imagen y responde el JSON extraído. El usuario siempre puede
// corregir o dejar vacío lo que la IA no haya podido leer.
//
// Entrada: { image_base64: string (sin el prefijo "data:..."), media_type: string }
// Salida:  { data: { proveedor, numero_factura, monto, fecha_factura } } o { error: string }
//
// Despliegue: Supabase → Edge Functions → Deploy a new function → nombre "facturas-leer-ia" →
// pegar este código. "Verify JWT" debe quedar ENCENDIDO (requiere sesión de la app).
// Secreto nuevo requerido: ANTHROPIC_API_KEY (Supabase → Edge Functions → Secrets).

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const MODELO = "claude-haiku-5-5";

const PROMPT = `Esta es una foto de una factura de compra de un restaurante en Colombia. Leé la imagen y
devolvé SOLO un JSON (sin texto adicional, sin markdown, sin explicación) con esta forma exacta:
{"proveedor": string o null, "numero_factura": string o null, "monto": number o null, "fecha_factura": string o null}

- proveedor: el nombre del negocio o proveedor que emite la factura.
- numero_factura: el número o consecutivo de la factura, tal como aparece.
- monto: el valor TOTAL a pagar, como número sin puntos, comas ni símbolo de moneda (ejemplo: 150000, nunca "$150.000").
- fecha_factura: la fecha de la factura en formato "YYYY-MM-DD". Si el año no se ve, asumí el año actual.
Si algún dato no se ve con claridad, devolvé null para ese campo en vez de adivinar. No inventes datos.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "Falta configurar ANTHROPIC_API_KEY en los secretos de Supabase" }, 500);

    const b = await req.json().catch(() => ({}));
    const imageBase64 = String(b.image_base64 ?? "");
    const mediaType = String(b.media_type ?? "image/jpeg");
    if (!imageBase64) return json({ error: "Falta la imagen" }, 400);
    if (!/^image\/(jpeg|png|webp|gif)$/.test(mediaType)) return json({ error: "Ese tipo de archivo no lo puede leer la IA" }, 400);

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODELO,
        max_tokens: 300,
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: imageBase64 } },
            { type: "text", text: PROMPT },
          ],
        }],
      }),
    });

    if (!resp.ok) {
      return json({ error: "La IA no pudo leer la factura (" + resp.status + ")" }, 502);
    }

    const result = await resp.json();
    const texto: string = result?.content?.[0]?.text ?? "{}";
    const m = texto.match(/\{[\s\S]*\}/);
    if (!m) return json({ error: "La IA no devolvió un resultado entendible" }, 502);

    let datos: Record<string, unknown>;
    try { datos = JSON.parse(m[0]); } catch { return json({ error: "La IA no devolvió un resultado entendible" }, 502); }

    return json({
      data: {
        proveedor: typeof datos.proveedor === "string" && datos.proveedor.trim() ? datos.proveedor.trim() : null,
        numero_factura: typeof datos.numero_factura === "string" && datos.numero_factura.trim() ? datos.numero_factura.trim() : null,
        monto: typeof datos.monto === "number" && isFinite(datos.monto) ? datos.monto : null,
        fecha_factura: typeof datos.fecha_factura === "string" && /^\d{4}-\d{2}-\d{2}$/.test(datos.fecha_factura) ? datos.fecha_factura : null,
      },
    });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
