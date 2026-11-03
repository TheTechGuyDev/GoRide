// GoRide push helper, called from the Flutter app.
window.goridePush = {
  supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  },
  permission() {
    return this.supported() ? Notification.permission : 'unsupported';
  },
  // Returns the subscription as JSON text, or '' if not allowed.
  async subscribe(vapidKey, ask) {
    if (!this.supported()) return '';
    if (Notification.permission === 'denied') return '';
    if (Notification.permission !== 'granted') {
      if (!ask) return '';
      if ((await Notification.requestPermission()) !== 'granted') return '';
    }
    const reg = await navigator.serviceWorker.register('push_sw.js', { scope: './push/' });
    // Wait for this worker (its scope is not the page, so .ready won't fire).
    const w = reg.installing || reg.waiting;
    if (!reg.active && w) {
      await new Promise((ok) => w.addEventListener('statechange', () => { if (w.state === 'activated') ok(); }));
    }
    const pad = '='.repeat((4 - (vapidKey.length % 4)) % 4);
    const raw = atob((vapidKey + pad).replace(/-/g, '+').replace(/_/g, '/'));
    const key = Uint8Array.from(raw, (c) => c.charCodeAt(0));
    let sub = await reg.pushManager.getSubscription();
    if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
    return JSON.stringify(sub.toJSON());
  },
};
