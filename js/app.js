const $ = (q) => document.querySelector(q);
const $$ = (q) => [...document.querySelectorAll(q)];
const state = { activeReceipt:null, currentProduct:null, stream:null, scanning:false, detector:null, frame:null, pendingRows:[] };

const COLS = {
  barcode:['barkod','barcode','barkod no','barkodno','ean','ean13','ean-13'],
  productCode:['ürün kodu','urun kodu','stok kodu','malzeme kodu','product code','code'],
  productName:['ürün adı','urun adi','ürün adi','stok adı','stok adi','malzeme adı','malzeme adi','product name','name'],
  unit:['birim','unit','ana birim'],
  caseQty:['koli içi','koli ici','koli içi adet','koli ici adet','koli miktarı','koli miktari','case qty'],
  boxQty:['kutu içi','kutu ici','kutu içi adet','kutu ici adet','box qty'],
  purchasePrice:['alış fiyatı','alis fiyati','alış','alis','purchase price','fiyat']
};

function normalizeHeader(v=''){return String(v).trim().toLocaleLowerCase('tr-TR').replace(/\s+/g,' ')}
function findField(obj, aliases){const keys=Object.keys(obj);for(const k of keys){if(aliases.includes(normalizeHeader(k))) return obj[k]}return ''}
function normUnit(v=''){const s=normalizeHeader(v).replace(/ı/g,'i'); if(s.includes('koli')) return 'KOLI'; if(s.includes('kutu')) return 'KUTU'; if(s.includes('adet')||s==='ad') return 'ADET'; return ''}
function mapProduct(row){return {barcode:String(findField(row,COLS.barcode)??'').replace(/\.0$/,'').trim(),productCode:String(findField(row,COLS.productCode)??'').trim(),productName:String(findField(row,COLS.productName)??'').trim(),unit:normUnit(findField(row,COLS.unit)),caseQty:findField(row,COLS.caseQty),boxQty:findField(row,COLS.boxQty),purchasePrice:findField(row,COLS.purchasePrice)}}

function toast(msg){const t=$('#toast');t.textContent=msg;t.classList.add('show');clearTimeout(t._timer);t._timer=setTimeout(()=>t.classList.remove('show'),2200)}
function showView(id){$$('.view').forEach(v=>v.classList.toggle('active',v.id===id)); if(id==='homeView')refreshDashboard(); if(id==='historyView')renderHistory(); if(id==='unknownView')renderUnknown(); window.scrollTo({top:0,behavior:'smooth'})}
$$('[data-view]').forEach(b=>b.addEventListener('click',()=>showView(b.dataset.view)));
$$('.back').forEach(b=>b.addEventListener('click',async()=>{if(b.dataset.special==='scanner'){await stopCamera();showView('homeView')}else showView('homeView')}));

async function refreshDashboard(){
  const products=await KervanDB.getAll('products'); const receipts=await KervanDB.getAll('receipts');
  $('#productCount').textContent=products.length; $('#receiptCount').textContent=receipts.filter(r=>r.status==='COMPLETED').length; $('#unknownCount').textContent=products.filter(p=>p.manuallyAdded).length;
}
function setOnline(){const on=navigator.onLine;$('#onlineStatus').textContent=on?'Çevrimiçi':'Offline';$('#onlineStatus').style.background=on?'rgba(255,255,255,.12)':'rgba(245,130,32,.35)'}
window.addEventListener('online',setOnline);window.addEventListener('offline',setOnline);setOnline();

$('#receiptDate').value = new Date().toISOString().slice(0,10);
$('#receiptForm').addEventListener('submit',async e=>{
  e.preventDefault();
  const receipt={id:crypto.randomUUID(),supplier:$('#supplier').value.trim(),invoiceNo:$('#invoiceNo').value.trim(),receiptDate:$('#receiptDate').value,employee:$('#employee').value.trim(),description:$('#description').value.trim(),status:'DRAFT',lines:[],createdAt:new Date().toISOString(),updatedAt:new Date().toISOString()};
  await KervanDB.put('receipts',receipt); state.activeReceipt=receipt; $('#scannerReceiptLabel').textContent=[receipt.supplier,receipt.invoiceNo].filter(Boolean).join(' · ')||'Aktif mal kabul'; renderLines(); showView('scannerView');
});

