const KCache=(()=>{const NAME='kervan-mal-kabul-web';const VERSION=5;let p;
const req=r=>new Promise((res,rej)=>{r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)});
function open(){if(p)return p;p=new Promise((res,rej)=>{const r=indexedDB.open(NAME,VERSION);r.onupgradeneeded=()=>{const db=r.result;
function mk(n,key='id'){if(!db.objectStoreNames.contains(n))return db.createObjectStore(n,{keyPath:key});return r.transaction.objectStore(n)}
let s=mk('products','barcode');if(!s.indexNames.contains('productName'))s.createIndex('productName','productName');if(!s.indexNames.contains('manuallyAdded'))s.createIndex('manuallyAdded','manuallyAdded');
s=mk('receipts');if(!s.indexNames.contains('createdAt'))s.createIndex('createdAt','createdAt');if(!s.indexNames.contains('status'))s.createIndex('status','status');
s=mk('receiptLines');if(!s.indexNames.contains('receiptId'))s.createIndex('receiptId','receiptId');if(!s.indexNames.contains('barcode'))s.createIndex('barcode','barcode');
s=mk('suppliers');if(!s.indexNames.contains('name'))s.createIndex('name','name');
s=mk('users');if(!s.indexNames.contains('username'))s.createIndex('username','username',{unique:true});
s=mk('auditLogs');if(!s.indexNames.contains('createdAt'))s.createIndex('createdAt','createdAt');
mk('settings','key');mk('syncQueue');mk('conflicts');};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)});return p}
async function st(n,m='readonly'){const db=await open();return db.transaction(n,m).objectStore(n)}
async function get(n,k){return req((await st(n)).get(k))}async function all(n){return req((await st(n)).getAll())}async function put(n,v){return req((await st(n,'readwrite')).put(v))}async function add(n,v){return req((await st(n,'readwrite')).add(v))}async function del(n,k){return req((await st(n,'readwrite')).delete(k))}
async function clear(n){return req((await st(n,'readwrite')).clear())}async function indexAll(n,i,k){return req((await st(n)).index(i).getAll(k))}
async function setting(k,d=null){const v=await get('settings',k);return v?.value??d}async function setSetting(k,v){return put('settings',{key:k,value:v,updatedAt:new Date().toISOString()})}
async function log(user,action,entityType,entityId,description,oldValue=null,newValue=null){return put('auditLogs',{id:crypto.randomUUID(),userId:user?.id||null,userName:user?.name||'Sistem',action,entityType,entityId,description,oldValue,newValue,createdAt:new Date().toISOString()})}
async function atomic(name,row,operation){const db=await open();return new Promise((resolve,reject)=>{const tx=db.transaction([name,'syncQueue'],'readwrite');tx.objectStore(name).put(row);tx.objectStore('syncQueue').put(operation);tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});}
return{open,get,all,put,add,del,clear,indexAll,setting,setSetting,log,atomic}})();
