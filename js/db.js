const KervanDB = (() => {
  const DB_NAME = 'kervan-mal-kabul';
  const DB_VERSION = 1;
  let dbPromise;

  function open() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains('products')) {
          const s = db.createObjectStore('products', { keyPath: 'barcode' });
          s.createIndex('productName', 'productName', { unique: false });
          s.createIndex('manuallyAdded', 'manuallyAdded', { unique: false });
        }
        if (!db.objectStoreNames.contains('receipts')) {
          const s = db.createObjectStore('receipts', { keyPath: 'id' });
          s.createIndex('createdAt', 'createdAt', { unique: false });
          s.createIndex('status', 'status', { unique: false });
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
    return dbPromise;
  }

  async function store(name, mode='readonly') {
    const db = await open();
    return db.transaction(name, mode).objectStore(name);
  }
  function reqP(req){return new Promise((res,rej)=>{req.onsuccess=()=>res(req.result);req.onerror=()=>rej(req.error)})}
  async function get(name,key){return reqP((await store(name)).get(key))}
  async function getAll(name){return reqP((await store(name)).getAll())}
  async function put(name,value){return reqP((await store(name,'readwrite')).put(value))}
  async function del(name,key){return reqP((await store(name,'readwrite')).delete(key))}
  async function count(name){return reqP((await store(name)).count())}

  async function upsertProducts(rows){
    const db = await open();
    const tx = db.transaction('products','readwrite');
    const s = tx.objectStore('products');
    let inserted=0, updated=0, skipped=0;
    for(const row of rows){
      const barcode = String(row.barcode || '').trim();
      if(!barcode){skipped++;continue;}
      const existing = await reqP(s.get(barcode));
      const merged = {
        barcode,
        productCode: row.productCode || existing?.productCode || '',
        productName: row.productName || existing?.productName || `Ürün ${barcode}`,
        unit: row.unit || existing?.unit || '',
        caseQty: positive(row.caseQty) ?? existing?.caseQty ?? null,
        boxQty: positive(row.boxQty) ?? existing?.boxQty ?? null,
        purchasePrice: numberOrNull(row.purchasePrice) ?? existing?.purchasePrice ?? null,
        manuallyAdded: existing?.manuallyAdded || false,
        manuallyDefinedUnit: existing?.manuallyDefinedUnit || false,
        note: existing?.note || '',
        createdAt: existing?.createdAt || new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      await reqP(s.put(merged));
      existing ? updated++ : inserted++;
    }
    return new Promise((resolve,reject)=>{tx.oncomplete=()=>resolve({inserted,updated,skipped});tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error)});
  }
  function numberOrNull(v){if(v===null||v===undefined||v==='')return null;const n=Number(String(v).replace(',','.'));return Number.isFinite(n)?n:null}
  function positive(v){const n=numberOrNull(v);return n&&n>0?n:null}
  return {open,get,getAll,put,del,count,upsertProducts};
})();
