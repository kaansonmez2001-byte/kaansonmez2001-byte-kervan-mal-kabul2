const CloudSync=(()=>{let client=null;async function connect(){client=KStaff.connect();if(!await KStaff.current())throw new Error('Merkezi hesaba giriş yapın.');return client}
function safe(v){return v===undefined?null:v}
async function pushTable(table,rows,map){if(!rows.length)return;const payload=rows.map(map);const{error}=await client.from(table).upsert(payload,{onConflict:'local_id'});if(error)throw error}
async function sync(user){await connect();const products=await KDB.all('products'),receipts=await KDB.all('receipts'),lines=await KDB.all('receiptLines'),suppliers=await KDB.all('suppliers'),logs=await KDB.all('auditLogs');
if(user.role==='ADMIN')await pushTable('products',products,p=>({local_id:p.barcode,barcode:p.barcode,product_code:safe(p.productCode),product_name:p.productName,unit:p.unit||null,case_quantity:safe(p.caseQuantity),box_quantity:safe(p.boxQuantity),purchase_price:safe(p.purchasePrice),manually_added:!!p.manuallyAdded,manually_defined_unit:!!p.manuallyDefinedUnit,notes:safe(p.notes),updated_at:p.updatedAt||new Date().toISOString()}));
if(user.role==='ADMIN')await pushTable('suppliers',suppliers,s=>({local_id:s.id,name:s.name,phone:safe(s.phone),tax_number:safe(s.taxNumber),notes:safe(s.notes),updated_at:s.updatedAt||new Date().toISOString()}));
for(const r of receipts){
 if(user.role!=='ADMIN' && r.employeeId!==user.id)continue;
 const {data:remote,error:readError}=await client.from('receipts').select('id,status,updated_at').eq('local_id',r.id).maybeSingle();if(readError)throw readError;
 if(remote && new Date(remote.updated_at)>=new Date(r.updatedAt||r.createdAt))continue;
 if(remote?.status==='completed' && user.role!=='ADMIN')continue;
 const payload={local_id:r.id,supplier_name:safe(r.supplierName),invoice_number:safe(r.invoiceNumber),receipt_date:r.receiptDate,employee_id:user.role==='ADMIN'?null:user.id,employee_name:safe(r.employeeName),description:safe(r.description),status:'draft',total_lines:r.lineCount||0,total_units:r.totalUnits||0,created_at:r.createdAt,updated_at:r.updatedAt||r.createdAt};
 const {data:saved,error:saveError}=await client.from('receipts').upsert(payload,{onConflict:'local_id'}).select('id').single();if(saveError)throw saveError;
 await pushTable('receipt_lines',lines.filter(l=>l.receiptId===r.id),l=>({local_id:l.id,receipt_id:saved.id,barcode:l.barcode,product_code:safe(l.productCode),product_name:l.productName,entered_quantity:l.quantity,entered_unit:l.unit,conversion_quantity:l.conversion,total_units:l.totalUnits,purchase_price:safe(l.purchasePrice),created_at:l.createdAt,updated_at:l.updatedAt||l.createdAt}));
 if(r.status==='COMPLETED'){const {error}=await client.from('receipts').update({status:'completed'}).eq('id',saved.id);if(error)throw error;}
}
if(user.role==='ADMIN')await pushTable('audit_logs',logs,l=>({local_id:l.id,user_name:l.userName,action:l.action,entity_type:l.entityType,entity_id:safe(l.entityId),description:l.description,old_value:safe(l.oldValue),new_value:safe(l.newValue),created_at:l.createdAt}));
await KDB.setSetting('lastSyncAt',new Date().toISOString());await KDB.log(user,'SYNC','system','cloud','Bulut senkronizasyonu tamamlandı.');return true}
return{sync,connect}})();