$('#chooseFileBtn').addEventListener('click',()=>$('#productFile').click());
$('#productFile').addEventListener('change',async e=>{
  const f=e.target.files?.[0]; if(!f)return; $('#fileName').textContent=f.name;
  try{
    let rows=[];
    if(f.name.toLowerCase().endsWith('.csv')){const text=await f.text();rows=parseCsv(text)}
    else {if(typeof XLSX==='undefined') throw new Error('Excel okuyucu yüklenemedi'); const buf=await f.arrayBuffer();const wb=XLSX.read(buf,{type:'array'});rows=XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]],{defval:''});}
    state.pendingRows=rows.map(mapProduct).filter(r=>r.barcode);
    $('#importPreview').innerHTML=`<b>${state.pendingRows.length}</b> barkod bulundu.<br><small>İlk ürün: ${escapeHtml(state.pendingRows[0]?.productName||'-')}</small>`;
    $('#importPreview').classList.remove('hidden');$('#importProductsBtn').classList.remove('hidden');
  }catch(err){toast('Dosya okunamadı: '+err.message)}
});
function parseCsv(text){const lines=text.replace(/^\uFEFF/,'').split(/\r?\n/).filter(Boolean);if(!lines.length)return[];const sep=(lines[0].match(/;/g)||[]).length>(lines[0].match(/,/g)||[]).length?';':',';const parse=l=>{const out=[];let cur='',q=false;for(let i=0;i<l.length;i++){const c=l[i];if(c==='"'){if(q&&l[i+1]==='"'){cur+='"';i++;}else q=!q;}else if(c===sep&&!q){out.push(cur);cur='';}else cur+=c;}out.push(cur);return out};const heads=parse(lines[0]);return lines.slice(1).map(l=>{const vals=parse(l),o={};heads.forEach((h,i)=>o[h]=vals[i]??'');return o})}
$('#importProductsBtn').addEventListener('click',async()=>{if(!state.pendingRows.length)return;const r=await KervanDB.upsertProducts(state.pendingRows);toast(`${r.inserted} yeni, ${r.updated} güncellendi`);state.pendingRows=[];$('#importProductsBtn').classList.add('hidden');refreshDashboard()});

$('#manualScanBtn').addEventListener('click',()=>handleBarcode($('#manualBarcode').value));
$('#manualBarcode').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();handleBarcode(e.target.value)}});
$('#cameraToggle').addEventListener('click',()=>state.stream?stopCamera():startCamera());

async function startCamera(){
  try{
    if(!('BarcodeDetector' in window)) throw new Error('Bu tarayıcı kamera barkod algılamayı desteklemiyor. Barkodu elle girebilirsiniz.');
    const formats=await BarcodeDetector.getSupportedFormats(); const wanted=['ean_13','ean_8','upc_a','upc_e','code_128','code_39'].filter(f=>formats.includes(f)); state.detector=new BarcodeDetector({formats:wanted.length?wanted:formats});
    state.stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'},width:{ideal:1280},height:{ideal:720}},audio:false});$('#camera').srcObject=state.stream;await $('#camera').play();$('#cameraToggle').textContent='Kamerayı Kapat';$('#cameraMessage').textContent='Barkodu çerçevenin içine getirin';state.scanning=true;scanLoop();
  }catch(err){$('#cameraMessage').textContent=err.message;toast(err.message)}
}
async function stopCamera(){state.scanning=false;cancelAnimationFrame(state.frame);if(state.stream){state.stream.getTracks().forEach(t=>t.stop());state.stream=null}$('#camera').srcObject=null;$('#cameraToggle').textContent='Kamerayı Aç'}
async function scanLoop(){if(!state.scanning||!state.detector)return;try{const codes=await state.detector.detect($('#camera'));if(codes.length){state.scanning=false;await handleBarcode(codes[0].rawValue);return}}catch{}state.frame=requestAnimationFrame(scanLoop)}
function resumeScanner(){if(state.stream){state.scanning=true;scanLoop()}}

