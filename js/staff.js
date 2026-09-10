const KStaff = (() => {
 const url='https://gibnvcducxqyrfvrtbub.supabase.co';
 const key='sb_publishable_nKHlFRkeAsq8tOvzv85lsw_BPWNS8jN';
 let client,lastAutoSync=0;
 const normalize=s=>String(s).trim().toLocaleLowerCase('tr-TR').replace(/\s+/g,' ');
 const emailFor=s=>Array.from(new TextEncoder().encode(normalize(s))).map(v=>v.toString(16).padStart(2,'0')).join('')+'@staff.kervan.invalid';
 const map=u=>({...u,createdAt:u.created_at,updatedAt:u.updated_at});
 const cacheUser=u=>{if(u)localStorage.setItem('kervanCentralUser',JSON.stringify(u));};
 const cachedUser=()=>{try{return JSON.parse(localStorage.getItem('kervanCentralUser')||'null')}catch{return null}};
 const cacheList=us=>localStorage.setItem('kervanCentralStaffList',JSON.stringify(us||[]));
 const cachedList=()=>{try{return JSON.parse(localStorage.getItem('kervanCentralStaffList')||'[]')}catch{return []}};
 function connect(){
  if(!window.supabase?.createClient)throw new Error('Giriş modülü yüklenemedi. İnternet bağlantısını kontrol edin.');
  return client ||= window.supabase.createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,storageKey:'kervan-central-auth-v1'}});
 }
 async function current(){
  const {data:{session}}=await connect().auth.getSession();if(!session)return null;
  if(!navigator.onLine){const u=cachedUser();return u?.id===session.user.id&&u.active!==false?u:null;}
  const {data,error}=await connect().from('staff').select('*').eq('id',session.user.id).maybeSingle();
  if(error)throw new Error('Merkezi yetki doğrulanamadı.');
  if(!data?.active||data.deleted_at){await logout();return null;}
  const user=map(data);cacheUser(user);return user;
 }
 async function login(username,pin,role){
  const c=connect();const {error}=await c.auth.signInWithPassword({email:emailFor(username),password:'Kervan-PIN:'+pin});
  if(error)throw new Error(error.status===429?'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.':'Kullanıcı adı veya PIN hatalı; bağlantınızı da kontrol edin.');
  const user=await current();
  if(!user || user.role!==role){await logout();throw new Error('Hesabınız seçilen giriş türüne uygun değil veya pasif.');}
  return user;
 }
 async function list(){
  try{const {data,error}=await connect().from('staff').select('*').is('deleted_at',null).order('name');if(error)throw error;const us=data.map(map);cacheList(us);return us;}
  catch(e){if(!navigator.onLine)return cachedList();throw e;}
 }
 async function manage(body){
  const {data:{session},error}=await connect().auth.getSession();
  if(error || !session)throw new Error('Yeniden giriş yapın.');
  const r=await fetch(url+'/functions/v1/manage-staff',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},body:JSON.stringify(body)});
  const data=await r.json();if(!r.ok)throw new Error(data.error||'Personel işlemi tamamlanamadı.');
  try{await list()}catch{}
  return data.user?map(data.user):data;
 }
 async function migrateLocal(actor){
  if(actor.role!=='ADMIN')return 0;
  if(!navigator.onLine)return 0;const central=await list(),names=new Set(central.map(u=>normalize(u.username)));
  let count=0;
  for(const u of await KCache.all('users')){
   const username=normalize(u.username||'');if(!username || names.has(username))continue;
   await manage({action:'create',username,name:u.name||u.username,role:u.role==='ADMIN'?'ADMIN':'PERSONNEL',active:u.active!==false,pin:'1453'});
   names.add(username);count++;
  }
  return count;
 }
 async function logout(){await connect().auth.signOut({scope:'local'});localStorage.removeItem('kervanSession');localStorage.removeItem('kervanLoginRole');localStorage.removeItem('kervanCentralUser');}
 return {connect,current,login,list,manage,migrateLocal,logout};
})();
