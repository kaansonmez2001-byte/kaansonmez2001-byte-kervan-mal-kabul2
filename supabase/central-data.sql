begin;
-- Existing data is retained; timestamps are server-owned from this release onward.
do $$ declare t text; begin
 foreach t in array array['suppliers','products','receipts','receipt_lines','audit_logs'] loop
  execute format('alter table public.%I add column if not exists deleted_at timestamptz, add column if not exists last_mutation uuid',t);
  execute format('alter table public.%I add column if not exists updated_at timestamptz not null default now()',t);
  execute format('update public.%I set local_id=id::text where local_id is null',t);
  execute format('alter table public.%I alter column local_id set not null',t);
  execute format('create unique index if not exists %I on public.%I(local_id)',t||'_local_id_uidx',t);
 end loop;
end $$;
alter table public.staff add column if not exists deleted_at timestamptz;
create or replace function private.staff_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.staff where id=(select auth.uid()) and active and deleted_at is null
$$;
revoke all on function private.staff_role() from public,anon;
grant execute on function private.staff_role() to authenticated;
alter table public.staff enable row level security;
alter table public.profiles enable row level security;
revoke all on public.staff,public.profiles from anon,authenticated;
grant select on public.staff to authenticated;
drop policy if exists staff_read on public.staff;
create policy staff_read on public.staff for select to authenticated using ((select private.staff_role()) is not null);
create or replace function public.manage_staff_status(p_actor uuid,p_id uuid,p_role text,p_active boolean) returns public.staff
language plpgsql security invoker set search_path='' as $$ declare result public.staff; begin
 lock table public.staff in share row exclusive mode;
 if not exists(select 1 from public.staff where id=p_actor and active and role='ADMIN' and deleted_at is null) or p_actor=p_id then raise exception 'Yetki yok'; end if;
 update public.staff set role=p_role,active=p_active,updated_at=clock_timestamp() where id=p_id and deleted_at is null returning * into result;
 return result;
