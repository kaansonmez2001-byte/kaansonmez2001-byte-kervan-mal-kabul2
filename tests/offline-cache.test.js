const fs=require('fs'),vm=require('vm'),assert=require('assert');
const stores=Object.fromEntries(['suppliers','products','receipts','receiptLines','auditLogs','syncQueue','conflicts','settings'].map(x=>[x,new Map()]));
const KCache={
 open:async()=>{},get:async(n,k)=>stores[n].get(k),all:async n=>[...stores[n].values()],put:async(n,v)=>stores[n].set(n==='products'?v.barcode:v.id??v.key,v),del:async(n,k)=>stores[n].delete(k),clear:async n=>stores[n].clear(),
 setting:async(k,d=null)=>stores.settings.get(k)?.value??d,setSetting:async(k,v)=>stores.settings.set(k,{key:k,value:v}),
 atomic:async(n,row,op)=>{stores[n].set(n==='products'?row.barcode:row.id,row);stores.syncQueue.set(op.id,op)}
};
let isOnline=false,rpcCalls=[];
const cloud={rpc:async(_fn,args)=>{rpcCalls.push(args);return{data:{status:'ok',row:{id:'cloud-id',local_id:args.p_key,name:args.p_data.name,phone:null,tax_number:null,notes:null,created_at:'2026-09-10T10:00:00Z',updated_at:'2026-09-10T10:00:01Z',deleted_at:null,last_mutation:args.p_mutation}},error:null}},from:()=>({select:()=>({order:()=>({range:async()=>({data:[],error:null})})})})};
const context={KCache,KStaff:{connect:()=>cloud},navigator:{get onLine(){return isOnline}},window:{dispatchEvent:()=>{}},CustomEvent:function(){},crypto:require('crypto').webcrypto,console,setTimeout,clearTimeout};
vm.createContext(context);vm.runInContext(fs.readFileSync('js/db.js','utf8')+';this.KDB=KDB;',context);
(async()=>{
 await KCache.setSetting('centralDataMigrationV1',true);await context.KDB.initialize({id:'admin',name:'Admin',role:'ADMIN'});
 await context.KDB.put('suppliers',{id:'offline-1',name:'Offline Supplier',createdAt:new Date().toISOString(),updatedAt:new Date().toISOString()});
 assert.equal(stores.syncQueue.size,1);assert.equal((await context.KDB.get('suppliers','offline-1')).name,'Offline Supplier');assert.equal(rpcCalls.length,0);
 isOnline=true;await context.KDB.flush();assert.equal(stores.syncQueue.size,0);assert.equal(rpcCalls.length,1);assert.equal(stores.suppliers.get('offline-1')._synced,true);
 console.log('PASS offline cache survives and flushes to cloud');
})().catch(e=>{console.error(e);process.exit(1)});
