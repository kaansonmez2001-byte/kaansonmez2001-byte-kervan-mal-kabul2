// Supabase is authoritative; KCache is a durable projection and offline outbox.
const KDB=(()=>{
 const tables={suppliers:'suppliers',products:'products',receipts:'receipts',receiptLines:'receipt_lines',auditLogs:'audit_logs'};
 const fields={productCode:'product_code',productName:'product_name',caseQuantity:'case_quantity',boxQuantity:'box_quantity',purchasePrice:'purchase_price',manuallyAdded:'manually_added',manuallyDefinedUnit:'manually_defined_unit',taxNumber:'tax_number',supplierId:'supplier_id',supplierName:'supplier_name',invoiceNumber:'invoice_number',receiptDate:'receipt_date',employeeId:'employee_id',employeeName:'employee_name',lineCount:'total_lines',totalUnits:'total_units',receiptId:'receipt_id',quantity:'entered_quantity',conversion:'conversion_quantity',userId:'user_id',userName:'user_name',entityType:'entity_type',entityId:'entity_id',oldValue:'old_value',newValue:'new_value',createdAt:'created_at',updatedAt:'updated_at',deletedAt:'deleted_at'};
 let actor=null,flushing=null,serial=Promise.resolve(),order=Date.now()*1000;const pendingReads=new Map();
 const lock=fn=>{const p=serial.then(fn);serial=p.catch(()=>{});return p;};
 const keyOf=(name,row)=>name==='products'?row.barcode:row.id;
 const notify=()=>window.dispatchEvent(new CustomEvent('kervan:data'));
 const online=()=>navigator.onLine;
 const client=()=>KStaff.connect();
 function toCloud(name,row){const out={};for(const [k,v] of Object.entries(row)){if(k.startsWith('_')||['id','createdAt','updatedAt'].includes(k))continue;out[fields[k]||k]=v;}if(name==='receiptLines'){out.entered_unit=row.unit;delete out.unit;}if(name==='receipts'){out.status=row.status.toLowerCase();delete out.total_lines;delete out.total_units;}if(name==='products'&&!out.unit)out.unit=null;return out;}
 async function fromCloud(name,row){
  const out={};const reverse=Object.fromEntries(Object.entries(fields).map(([a,b])=>[b,a]));
  for(const [k,v] of Object.entries(row))out[reverse[k]||k]=v;
  out.id=row.local_id;out._cloudId=row.id;out._base=row.updated_at;out._synced=true;out._pending=false;
  if(name==='receipts'){out.status=row.status.toUpperCase();out.receiptDate=row.receipt_date.slice(0,10);if(row.supplier_id){const s=(await KCache.all('suppliers')).find(s=>s._cloudId===row.supplier_id);out.supplierId=s?.id||row.supplier_id;}}
  if(name==='receiptLines'){out.unit=row.entered_unit;const r=(await KCache.all('receipts')).find(r=>r._cloudId===row.receipt_id);out.receiptId=r?.id||row.receipt_id;}
  return out;
 }
 async function refresh(name){
  if(!tables[name]||!actor||!online())return;
  if(pendingReads.has(name))return pendingReads.get(name);
  const task=(async()=>{
   const rows=[];for(let start=0;;start+=500){const {data,error}=await client().from(tables[name]).select('*').order('local_id').range(start,start+499);if(error)throw error;rows.push(...data);if(data.length<500)break;}
   const existing=await KCache.all(name),oldByKey=new Map(existing.map(row=>[keyOf(name,row),row])),seen=new Set(),puts=[];
   for(const row of rows){const mapped=await fromCloud(name,row),key=keyOf(name,mapped);seen.add(key);if(!oldByKey.get(key)?._pending)puts.push(mapped);}
   const deletes=existing.filter(old=>old._synced&&!old._pending&&!seen.has(keyOf(name,old))).map(old=>keyOf(name,old));
   await KCache.reconcile(name,puts,deletes);
  })();pendingReads.set(name,task);try{await task;}finally{pendingReads.delete(name);}
 }
 async function all(name){if(name==='users')return KStaff.list();if(!tables[name])return KCache.all(name);await refresh(name);return (await KCache.all(name)).filter(r=>!r.deletedAt&&!r._rejected);}
 async function get(name,key){if(!tables[name])return KCache.get(name,key);await refresh(name);const r=await KCache.get(name,key);return r?.deletedAt||r?._rejected?undefined:r;}
 async function queue(name,value){
  if(!actor)throw new Error('Önce giriş yapın.');
  if(name==='suppliers'&&actor.role!=='ADMIN')throw new Error('Yönetici yetkisi gerekiyor.');
  const key=keyOf(name,value),old=await KCache.get(name,key);
  const ops=(await KCache.all('syncQueue')).filter(o=>o.actorId===actor.id&&o.name===name&&o.key===key);
  const previous=ops.sort((a,b)=>a.order-b.order).at(-1);
  const op={id:crypto.randomUUID(),name,key,actorId:actor.id,base:old?._base||null,after:previous?.id||null,data:value,order:++order};
  const optimistic={...value,_base:old?._base||null,_synced:old?._synced||false,_cloudId:old?._cloudId,_pending:true};
  await KCache.atomic(name,optimistic,op);return op;
 }
 async function put(name,value){if(!tables[name])return KCache.put(name,value);return lock(async()=>{const op=await queue(name,value);if(online()){await flush();const conflict=await KCache.get('conflicts',op.id);if(conflict)throw new Error(conflict.message);}notify();return keyOf(name,value);});}
 async function del(name,key){const r=await get(name,key);if(r)return put(name,{...r,deletedAt:new Date().toISOString()});}
 async function flush(){
  if(flushing)return flushing;if(!actor||!online())return;
  flushing=(async()=>{
   const ops=(await KCache.all('syncQueue')).filter(o=>o.actorId===actor.id).sort((a,b)=>a.order-b.order);
   for(const op of ops){
    if(op.after){if(await KCache.get('syncQueue',op.after))continue;if(await KCache.get('conflicts',op.after)){await block(op,null,'Önceki işlem çakıştı; değişiklik inceleme için korundu.');continue;}}
    const current=await KCache.get(op.name,op.key),base=op.after?(current?._base||null):op.base;
    const {data,error}=await client().rpc('apply_change',{p_table:tables[op.name],p_key:String(op.key),p_data:toCloud(op.name,op.data),p_base:base,p_mutation:op.id});
    if(error){if(!error.code||/fetch|network|Failed to fetch/i.test(error.message))throw error;await block(op,null,error.message);continue;}
    if(data.status==='conflict'){await block(op,data.row,'Kayıt başka cihazda değişti veya silindi. Merkezdeki sürüm korundu; değişikliğiniz inceleme listesine alındı.');continue;}
    const mapped=await fromCloud(op.name,data.row),remaining=ops.some(x=>x.name===op.name&&x.key===op.key&&x.order>op.order);
    await KCache.put(op.name,remaining?{...current,_base:mapped._base,_cloudId:mapped._cloudId,_synced:true}:mapped);
    await KCache.del('syncQueue',op.id);
   }
   await KCache.setSetting('lastSyncAt',new Date().toISOString());
  })();try{await flushing;}finally{flushing=null;notify();}
 }
 async function block(op,row,message){
  await KCache.put('conflicts',{...op,message,server:row,createdAt:new Date().toISOString()});await KCache.del('syncQueue',op.id);
  if(row)await KCache.put(op.name,await fromCloud(op.name,row));else{const old=await KCache.get(op.name,op.key);if(old)await KCache.put(op.name,{...old,_pending:false,_rejected:true});}
  window.dispatchEvent(new CustomEvent('kervan:conflict',{detail:message}));
 }
 async function repairLegacyProductConflicts(){
  if(!actor||!online())return;
  const conflicts=(await KCache.all('conflicts')).filter(c=>c.actorId===actor.id&&c.name==='products'&&/products_barcode_key|duplicate key/i.test(c.message||''));
  for(const conflict of conflicts){
   const barcode=String(conflict.data?.barcode||conflict.key||'');if(!barcode)continue;
   const {data,error}=await client().from('products').select('*').eq('barcode',barcode).maybeSingle();
   if(error||!data)continue;
   await KCache.put('products',await fromCloud('products',data));
   await KCache.del('conflicts',conflict.id);
  }
 }
 async function sync(){await repairLegacyProductConflicts();await flush();for(const name of Object.keys(tables))await refresh(name);notify();}
 async function initialize(user){
  actor=user;
  const owner=await KCache.setting('cacheOwner');if(owner&&owner!==user.id){for(const name of Object.keys(tables))await KCache.clear(name);}
  await KCache.setSetting('cacheOwner',user.id);
  if(online()&&!await KCache.setting('centralDataMigrationV1')){
   for(const name of Object.keys(tables))for(const row of await KCache.all(name)){
    if(row._synced||row._pending)continue;
    if(user.role!=='ADMIN'&&['suppliers','products','auditLogs'].includes(name))continue;
    if(user.role!=='ADMIN'&&name==='receipts'&&row.employeeId!==user.id)continue;
    await queue(name,row);
   }
   await KCache.setSetting('centralDataMigrationV1',true);
  }
  await sync();
 }
 async function log(user,action,entityType,entityId,description,oldValue=null,newValue=null){return put('auditLogs',{id:crypto.randomUUID(),userId:user?.id,userName:user?.name,action,entityType,entityId,description,oldValue,newValue,createdAt:new Date().toISOString()});}
 async function conflicts(){return (await KCache.all('conflicts')).filter(c=>c.actorId===actor?.id);}
 return {open:KCache.open,setting:KCache.setting,setSetting:KCache.setSetting,all,get,put,add:put,del,indexAll:async(n,i,k)=>(await all(n)).filter(r=>r[i]===k),log,initialize,sync,refresh,flush,conflicts,fromCloud,toCloud};
})();
