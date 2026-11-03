// GoRide push notifications service worker.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (_) { d = { body: event.data && event.data.text() }; }
  const base = new URL('../', self.registration.scope).href;
  event.waitUntil(self.registration.showNotification(d.title || 'GoRide', {
    body: d.body || '',
    tag: d.tag || 'goride',
    renotify: true,
    icon: base + 'icons/Icon-192.png',
    badge: base + 'icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: { url: base + (d.url || '') },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification.data && event.notification.data.url;
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (c.url.startsWith(new URL('../', self.registration.scope).href)) {
        await c.focus();
        if (url && 'navigate' in c) { try { await c.navigate(url); } catch (_) {} }
        return;
      }
    }
    if (url) await self.clients.openWindow(url);
  })());
});
