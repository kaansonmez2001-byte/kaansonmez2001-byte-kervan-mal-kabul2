const CloudSync=(()=>{let client=null;
async function connect(){client=KStaff.connect();if(!await KStaff.current(true))throw new Error('Merkezi hesaba giriş yapın.');return client}
function safe(v){return v===undefined?null:v}
function newer(remote,local){if(!local)return true;const r=new Date(remote?.updated_at||remote?.created_at||0).getTime(),l=new Date(local?.updatedAt||local?.createdAt||0).getTime();return r>=l}
async function pull(user){
 const c=client;
 const [{data:products,error:pe},{data:suppliers,error:se},{data:receipts,error:re},{data:lines,error:le}]=await Promise.all([
  c.from('products').select('*'),c.from('suppliers').select('*'),c.from('receipts').select('*'),c.from('receipt_lines').select('*')
 ]);if(pe)throw pe;if(se)throw se;if(re)throw re;if(le)throw le;
 for(const p of products||[]){const local=await KDB.get('products',p.barcode);if(newer(p,local))await KDB.put('products',{barcode:p.barcode,productCode:p.product_code||'',productName:p.product_name,unit:p.unit||'',caseQuantity:p.case_quantity,boxQuantity:p.box_quantity,purchasePrice:p.purchase_price,manuallyAdded:!!p.manually_added,manuallyDefinedUnit:!!p.manually_defined_unit,notes:p.notes||'',createdAt:p.created_at,updatedAt:p.updated_at});}
 for(const s of suppliers||[]){const id=s.local_id||s.id,local=await KDB.get('suppliers',id);if(newer(s,local))await KDB.put('suppliers',{id,name:s.name,phone:s.phone||'',taxNumber:s.tax_number||'',notes:s.notes||'',createdAt:s.created_at,updatedAt:s.updated_at});}
 const receiptMap=new Map();
 for(const r of receipts||[]){const id=r.local_id||r.id;receiptMap.set(r.id,id);const local=await KDB.get('receipts',id);if(newer(r,local))await KDB.put('receipts',{id,supplierId:r.supplier_id||null,supplierName:r.supplier_name||'',invoiceNumber:r.invoice_number||'',receiptDate:String(r.receipt_date||'').slice(0,10),employeeId:r.employee_id||null,employeeName:r.employee_name||'',description:r.description||'',status:String(r.status||'draft').toUpperCase(),lineCount:r.total_lines||0,totalUnits:r.total_units||0,createdAt:r.created_at,updatedAt:r.updated_at,completedAt:r.status==='completed'?r.updated_at:null});}
 for(const l of lines||[]){const id=l.local_id||l.id,receiptId=receiptMap.get(l.receipt_id);if(!receiptId)continue;const local=await KDB.get('receiptLines',id);if(newer(l,local))await KDB.put('receiptLines',{id,receiptId,barcode:l.barcode,productCode:l.product_code||'',productName:l.product_name,quantity:Number(l.entered_quantity||0),unit:l.entered_unit,conversion:Number(l.conversion_quantity||1),totalUnits:Number(l.total_units||0),purchasePrice:l.purchase_price,createdAt:l.created_at,updatedAt:l.updated_at});}
 if(user.role==='ADMIN'){
  const {data:logs,error}=await c.from('audit_logs').select('*').order('created_at',{ascending:false}).limit(1000);if(error)throw error;
  for(const l of logs||[]){const id=l.local_id||String(l.id),local=await KDB.get('auditLogs',id);if(!local)await KDB.put('auditLogs',{id,userId:l.user_id||null,userName:l.user_name||'Sistem',action:l.action,entityType:l.entity_type,entityId:l.entity_id,oldValue:l.old_value,newValue:l.new_value,description:l.description||'',createdAt:l.created_at});}
 }
}
async function pushTable(table,rows,map){if(!rows.length)return;const payload=rows.map(map);const{error}=await client.from(table).upsert(payload,{onConflict:'local_id'});if(error)throw error}
async function push(user){
 const products=await KDB.all('products'),receipts=await KDB.all('receipts'),lines=await KDB.all('receiptLines'),suppliers=await KDB.all('suppliers'),logs=await KDB.all('auditLogs');
 if(user.role==='ADMIN')await pushTable('products',products,p=>({local_id:p.barcode,barcode:p.barcode,product_code:safe(p.productCode),product_name:p.productName,unit:p.unit||null,case_quantity:safe(p.caseQuantity),box_quantity:safe(p.boxQuantity),purchase_price:safe(p.purchasePrice),manually_added:!!p.manuallyAdded,manually_defined_unit:!!p.manuallyDefinedUnit,notes:safe(p.notes),created_at:p.createdAt||new Date().toISOString(),updated_at:p.updatedAt||new Date().toISOString()}));
 if(user.role==='ADMIN')await pushTable('suppliers',suppliers,s=>({local_id:s.id,name:s.name,phone:safe(s.phone),tax_number:safe(s.taxNumber),notes:safe(s.notes),created_at:s.createdAt||new Date().toISOString(),updated_at:s.updatedAt||new Date().toISOString()}));
 for(const r of receipts){
  if(user.role!=='ADMIN' && r.employeeId!==user.id)continue;
  const {data:remote,error:readError}=await client.from('receipts').select('id,status,updated_at').eq('local_id',r.id).maybeSingle();if(readError)throw readError;
  if(remote && new Date(remote.updated_at)>new Date(r.updatedAt||r.createdAt))continue;
  if(remote?.status==='completed' && user.role!=='ADMIN')continue;
  const payload={local_id:r.id,supplier_name:safe(r.supplierName),invoice_number:safe(r.invoiceNumber),receipt_date:r.receiptDate,employee_id:r.employeeId||(user.role==='PERSONNEL'?user.id:null),employee_name:safe(r.employeeName),description:safe(r.description),status:'draft',total_lines:r.lineCount||0,total_units:r.totalUnits||0,created_at:r.createdAt,updated_at:r.updatedAt||r.createdAt};
  const {data:saved,error:saveError}=await client.from('receipts').upsert(payload,{onConflict:'local_id'}).select('id').single();if(saveError)throw saveError;
  await pushTable('receipt_lines',lines.filter(l=>l.receiptId===r.id),l=>({local_id:l.id,receipt_id:saved.id,barcode:l.barcode,product_code:safe(l.productCode),product_name:l.productName,entered_quantity:l.quantity,entered_unit:l.unit,conversion_quantity:l.conversion,total_units:l.totalUnits,purchase_price:safe(l.purchasePrice),created_at:l.createdAt,updated_at:l.updatedAt||l.createdAt}));
  if(r.status==='COMPLETED'){const {error}=await client.from('receipts').update({status:'completed',updated_at:r.updatedAt||new Date().toISOString()}).eq('id',saved.id);if(error)throw error;}
 }
 if(user.role==='ADMIN')await pushTable('audit_logs',logs,l=>({local_id:l.id,user_id:safe(l.userId),user_name:l.userName,action:l.action,entity_type:l.entityType,entity_id:safe(l.entityId),description:l.description,old_value:safe(l.oldValue),new_value:safe(l.newValue),created_at:l.createdAt}));
}
async function sync(user,quiet=false){await connect();await pull(user);await push(user);await pull(user);await KDB.setSetting('lastSyncAt',new Date().toISOString());if(!quiet)await KDB.log(user,'SYNC','system','cloud','Bulut senkronizasyonu tamamlandı.');return true}
return{sync,connect,pull}})();
