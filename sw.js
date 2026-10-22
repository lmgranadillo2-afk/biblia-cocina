// Service worker de la Biblia de Cocina: solo para las notificaciones del chat (no guarda la app en caché).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

// Llega una notificación: si la app está abierta y a la vista no se muestra (la app ya avisa adentro).
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { cuerpo: e.data ? e.data.text() : '' }; }
  e.waitUntil((async () => {
    const ventanas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (ventanas.some(v => v.visibilityState === 'visible' && v.focused)) return;
    await self.registration.showNotification(d.titulo || 'Biblia de Cocina', {
      body: d.cuerpo || 'Mensaje nuevo',
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      tag: d.conversacion_id || 'chat',   // un aviso por conversación (el nuevo reemplaza al anterior)
      renotify: true,
      data: { url: d.url || '/', conversacion_id: d.conversacion_id || null, location_id: d.location_id || null }
    });
  })());
});

// Tocar la notificación: abre la app (o la trae al frente) en esa conversación.
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const datos = e.notification.data || {};
  e.waitUntil((async () => {
    const ventanas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const v = ventanas.find(x => new URL(x.url).origin === self.location.origin);
    if (v) {
      await v.focus();
      v.postMessage({ tipo: 'abrir-chat', conversacion_id: datos.conversacion_id, location_id: datos.location_id });
      return;
    }
    await self.clients.openWindow(datos.url || '/');
  })());
});
