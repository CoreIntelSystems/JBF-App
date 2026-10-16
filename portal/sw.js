// Keeps the app shell available offline. Member data is never cached here:
// it is fetched fresh, and the page keeps its own copy of the last statement.
const SHELL = 'jbf-shell-v3';
const FILES = ['./', 'index.html', 'app.js', 'manifest.webmanifest', 'logo.png',
  'icon-192.png', 'icon-512.png', 'apple-touch-icon.png', 'Inter-Regular.woff2', 'Inter-SemiBold.woff2'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(SHELL).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== SHELL).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  // Network first so updates arrive, falling back to the cached shell.
  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(SHELL).then((c) => c.put(req, copy));
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match('./'))),
  );
});