end $$;
revoke all on function public.manage_staff_status(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.manage_staff_status(uuid,uuid,text,boolean) to service_role;

-- Guard writes even if a caller bypasses the application and invokes REST directly.
create or replace function private.guard_data_write() returns trigger language plpgsql security invoker set search_path='' as $$
declare r text:=private.staff_role(); parent public.receipts; begin
 if auth.uid() is null then if current_user not in ('postgres','service_role','supabase_admin') then raise exception 'Aktif oturum gerekli' using errcode='42501'; end if; new.updated_at:=clock_timestamp(); if new.deleted_at is not null then new.deleted_at:=new.updated_at; end if; return new; end if; if r is null then raise exception 'Aktif oturum gerekli' using errcode='42501'; end if;
 if TG_OP='DELETE' then raise exception 'Kalıcı silme kapalı; deleted_at kullanın' using errcode='42501'; end if;
 if TG_OP='UPDATE' then
  if old.deleted_at is not null then raise exception 'Silinmiş kayıt değiştirilemez'; end if;
  if new.local_id<>old.local_id or new.id<>old.id then raise exception 'Kayıt kimliği değiştirilemez'; end if;
 end if;
 if TG_TABLE_NAME='products' and r<>'ADMIN' then
  if TG_OP='INSERT' and (not new.manually_added or new.purchase_price is not null) then raise exception 'Yalnızca tanımsız ürün eklenebilir' using errcode='42501'; end if;
  if TG_OP='UPDATE' and (to_jsonb(new)-array['unit','case_quantity','box_quantity','manually_defined_unit','updated_at','last_mutation']) is distinct from (to_jsonb(old)-array['unit','case_quantity','box_quantity','manually_defined_unit','updated_at','last_mutation']) then raise exception 'Ürün yönetimi yalnızca yöneticiye açık' using errcode='42501'; end if;
  if TG_OP='UPDATE' and ((old.case_quantity is not null and new.case_quantity is distinct from old.case_quantity) or (old.box_quantity is not null and new.box_quantity is distinct from old.box_quantity) or (old.unit is not null and new.unit is distinct from old.unit)) then raise exception 'Tanımlı çevrim yalnızca yönetici tarafından değiştirilebilir' using errcode='42501'; end if;
 end if;
 if TG_TABLE_NAME='receipts' then
  if TG_OP='INSERT' and r<>'ADMIN' then new.employee_id:=auth.uid(); select name into new.employee_name from public.staff where id=auth.uid(); end if;
  if TG_OP='UPDATE' and r<>'ADMIN' and (old.employee_id<>auth.uid() or old.status<>'draft' or new.employee_id is distinct from old.employee_id or new.employee_name is distinct from old.employee_name or new.deleted_at is not null) then raise exception 'Bu mal kabul değiştirilemez' using errcode='42501'; end if;
  if new.status='completed' then
   select count(*),coalesce(sum(total_units),0) into new.total_lines,new.total_units from public.receipt_lines where receipt_id=new.id and deleted_at is null;
   if new.total_lines=0 then raise exception 'Boş mal kabul tamamlanamaz'; end if;
  end if;
 end if;
 if TG_TABLE_NAME='receipt_lines' then
  select * into parent from public.receipts where id=new.receipt_id for update;
  if not found or parent.deleted_at is not null then raise exception 'Mal kabul bulunamadı'; end if;
  if r<>'ADMIN' and (parent.employee_id<>auth.uid() or parent.status<>'draft') then raise exception 'Yalnızca kendi taslağınız değiştirilebilir' using errcode='42501'; end if;
  if TG_OP='UPDATE' and new.receipt_id<>old.receipt_id then raise exception 'Satır başka belgeye taşınamaz'; end if;
  if new.entered_quantity<=0 or new.conversion_quantity<=0 then raise exception 'Miktar ve çevrim pozitif olmalı'; end if;
  if new.entered_unit='ADET' then new.conversion_quantity:=1; end if;
  new.total_units:=new.entered_quantity*new.conversion_quantity;
 end if;
 if TG_TABLE_NAME='audit_logs' then
  if TG_OP<>'INSERT' then raise exception 'İşlem geçmişi değiştirilemez' using errcode='42501'; end if;
  new.user_id:=auth.uid(); select name into new.user_name from public.staff where id=auth.uid();
 end if;
 new.updated_at:=clock_timestamp();
 if new.deleted_at is not null then new.deleted_at:=new.updated_at; end if;
 return new;
end $$;
revoke all on function private.guard_data_write() from public,anon;
grant execute on function private.guard_data_write() to authenticated;
do $$ declare t text; p record; begin
 foreach t in array array['suppliers','products','receipts','receipt_lines','audit_logs'] loop
  execute format('alter table public.%I enable row level security',t);
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop execute format('drop policy %I on public.%I',p.policyname,t); end loop;
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant select,insert,update on public.%I to authenticated',t);
  execute format('drop trigger if exists guard_data_write on public.%I',t);
  execute format('create trigger guard_data_write before insert or update or delete on public.%I for each row execute function private.guard_data_write()',t);
 end loop;
end $$;
create policy suppliers_read on public.suppliers for select to authenticated using ((select private.staff_role()) is not null);
create policy suppliers_write on public.suppliers for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy products_read on public.products for select to authenticated using ((select private.staff_role()) is not null);
create policy products_insert on public.products for insert to authenticated with check ((select private.staff_role()) is not null);
create policy products_update on public.products for update to authenticated using ((select private.staff_role()) is not null) with check ((select private.staff_role()) is not null);
create policy receipts_read on public.receipts for select to authenticated using ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid())));
create policy receipts_insert on public.receipts for insert to authenticated with check ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid())));
create policy receipts_update on public.receipts for update to authenticated using ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid()) and status='draft')) with check ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid())));
create policy lines_read on public.receipt_lines for select to authenticated using (exists(select 1 from public.receipts r where r.id=receipt_id));
create policy lines_insert on public.receipt_lines for insert to authenticated with check ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.status='draft' and r.deleted_at is null));
create policy lines_update on public.receipt_lines for update to authenticated using ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.status='draft' and r.deleted_at is null)) with check ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.status='draft' and r.deleted_at is null));
create policy audit_read on public.audit_logs for select to authenticated using ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and user_id=(select auth.uid())));
create policy audit_insert on public.audit_logs for insert to authenticated with check ((select private.staff_role()) is not null and user_id=(select auth.uid()));
grant usage on sequence public.audit_logs_id_seq to authenticated;