async function handleBarcode(raw){const barcode=String(raw||'').trim();if(!barcode){toast('Barkod girin');return}$('#manualBarcode').value='';const p=await KervanDB.get('products',barcode);if(!p){$('#unknownBarcode').textContent=barcode;$('#unknownDialog').dataset.barcode=barcode;$('#uName').value='';$('#uCode').value='';$('#uUnit').value='ADET';$('#uConversion').value='';toggleUnknownConversion();$('#unknownDialog').showModal();return}openQuantity(p)}
function openQuantity(p){state.currentProduct=p;$('#qProductName').textContent=p.productName;$('#qProductMeta').innerHTML=`Kod: <b>${escapeHtml(p.productCode||'-')}</b><br>Barkod: <b>${escapeHtml(p.barcode)}</b>${p.purchasePrice!=null?`<br>Alış: <b>${p.purchasePrice}</b>`:''}`;$('#qUnit').value=p.unit||'ADET';$('#qQuantity').value='';$('#qConversion').value='';updateConversionUI();updateCalc();$('#quantityDialog').showModal();setTimeout(()=>$('#qQuantity').focus(),100)}
function getConversion(p,unit){if(unit==='ADET')return 1;if(unit==='KOLI')return Number(p.caseQty)||null;if(unit==='KUTU')return Number(p.boxQty)||null;return 1}
function updateConversionUI(){const unit=$('#qUnit').value;const existing=getConversion(state.currentProduct||{},unit);const needs=unit!=='ADET'&&!existing;$('#conversionWrap').classList.toggle('hidden',!needs);$('#conversionUnitText').textContent=unit==='KOLI'?'Koli':'Kutu';if(existing)$('#qConversion').value=existing;updateCalc()}
function updateCalc(){const unit=$('#qUnit').value;const q=Number($('#qQuantity').value)||0;const conv=getConversion(state.currentProduct||{},unit)||Number($('#qConversion').value)||0;$('#calcPreview').textContent=`${q||0} ${unit==='KOLI'?'Koli':unit==='KUTU'?'Kutu':'Adet'} × ${unit==='ADET'?1:conv||0} = ${formatNumber(q*(unit==='ADET'?1:conv))} Adet`}
$('#qUnit').addEventListener('change',updateConversionUI);$('#qQuantity').addEventListener('input',updateCalc);$('#qConversion').addEventListener('input',updateCalc);
$('#quantityDialog').addEventListener('close',()=>resumeScanner());
$('#unknownDialog').addEventListener('close',()=>resumeScanner());
$('#saveQuantityBtn').addEventListener('click',async()=>{
  const p=state.currentProduct, unit=$('#qUnit').value, qty=Number($('#qQuantity').value), manualConv=Number($('#qConversion').value);let conv=getConversion(p,unit);if(unit!=='ADET'&&!conv)conv=manualConv;if(!qty||qty<=0){toast('Miktar girin');return}if(!conv||conv<=0){toast('Koli/kutu içi adet girin');return}
  if(unit==='KOLI'&&!p.caseQty){p.caseQty=conv;p.unit=p.unit||unit;p.manuallyDefinedUnit=true;await KervanDB.put('products',p)}if(unit==='KUTU'&&!p.boxQty){p.boxQty=conv;p.unit=p.unit||unit;p.manuallyDefinedUnit=true;await KervanDB.put('products',p)}if(!p.unit){p.unit=unit;p.manuallyDefinedUnit=true;await KervanDB.put('products',p)}
  await addLine(p,unit,qty,conv);$('#quantityDialog').close();toast('Ürün eklendi');
});
async function addLine(p,unit,qty,conv){if(!state.activeReceipt)return;const existing=state.activeReceipt.lines.find(l=>l.barcode===p.barcode&&l.unit===unit&&l.conversion===conv);if(existing){existing.quantity+=qty;existing.totalUnits=existing.quantity*conv}else{state.activeReceipt.lines.push({id:crypto.randomUUID(),barcode:p.barcode,productCode:p.productCode,productName:p.productName,quantity:qty,unit,conversion:conv,totalUnits:qty*conv,purchasePrice:p.purchasePrice??null})}state.activeReceipt.updatedAt=new Date().toISOString();await KervanDB.put('receipts',state.activeReceipt);renderLines()}
function renderLines(){const lines=state.activeReceipt?.lines||[];$('#receiptLines').innerHTML=lines.slice().reverse().map(l=>`<div class="line-card"><div><h4>${escapeHtml(l.productName)}</h4><p>${escapeHtml(l.barcode)} · ${formatNumber(l.quantity)} ${labelUnit(l.unit)} × ${formatNumber(l.conversion)}</p></div><div class="line-total">${formatNumber(l.totalUnits)} Adet</div></div>`).join('');$('#lineCount').textContent=`${lines.length} Kalem`;$('#unitCount').textContent=`${formatNumber(lines.reduce((s,l)=>s+l.totalUnits,0))} Toplam Adet`}
$('#completeReceiptBtn').addEventListener('click',async()=>{if(!state.activeReceipt)return;if(!state.activeReceipt.lines.length){toast('En az bir ürün ekleyin');return}if(!confirm('Bu mal kabulünü tamamlamak istiyor musunuz?'))return;state.activeReceipt.status='COMPLETED';state.activeReceipt.completedAt=new Date().toISOString();state.activeReceipt.updatedAt=state.activeReceipt.completedAt;await KervanDB.put('receipts',state.activeReceipt);await stopCamera();toast('Mal kabul tamamlandı');state.activeReceipt=null;showView('historyView')});

