// Notifications for the Flutter app (lib/data/web_push_web.dart calls these).
// On iPhone they only work in the app added to the Home Screen (iOS 16.4+),
// and everywhere they need the https address.
(function () {
  function keyBytes(base64url) {
    const padding = '='.repeat((4 - (base64url.length % 4)) % 4);
    const raw = atob((base64url + padding).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  async function registration() {
    return navigator.serviceWorker.getRegistration();
  }

  window.kognitivPush = {
    secure: () => window.isSecureContext === true,
    supported: () =>
      'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window,
    ios: () => /iPhone|iPad|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1),
    standalone: () =>
      window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true,
    permission: () => ('Notification' in window ? Notification.permission : 'unsupported'),
    timeZone: () => {
      try { return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'; } catch (_) { return 'UTC'; }
    },

    // Asks for permission (call straight from a tap: iOS insists), then
    // subscribes. Resolves to the subscription as JSON text.
    subscribe: async (serverKey) => {
      const permission = await Notification.requestPermission();
      // 'denied' or 'default' (the prompt was dismissed).
      if (permission !== 'granted') throw new Error('permission:' + permission);
      const reg = await navigator.serviceWorker.ready;
      let sub = await reg.pushManager.getSubscription();
      if (sub) {
        // Made with another server key: start again.
        const old = sub.options && sub.options.applicationServerKey;
        const same = old && btoa(String.fromCharCode(...new Uint8Array(old)))
          .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '') === serverKey;
        if (!same) { await sub.unsubscribe(); sub = null; }
      }
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: keyBytes(serverKey),
        });
      }
      return JSON.stringify(sub.toJSON());
    },

    // This device's subscription as JSON text, or '' if there is none.
    current: async () => {
      if (!window.kognitivPush.supported()) return '';
      const reg = await registration();
      const sub = reg && (await reg.pushManager.getSubscription());
      return sub ? JSON.stringify(sub.toJSON()) : '';
    },

    // Unsubscribes this device. Resolves to the endpoint it had, or ''.
    unsubscribe: async () => {
      const reg = await registration();
      const sub = reg && (await reg.pushManager.getSubscription());
      if (!sub) return '';
      const endpoint = sub.endpoint;
      await sub.unsubscribe();
      return endpoint;
    },
  };

  if ('serviceWorker' in navigator && window.isSecureContext) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();