-- Compare-and-set inside one transaction. Client clocks never decide the winner.
create or replace function public.apply_change(p_table text,p_key text,p_data jsonb,p_base timestamptz,p_mutation uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare oldrow jsonb; result jsonb; cols text; vals text; sets text; clean jsonb; allowed text[]; natural_match boolean:=false; begin
 if auth.uid() is null or private.staff_role() is null then raise exception 'Aktif oturum gerekli' using errcode='42501'; end if;
 allowed:=case p_table
 when 'suppliers' then array['name','phone','tax_number','notes','deleted_at']
 when 'products' then array['barcode','product_code','product_name','unit','case_quantity','box_quantity','purchase_price','manually_added','manually_defined_unit','notes','deleted_at']
 when 'receipts' then array['supplier_id','supplier_name','invoice_number','receipt_date','employee_id','employee_name','description','status','deleted_at']
 when 'receipt_lines' then array['receipt_id','barcode','product_code','product_name','entered_quantity','entered_unit','conversion_quantity','total_units','purchase_price','deleted_at']
 when 'audit_logs' then array['user_id','user_name','action','entity_type','entity_id','description','old_value','new_value'] else null end;
 if allowed is null or p_key is null or p_key='' or length(p_key)>200 then raise exception 'Geçersiz tablo veya kimlik'; end if;
 -- Serialization also covers concurrent first inserts and retries after lost responses.
 perform pg_advisory_xact_lock(hashtextextended(p_table||':'||p_key,0));
 if p_table='audit_logs' then
  execute format('select to_jsonb(t) from public.%I t where local_id=$1',p_table) into oldrow using p_key;
 else
  execute format('select to_jsonb(t) from public.%I t where local_id=$1 for update',p_table) into oldrow using p_key;
 end if;
 if oldrow is null and p_table='products' and nullif(p_data->>'barcode','') is not null then
  select to_jsonb(t) into oldrow from public.products t where t.barcode=p_data->>'barcode' for update;
  natural_match:=oldrow is not null;
  if natural_match and p_base is null then
   return jsonb_build_object('status','ok','row',oldrow,'deduplicated',true);
  end if;
 end if;
 if oldrow is not null then
  if oldrow->>'last_mutation'=p_mutation::text then return jsonb_build_object('status','ok','row',oldrow); end if;
  if oldrow->>'deleted_at' is not null or p_base is null or (oldrow->>'updated_at')::timestamptz is distinct from p_base then return jsonb_build_object('status','conflict','row',oldrow); end if;
 elsif p_base is not null then return jsonb_build_object('status','conflict','row',null);
 end if;
 select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into clean from jsonb_each(p_data) where key=any(allowed);
 clean:=clean||jsonb_build_object('local_id',coalesce(oldrow->>'local_id',p_key),'last_mutation',p_mutation);
 if p_table='receipts' and clean->>'supplier_id' is not null then clean:=jsonb_set(clean,'{supplier_id}',coalesce((select to_jsonb(id) from public.suppliers where local_id=clean->>'supplier_id' and deleted_at is null),'null'::jsonb)); end if;
 if p_table='receipt_lines' then clean:=jsonb_set(clean,'{receipt_id}',coalesce((select to_jsonb(id) from public.receipts where local_id=clean->>'receipt_id'),'null'::jsonb)); end if;
 if p_table='audit_logs' then clean:=clean||jsonb_build_object('user_id',auth.uid()); end if;
 select string_agg(format('%I',key),','),string_agg(format('r.%I',key),','),string_agg(format('%I=r.%I',key,key),',') into cols,vals,sets from jsonb_object_keys(clean) key;
 if oldrow is null then
  execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) r returning to_jsonb(%I.*)',p_table,cols,vals,p_table,p_table) into result using clean;
 else
  execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I,$1) r where t.local_id=$2 returning to_jsonb(t.*)',p_table,sets,p_table) into result using clean,p_key;
 end if;
 if result is null then raise exception 'İşlem yetkisi yok' using errcode='42501'; end if;
 return jsonb_build_object('status','ok','row',result);
end $$;
revoke all on function public.apply_change(text,text,jsonb,timestamptz,uuid) from public,anon;
grant execute on function public.apply_change(text,text,jsonb,timestamptz,uuid) to authenticated;

-- Realtime invalidates caches; paginated reads still provide the authoritative snapshot.
do $$ declare t text; begin
 foreach t in array array['staff','suppliers','products','receipts','receipt_lines','audit_logs'] loop
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then execute format('alter publication supabase_realtime add table public.%I',t); end if;
 end loop;
end $$;
commit;
