import { createClient } from 'npm:@supabase/supabase-js@2.95.3';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const fields = 'id,username,name,role,active,created_at,updated_at';
const normalize = (s: string) => s.trim().toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ');
const emailFor = (username: string) => Array.from(new TextEncoder().encode(username)).map(v=>v.toString(16).padStart(2,'0')).join('') + '@staff.kervan.invalid';
Deno.serve(async req => {
 const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
 if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
 if (req.method !== 'POST') return reply({error:'Yalnızca POST desteklenir.'},405);
 try {
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: {persistSession:false,autoRefreshToken:false} });
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer /,'');
  const {data:auth,error:authError} = await db.auth.getUser(token);
  if (authError || !auth.user) return reply({error:'Oturum açmanız gerekiyor.'},401);
  const {data:actor,error:actorError} = await db.from('staff').select(fields).eq('id',auth.user.id).single();
  if (actorError || !actor?.active || actor.role !== 'ADMIN') return reply({error:'Yönetici yetkisi gerekiyor.'},403);
  const body = await req.json();
  if (body.action === 'create') {
   const username=normalize(String(body.username||'')), name=String(body.name||'').trim(), role=body.role;
   const pin=String(body.pin||'1453');
   if (!username || username.length>40 || !name || name.length>100 || !['ADMIN','PERSONNEL'].includes(role) || !/^\d{4,12}$/.test(pin)) return reply({error:'Ad, kullanıcı adı, rol ve 4–12 haneli PIN kontrol edilmeli.'},400);
   const {data:existing,error:lookupError}=await db.from('staff').select('id').eq('username',username).maybeSingle();
   if(lookupError) throw lookupError;
   if(existing) return reply({error:'Bu kullanıcı adı zaten var.'},409);
   const {data:created,error}=await db.auth.admin.createUser({email:emailFor(username),password:'Kervan-PIN:'+pin,email_confirm:true});
   if(error) return reply({error:'Kullanıcı oluşturulamadı. Kullanıcı adı daha önce kullanılmış olabilir.'},400);
   const {data:staff,error:insertError}=await db.from('staff').insert({id:created.user.id,username,name,role,active:body.active!==false}).select(fields).single();
   if(insertError){await db.auth.admin.deleteUser(created.user.id);throw insertError;}
   return reply({user:staff});
  }
  if(body.action === 'toggle' || body.action === 'resetPin') {
   const {data:target,error}=await db.from('staff').select(fields).eq('id',body.id).single();
   if(error || !target) return reply({error:'Kullanıcı bulunamadı.'},404);
   if(body.action === 'toggle') {
    if(target.id===actor.id) return reply({error:'Kendi hesabınızı pasif edemezsiniz.'},400);
    if(typeof body.active!=='boolean') return reply({error:'Durum geçersiz.'},400);
    const {data:user,error:updateError}=await db.from('staff').update({active:body.active,updated_at:new Date().toISOString()}).eq('id',target.id).select(fields).single();
    if(updateError) throw updateError;
    return reply({user});
   }
   const pin=String(body.pin||'1453');
   if(!/^\d{4,12}$/.test(pin)) return reply({error:'PIN 4–12 rakam olmalı.'},400);
   const {error:resetError}=await db.auth.admin.updateUserById(target.id,{password:'Kervan-PIN:'+pin});
   if(resetError) throw resetError;
   return reply({ok:true});
  }
  return reply({error:'İşlem tanınmadı.'},400);
 } catch { return reply({error:'Merkezi personel işlemi tamamlanamadı.'},500); }
});
