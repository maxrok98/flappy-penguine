const CACHE = "penguine-v1";
const FILES = ["./", "index.html", "index.js", "index.wasm", "index.data", "odin.js", "manifest.json", "icon-192.png", "icon-512.png"];

self.addEventListener("install", e => {
	e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
	self.skipWaiting();
});

self.addEventListener("activate", e => {
	e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
	self.clients.claim();
});

// Network first, so a new deploy is picked up; falls back to cache when offline
self.addEventListener("fetch", e => {
	if (e.request.method !== "GET") return;
	e.respondWith(
		fetch(e.request)
			.then(res => {
				const copy = res.clone();
				caches.open(CACHE).then(c => c.put(e.request, copy));
				return res;
			})
			.catch(() => caches.match(e.request))
	);
});
