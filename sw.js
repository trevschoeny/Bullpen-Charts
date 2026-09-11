/* Bullpen Charts service worker.
   The whole app is one HTML file, so caching is simple: keep the shell, serve
   it first, and refresh it in the background when there is a connection.
   CACHE is stamped with a content hash at build time — a new build means a new
   cache name, which is what makes updates actually reach an installed app. */
const CACHE = 'bullpen-charts-d14b50a4f5ae';
const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-180.png',
  './config.js'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => c.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k.startsWith('bullpen-charts-') && k !== CACHE)
            .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   // fonts, Supabase, the CDN: straight to network

  // config.js decides which backend the app talks to. Always take the network
  // copy when there is one, so changing backends is never stuck behind a cache.
  if (url.pathname.endsWith('/config.js')) {
    e.respondWith(fetch(req).catch(() => caches.match(req)));
    return;
  }

  // Navigations: cache first so the app opens instantly and offline, with a
  // background refresh so the next open has the newest build.
  if (req.mode === 'navigate') {
    e.respondWith(
      caches.match('./index.html').then((hit) => {
        const net = fetch(req)
          .then((res) => {
            if (res && res.ok) {
              const copy = res.clone();
              caches.open(CACHE).then((c) => c.put('./index.html', copy));
            }
            return res;
          })
          .catch(() => hit);
        return hit || net;
      })
    );
    return;
  }

  e.respondWith(
    caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res && res.ok && res.type === 'basic') {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
      }
      return res;
    }).catch(() => hit))
  );
});
