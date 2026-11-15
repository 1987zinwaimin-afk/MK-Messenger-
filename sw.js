const CACHE_NAME='mk-messenger-shell-v3';
const APP_SHELL=['/','/manifest.webmanifest','/icons/mk-messenger-192.png','/icons/mk-messenger-512.png'];
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE_NAME).then(cache=>cache.addAll(APP_SHELL)).catch(()=>{}));
  self.skipWaiting();
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE_NAME).map(key=>caches.delete(key)))));
  self.clients.claim();
});
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET'||new URL(request.url).origin!==self.location.origin)return;
  if(request.mode==='navigate'){
    event.respondWith(fetch(request).then(response=>{
      const copy=response.clone();
      if(response.ok)caches.open(CACHE_NAME).then(cache=>cache.put('/',copy));
      return response;
    }).catch(()=>caches.match('/')));
    return;
  }
  if(request.destination==='image'){
    event.respondWith(caches.match(request).then(cached=>cached||fetch(request)));
  }
});

self.addEventListener('push',event=>{
  let payload={};
  try{payload=event.data?event.data.json():{};}catch(_){
    payload={body:event.data?event.data.text():'You have a new message in MK Messenger.'};
  }
  const title=String(payload.title||'MK Messenger').slice(0,80);
  const body=String(payload.body||'You have a new message. Open MK Messenger to view it.').slice(0,180);
  const rawUrl=typeof payload.url==='string'?payload.url:'/';
  let target='/';
  try{
    const parsed=new URL(rawUrl,self.location.origin);
    if(parsed.origin===self.location.origin)target=parsed.pathname+parsed.search+parsed.hash;
  }catch(_){}
  event.waitUntil(self.registration.showNotification(title,{
    body,
    icon:'/icons/mk-messenger-192.png',
    badge:'/icons/mk-messenger-192.png',
    tag:typeof payload.tag==='string'?payload.tag:'mk-messenger-message',
    data:{url:target},
    renotify:true,
    requireInteraction:true,
    vibrate:[250,100,250,100,400]
  }));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const target=event.notification.data&&typeof event.notification.data.url==='string'?event.notification.data.url:'/';
  event.waitUntil((async()=>{
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of windows){
      if(new URL(client.url).origin===self.location.origin){
        if('navigate' in client)await client.navigate(target);
        return client.focus();
      }
    }
    return self.clients.openWindow(target);
  })());
});
