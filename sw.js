const CACHE='kervan-mal-kabul-v11-mobile-bulk-sync';
const LOCAL=['/','/index.html','/assets/app.css','/js/cache.js','/js/db.js','/js/staff.js','/js/sync.js','/js/app.js','/manifest.webmanifest'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(LOCAL)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{
 if(e.request.method!=='GET'||new URL(e.request.url).origin!==self.location.origin)return;
 const u=new URL(e.request.url),fresh=u.pathname==='/'||u.pathname.endsWith('.html')||u.pathname.endsWith('.js')||u.pathname.endsWith('.css')||u.pathname==='/sw.js';
 if(fresh){
  e.respondWith(fetch(e.request,{cache:'no-store'}).then(resp=>{const copy=resp.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));return resp}).catch(()=>caches.match(e.request).then(hit=>hit||(e.request.mode==='navigate'?caches.match('/index.html'):undefined))));
  return;
 }
 e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(resp=>{const copy=resp.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));return resp})));
});