function toggleUnknownConversion(){const u=$('#uUnit').value;$('#uConversionWrap').classList.toggle('hidden',u==='ADET')}
$('#uUnit').addEventListener('change',toggleUnknownConversion);
$('#saveUnknownBtn').addEventListener('click',async()=>{const barcode=$('#unknownDialog').dataset.barcode,name=$('#uName').value.trim(),unit=$('#uUnit').value,conv=Number($('#uConversion').value);if(!name){toast('Ürün adı girin');return}if(unit!=='ADET'&&(!conv||conv<=0)){toast('Koli/kutu içi adet girin');return}const p={barcode,productCode:$('#uCode').value.trim(),productName:name,unit,caseQty:unit==='KOLI'?conv:null,boxQty:unit==='KUTU'?conv:null,purchasePrice:null,manuallyAdded:true,manuallyDefinedUnit:true,note:$('#uNote').value.trim(),createdAt:new Date().toISOString(),updatedAt:new Date().toISOString()};await KervanDB.put('products',p);$('#unknownDialog').close();toast('Yeni ürün kaydedildi');openQuantity(p);refreshDashboard()});

async function renderHistory(){const rows=(await KervanDB.getAll('receipts')).filter(r=>r.status==='COMPLETED').sort((a,b)=>String(b.completedAt||b.createdAt).localeCompare(String(a.completedAt||a.createdAt)));$('#historyList').innerHTML=rows.length?rows.map(r=>`<div class="record-card"><div class="top"><h4>${escapeHtml(r.supplier||'Tedarikçi yok')}</h4><b>${formatDate(r.receiptDate)}</b></div><p>${escapeHtml(r.invoiceNo||'Fatura/irsaliye no yok')} · ${escapeHtml(r.employee||'-')}</p><div class="stats"><span>${r.lines.length} Kalem</span><span>${formatNumber(r.lines.reduce((s,l)=>s+l.totalUnits,0))} Adet</span></div></div>`).join(''):'<div class="info-card">Henüz tamamlanmış mal kabul yok.</div>'}
async function renderUnknown(){const rows=(await KervanDB.getAll('products')).filter(p=>p.manuallyAdded).sort((a,b)=>String(b.createdAt).localeCompare(String(a.createdAt)));$('#unknownList').innerHTML=rows.length?rows.map(p=>`<div class="record-card"><div class="top"><h4>${escapeHtml(p.productName)}</h4><b>${labelUnit(p.unit)}</b></div><p>${escapeHtml(p.barcode)}${p.productCode?' · '+escapeHtml(p.productCode):''}</p><div class="stats"><span>${p.unit==='KOLI'?(p.caseQty||'-')+' adet/koli':p.unit==='KUTU'?(p.boxQty||'-')+' adet/kutu':'Adet'}</span></div></div>`).join(''):'<div class="info-card">Sonradan eklenen ürün yok.</div>'}
function escapeHtml(s=''){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function formatNumber(n){return new Intl.NumberFormat('tr-TR',{maximumFractionDigits:2}).format(Number(n)||0)}
function labelUnit(u){return u==='KOLI'?'Koli':u==='KUTU'?'Kutu':'Adet'}
function formatDate(s){if(!s)return'-';const [y,m,d]=s.split('-');return `${d}.${m}.${y}`}

let deferredPrompt=null;window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();deferredPrompt=e;$('#installBtn').classList.remove('hidden')});$('#installBtn').addEventListener('click',async()=>{if(!deferredPrompt)return;deferredPrompt.prompt();await deferredPrompt.userChoice;deferredPrompt=null;$('#installBtn').classList.add('hidden')});
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
KervanDB.open().then(refreshDashboard).catch(()=>toast('Yerel veritabanı açılamadı'));
