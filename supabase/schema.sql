-- Canonical Kervan Mal Kabul schema. Safe for a new project and idempotent on production.
create extension if not exists pgcrypto;
create schema if not exists private;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,role text not null default 'personnel' check(role in('admin','personnel')),active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.staff(id uuid primary key references auth.users(id) on delete cascade,username text not null unique,name text not null,role text not null check(role in('ADMIN','PERSONNEL')),active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz);
create table if not exists public.suppliers(id uuid primary key default gen_random_uuid(),local_id text unique,name text not null,phone text,tax_number text,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.products(id uuid primary key default gen_random_uuid(),local_id text unique,barcode text not null unique,product_code text,product_name text not null,unit text check(unit in('ADET','KOLI','KUTU') or unit is null),case_quantity numeric,box_quantity numeric,purchase_price numeric,source text not null default 'akınsoft',manually_added boolean not null default false,manually_defined_unit boolean not null default false,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.receipts(id uuid primary key default gen_random_uuid(),local_id text unique,supplier_id uuid references public.suppliers(id),supplier_name text,invoice_number text,receipt_date timestamptz not null default now(),employee_id uuid references auth.users(id),employee_name text,description text,status text not null default 'draft' check(status in('draft','completed','cancelled')),total_lines integer not null default 0,total_units numeric not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.receipt_lines(id uuid primary key default gen_random_uuid(),local_id text unique,receipt_id uuid not null references public.receipts(id),product_id uuid references public.products(id),barcode text not null,product_code text,product_name text not null,entered_quantity numeric not null,entered_unit text not null check(entered_unit in('ADET','KOLI','KUTU')),conversion_quantity numeric not null default 1,total_units numeric not null,purchase_price numeric,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.shortage_reports(id uuid primary key default gen_random_uuid(),local_id text unique,receipt_id uuid not null references public.receipts(id),supplier_name text,invoice_number text,product_name text not null,missing_quantity numeric not null check(missing_quantity>0),reported_by uuid not null references auth.users(id),reporter_name text,status text not null default 'open' check(status in('open','resolved')),admin_note text,resolved_at timestamptz,resolved_by uuid references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
alter table public.products add column if not exists sale_price numeric not null default 0, add column if not exists vat_rate numeric not null default 1, add column if not exists current_stock numeric not null default 0;
create table if not exists public.customers(id uuid primary key default gen_random_uuid(),local_id text unique,name text not null,phone text,email text,tax_number text,tax_office text,address text,opening_balance numeric not null default 0,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.accounts(id uuid primary key default gen_random_uuid(),local_id text unique,name text not null,account_type text not null check(account_type in('cash','bank')),currency text not null default 'TRY',opening_balance numeric not null default 0,active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.financial_transactions(id uuid primary key default gen_random_uuid(),local_id text unique,account_id uuid not null references public.accounts(id),transaction_type text not null check(transaction_type in('income','expense','collection','payment','transfer_in','transfer_out')),amount numeric not null check(amount>0),transaction_date date not null default current_date,counterparty_type text,counterparty_id uuid,description text,document_number text,created_by uuid not null references auth.users(id),created_by_name text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.invoices(id uuid primary key default gen_random_uuid(),local_id text unique,invoice_type text not null check(invoice_type in('purchase','sale')),document_number text,invoice_date date not null default current_date,due_date date,supplier_id uuid references public.suppliers(id),supplier_name text,customer_id uuid references public.customers(id),customer_name text,status text not null default 'open' check(status in('draft','open','paid','cancelled')),payment_status text not null default 'unpaid' check(payment_status in('unpaid','partial','paid')),sub_total numeric not null default 0,vat_total numeric not null default 0,grand_total numeric not null default 0,notes text,created_by uuid not null references auth.users(id),created_by_name text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.invoice_lines(id uuid primary key default gen_random_uuid(),local_id text unique,invoice_id uuid not null references public.invoices(id),product_id uuid references public.products(id),barcode text,product_name text not null,quantity numeric not null check(quantity>0),unit text not null default 'ADET',unit_price numeric not null check(unit_price>=0),vat_rate numeric not null default 1,line_total numeric not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.stock_movements(id uuid primary key default gen_random_uuid(),local_id text unique,product_id uuid references public.products(id),barcode text not null,product_name text not null,movement_type text not null check(movement_type in('purchase','sale','count','adjustment','waste','return_in','return_out','opening')),quantity numeric not null,unit_cost numeric,movement_date date not null default current_date,reference_type text,reference_id text,description text,created_by uuid not null references auth.users(id),created_by_name text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.stock_counts(id uuid primary key default gen_random_uuid(),local_id text unique,count_date date not null default current_date,status text not null default 'pending' check(status in('pending','approved','rejected')),notes text,created_by uuid not null references auth.users(id),created_by_name text,approved_at timestamptz,approved_by uuid references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.stock_count_lines(id uuid primary key default gen_random_uuid(),local_id text unique,count_id uuid not null references public.stock_counts(id),product_id uuid references public.products(id),barcode text not null,product_name text not null,system_quantity numeric not null default 0,counted_quantity numeric not null check(counted_quantity>=0),difference_quantity numeric not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
create table if not exists public.audit_logs(id bigint generated always as identity primary key,local_id text unique,user_id uuid references auth.users(id),user_name text,action text not null,entity_type text not null,entity_id text,description text,old_value jsonb,new_value jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),deleted_at timestamptz,last_mutation uuid);
begin;
-- Existing data is retained; timestamps are server-owned from this release onward.
do $$ declare t text; begin
 foreach t in array array['suppliers','products','receipts','receipt_lines','shortage_reports','customers','accounts','financial_transactions','invoices','invoice_lines','stock_movements','stock_counts','stock_count_lines','audit_logs'] loop
  execute format('alter table public.%I add column if not exists deleted_at timestamptz, add column if not exists last_mutation uuid',t);
  execute format('alter table public.%I add column if not exists updated_at timestamptz not null default now()',t);
  execute format('update public.%I set local_id=id::text where local_id is null',t);
  execute format('alter table public.%I alter column local_id set not null',t);
  execute format('create unique index if not exists %I on public.%I(local_id)',t||'_local_id_uidx',t);
 end loop;
end $$;
drop index if exists public.shortage_reports_local_id_uidx;
drop index if exists public.customers_local_id_uidx;
drop index if exists public.accounts_local_id_uidx;
drop index if exists public.financial_transactions_local_id_uidx;
drop index if exists public.invoices_local_id_uidx;
drop index if exists public.invoice_lines_local_id_uidx;
drop index if exists public.stock_movements_local_id_uidx;
drop index if exists public.stock_counts_local_id_uidx;
drop index if exists public.stock_count_lines_local_id_uidx;
create index if not exists shortage_reports_receipt_id_idx on public.shortage_reports(receipt_id);
create index if not exists shortage_reports_reported_by_idx on public.shortage_reports(reported_by);
create index if not exists shortage_reports_resolved_by_idx on public.shortage_reports(resolved_by);
create index if not exists financial_transactions_account_id_idx on public.financial_transactions(account_id);
create index if not exists financial_transactions_created_by_idx on public.financial_transactions(created_by);
create index if not exists invoices_supplier_id_idx on public.invoices(supplier_id);
create index if not exists invoices_customer_id_idx on public.invoices(customer_id);
create index if not exists invoices_created_by_idx on public.invoices(created_by);
create index if not exists invoice_lines_invoice_id_idx on public.invoice_lines(invoice_id);
create index if not exists invoice_lines_product_id_idx on public.invoice_lines(product_id);
create index if not exists stock_movements_barcode_idx on public.stock_movements(barcode);
create index if not exists stock_movements_product_id_idx on public.stock_movements(product_id);
create index if not exists stock_movements_created_by_idx on public.stock_movements(created_by);
create index if not exists stock_counts_created_by_idx on public.stock_counts(created_by);
create index if not exists stock_counts_approved_by_idx on public.stock_counts(approved_by);
create index if not exists stock_count_lines_count_id_idx on public.stock_count_lines(count_id);
create index if not exists stock_count_lines_product_id_idx on public.stock_count_lines(product_id);
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
  if TG_OP='UPDATE' and r<>'ADMIN' and (old.employee_id<>auth.uid() or old.status='cancelled' or (old.status='completed' and new.status<>'completed') or new.employee_id is distinct from old.employee_id or new.employee_name is distinct from old.employee_name or new.deleted_at is not null) then raise exception 'Yalnızca kendi mal kabul kaydınızı düzenleyebilirsiniz' using errcode='42501'; end if;
  if new.status='completed' then
   select count(*),coalesce(sum(total_units),0) into new.total_lines,new.total_units from public.receipt_lines where receipt_id=new.id and deleted_at is null;
   if new.total_lines=0 then raise exception 'Boş mal kabul tamamlanamaz'; end if;
  end if;
 end if;
 if TG_TABLE_NAME='receipt_lines' then
  select * into parent from public.receipts where id=new.receipt_id for update;
  if not found or parent.deleted_at is not null then raise exception 'Mal kabul bulunamadı'; end if;
  if r<>'ADMIN' and (parent.employee_id<>auth.uid() or parent.status not in ('draft','completed')) then raise exception 'Yalnızca kendi mal kabul satırlarınızı düzenleyebilirsiniz' using errcode='42501'; end if;
  if TG_OP='UPDATE' and new.receipt_id<>old.receipt_id then raise exception 'Satır başka belgeye taşınamaz'; end if;
  if new.entered_quantity<=0 or new.conversion_quantity<=0 then raise exception 'Miktar ve çevrim pozitif olmalı'; end if;
  if new.entered_unit='ADET' then new.conversion_quantity:=1; end if;
  new.total_units:=new.entered_quantity*new.conversion_quantity;
 end if;
 if TG_TABLE_NAME='shortage_reports' then
  select * into parent from public.receipts where id=new.receipt_id and deleted_at is null;
  if not found or parent.status<>'completed' then raise exception 'Eksik ürün yalnızca tamamlanmış mal kabulden bildirilebilir'; end if;
  if btrim(coalesce(new.product_name,''))='' or new.missing_quantity<=0 then raise exception 'Ürün adı ve eksik adet zorunludur'; end if;
  if TG_OP='INSERT' then
   if r<>'ADMIN' and parent.employee_id<>auth.uid() then raise exception 'Yalnızca kendi mal kabulünüz için bildirim oluşturabilirsiniz' using errcode='42501'; end if;
   new.reported_by:=auth.uid(); select name into new.reporter_name from public.staff where id=auth.uid(); new.status:='open'; new.admin_note:=null; new.resolved_at:=null; new.resolved_by:=null;
  elsif r<>'ADMIN' then raise exception 'Eksik ürün bildirimi yalnızca yönetici tarafından güncellenebilir' using errcode='42501';
  elsif new.status='resolved' and old.status<>'resolved' then new.resolved_at:=clock_timestamp();new.resolved_by:=auth.uid();
  elsif new.status='open' then new.resolved_at:=null;new.resolved_by:=null;
  end if;
 end if;
 if TG_TABLE_NAME in ('customers','accounts','financial_transactions','invoices','invoice_lines','stock_movements') and r<>'ADMIN' then raise exception 'Bu işlem yalnızca yöneticiye açık' using errcode='42501'; end if;
 if TG_TABLE_NAME='financial_transactions' and TG_OP='INSERT' then new.created_by:=auth.uid();select name into new.created_by_name from public.staff where id=auth.uid(); end if;
 if TG_TABLE_NAME='invoices' and TG_OP='INSERT' then new.created_by:=auth.uid();select name into new.created_by_name from public.staff where id=auth.uid(); end if;
 if TG_TABLE_NAME='invoice_lines' then new.line_total:=new.quantity*new.unit_price*(1+new.vat_rate/100); end if;
 if TG_TABLE_NAME='stock_movements' and TG_OP='INSERT' then new.created_by:=auth.uid();select name into new.created_by_name from public.staff where id=auth.uid(); end if;
 if TG_TABLE_NAME='stock_counts' then
  if TG_OP='INSERT' then new.created_by:=auth.uid();select name into new.created_by_name from public.staff where id=auth.uid();new.status:='pending';new.approved_at:=null;new.approved_by:=null;
  elsif r<>'ADMIN' then raise exception 'Sayımı yalnızca yönetici onaylayabilir' using errcode='42501'; end if;
 end if;
 if TG_TABLE_NAME='stock_count_lines' then
  if TG_OP='INSERT' and not exists(select 1 from public.stock_counts c where c.id=new.count_id and (c.created_by=auth.uid() or r='ADMIN') and c.status='pending') then raise exception 'Sayım satırı yetkisi yok' using errcode='42501'; end if;
  new.difference_quantity:=new.counted_quantity-new.system_quantity;
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
 foreach t in array array['suppliers','products','receipts','receipt_lines','shortage_reports','customers','accounts','financial_transactions','invoices','invoice_lines','stock_movements','stock_counts','stock_count_lines','audit_logs'] loop
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
create policy receipts_update on public.receipts for update to authenticated using ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid()))) with check ((select private.staff_role())='ADMIN' or ((select private.staff_role())='PERSONNEL' and employee_id=(select auth.uid())));
create policy lines_read on public.receipt_lines for select to authenticated using (exists(select 1 from public.receipts r where r.id=receipt_id));
create policy lines_insert on public.receipt_lines for insert to authenticated with check ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.status='draft' and r.deleted_at is null));
create policy lines_update on public.receipt_lines for update to authenticated using ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.deleted_at is null)) with check ((select private.staff_role())='ADMIN' or exists(select 1 from public.receipts r where r.id=receipt_id and r.employee_id=(select auth.uid()) and r.deleted_at is null));
create policy shortages_read on public.shortage_reports for select to authenticated using ((select private.staff_role())='ADMIN' or reported_by=(select auth.uid()));
create policy shortages_insert on public.shortage_reports for insert to authenticated with check ((select private.staff_role()) is not null and reported_by=(select auth.uid()));
create policy shortages_update on public.shortage_reports for update to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy customers_admin on public.customers for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy accounts_admin on public.accounts for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy transactions_admin on public.financial_transactions for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy invoices_admin on public.invoices for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy invoice_lines_admin on public.invoice_lines for all to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy stock_movements_read on public.stock_movements for select to authenticated using ((select private.staff_role()) is not null);
create policy stock_movements_admin on public.stock_movements for insert to authenticated with check ((select private.staff_role())='ADMIN');
create policy stock_movements_update on public.stock_movements for update to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy stock_counts_read on public.stock_counts for select to authenticated using ((select private.staff_role())='ADMIN' or created_by=(select auth.uid()));
create policy stock_counts_insert on public.stock_counts for insert to authenticated with check ((select private.staff_role()) is not null and created_by=(select auth.uid()));
create policy stock_counts_update on public.stock_counts for update to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
create policy stock_count_lines_read on public.stock_count_lines for select to authenticated using (exists(select 1 from public.stock_counts c where c.id=count_id));
create policy stock_count_lines_insert on public.stock_count_lines for insert to authenticated with check (exists(select 1 from public.stock_counts c where c.id=count_id and (c.created_by=(select auth.uid()) or (select private.staff_role())='ADMIN') and c.status='pending'));
create policy stock_count_lines_update on public.stock_count_lines for update to authenticated using ((select private.staff_role())='ADMIN') with check ((select private.staff_role())='ADMIN');
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
 when 'products' then array['barcode','product_code','product_name','unit','case_quantity','box_quantity','purchase_price','sale_price','vat_rate','current_stock','manually_added','manually_defined_unit','notes','deleted_at']
 when 'receipts' then array['supplier_id','supplier_name','invoice_number','receipt_date','employee_id','employee_name','description','status','deleted_at']
 when 'receipt_lines' then array['receipt_id','barcode','product_code','product_name','entered_quantity','entered_unit','conversion_quantity','total_units','purchase_price','deleted_at']
 when 'shortage_reports' then array['receipt_id','supplier_name','invoice_number','product_name','missing_quantity','reported_by','reporter_name','status','admin_note','resolved_at','resolved_by','deleted_at']
 when 'customers' then array['name','phone','email','tax_number','tax_office','address','opening_balance','notes','deleted_at']
 when 'accounts' then array['name','account_type','currency','opening_balance','active','deleted_at']
 when 'financial_transactions' then array['account_id','transaction_type','amount','transaction_date','counterparty_type','counterparty_id','description','document_number','created_by','created_by_name','deleted_at']
 when 'invoices' then array['invoice_type','document_number','invoice_date','due_date','supplier_id','supplier_name','customer_id','customer_name','status','payment_status','sub_total','vat_total','grand_total','notes','created_by','created_by_name','deleted_at']
 when 'invoice_lines' then array['invoice_id','product_id','barcode','product_name','quantity','unit','unit_price','vat_rate','line_total','deleted_at']
 when 'stock_movements' then array['product_id','barcode','product_name','movement_type','quantity','unit_cost','movement_date','reference_type','reference_id','description','created_by','created_by_name','deleted_at']
 when 'stock_counts' then array['count_date','status','notes','created_by','created_by_name','approved_at','approved_by','deleted_at']
 when 'stock_count_lines' then array['count_id','product_id','barcode','product_name','system_quantity','counted_quantity','difference_quantity','deleted_at']
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
  -- A product created offline may already have arrived from an Excel import.
  -- Adopt the central row and clear the outbox instead of violating barcode uniqueness.
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
 if p_table='shortage_reports' then
  if clean->>'receipt_id' is not null then clean:=jsonb_set(clean,'{receipt_id}',coalesce((select to_jsonb(id) from public.receipts where local_id=clean->>'receipt_id'),'null'::jsonb));
  elsif oldrow is not null then clean:=clean||jsonb_build_object('receipt_id',oldrow->'receipt_id'); end if;
  if oldrow is null then clean:=clean||jsonb_build_object('reported_by',auth.uid());
  else clean:=clean||jsonb_build_object('reported_by',oldrow->'reported_by','reporter_name',oldrow->'reporter_name'); end if;
 end if;
 if p_table in ('financial_transactions','invoices','stock_movements','stock_counts') then clean:=clean||jsonb_build_object('created_by',coalesce(oldrow->'created_by',to_jsonb(auth.uid()))); end if;
 if p_table='financial_transactions' and clean->>'account_id' is not null then clean:=jsonb_set(clean,'{account_id}',coalesce((select to_jsonb(id) from public.accounts where local_id=clean->>'account_id'),'null'::jsonb)); end if;
 if p_table='invoices' then
  if clean->>'supplier_id' is not null then clean:=jsonb_set(clean,'{supplier_id}',coalesce((select to_jsonb(id) from public.suppliers where local_id=clean->>'supplier_id'),'null'::jsonb)); end if;
  if clean->>'customer_id' is not null then clean:=jsonb_set(clean,'{customer_id}',coalesce((select to_jsonb(id) from public.customers where local_id=clean->>'customer_id'),'null'::jsonb)); end if;
 end if;
 if p_table='invoice_lines' then clean:=jsonb_set(clean,'{invoice_id}',coalesce((select to_jsonb(id) from public.invoices where local_id=clean->>'invoice_id'),'null'::jsonb)); end if;
 if p_table='stock_count_lines' then clean:=jsonb_set(clean,'{count_id}',coalesce((select to_jsonb(id) from public.stock_counts where local_id=clean->>'count_id'),'null'::jsonb)); end if;
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

create or replace function private.recalculate_invoice() returns trigger language plpgsql security invoker set search_path='' as $$
declare target uuid:=new.invoice_id;begin
 update public.invoices i set
  sub_total=x.sub_total,vat_total=x.vat_total,grand_total=x.grand_total,updated_at=clock_timestamp()
 from (select coalesce(sum(quantity*unit_price),0) sub_total,coalesce(sum(quantity*unit_price*vat_rate/100),0) vat_total,coalesce(sum(line_total),0) grand_total from public.invoice_lines where invoice_id=target and deleted_at is null) x
 where i.id=target;
 return new;
end $$;
drop trigger if exists recalculate_invoice on public.invoice_lines;
create trigger recalculate_invoice after insert or update on public.invoice_lines for each row execute function private.recalculate_invoice();

create or replace function private.apply_stock_movement() returns trigger language plpgsql security invoker set search_path='' as $$ begin
 if TG_OP='INSERT' and new.deleted_at is null then update public.products set current_stock=current_stock+new.quantity,updated_at=clock_timestamp() where barcode=new.barcode; end if;
 if TG_OP='UPDATE' then
  if old.deleted_at is null and new.deleted_at is not null then update public.products set current_stock=current_stock-old.quantity,updated_at=clock_timestamp() where barcode=old.barcode;
  elsif old.deleted_at is null and new.deleted_at is null and (old.quantity is distinct from new.quantity or old.barcode is distinct from new.barcode) then
   update public.products set current_stock=current_stock-old.quantity,updated_at=clock_timestamp() where barcode=old.barcode;
   update public.products set current_stock=current_stock+new.quantity,updated_at=clock_timestamp() where barcode=new.barcode;
  end if;
 end if;
 return new;
end $$;
drop trigger if exists apply_stock_movement on public.stock_movements;
create trigger apply_stock_movement after insert or update on public.stock_movements for each row execute function private.apply_stock_movement();

create or replace function public.post_simple_invoice(p_data jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare inv public.invoices;prod public.products;party_name text;party_id uuid;qty numeric:=(p_data->>'quantity')::numeric;price numeric:=(p_data->>'unit_price')::numeric;vat numeric:=coalesce((p_data->>'vat_rate')::numeric,1);kind text:=p_data->>'invoice_type';begin
 if private.staff_role()<>'ADMIN' then raise exception 'Fatura işlemi yalnızca yöneticiye açık' using errcode='42501'; end if;
 if kind not in ('purchase','sale') or qty<=0 or price<0 then raise exception 'Fatura bilgileri geçersiz'; end if;
 select * into prod from public.products where barcode=p_data->>'barcode' and deleted_at is null for update;if not found then raise exception 'Ürün bulunamadı';end if;
 if kind='purchase' then select id,name into party_id,party_name from public.suppliers where local_id=p_data->>'party_local_id' and deleted_at is null;
 else select id,name into party_id,party_name from public.customers where local_id=p_data->>'party_local_id' and deleted_at is null;end if;
 if party_id is null then raise exception 'Cari kart bulunamadı';end if;
 insert into public.invoices(local_id,invoice_type,document_number,invoice_date,supplier_id,supplier_name,customer_id,customer_name,status,payment_status,notes,created_by)
 values(p_data->>'local_id',kind,nullif(p_data->>'document_number',''),coalesce((p_data->>'invoice_date')::date,current_date),case when kind='purchase' then party_id end,case when kind='purchase' then party_name end,case when kind='sale' then party_id end,case when kind='sale' then party_name end,'open','unpaid',p_data->>'notes',auth.uid()) returning * into inv;
 insert into public.invoice_lines(local_id,invoice_id,product_id,barcode,product_name,quantity,unit,unit_price,vat_rate,line_total)
 values(gen_random_uuid()::text,inv.id,prod.id,prod.barcode,prod.product_name,qty,coalesce(prod.unit,'ADET'),price,vat,qty*price*(1+vat/100));
 insert into public.stock_movements(local_id,product_id,barcode,product_name,movement_type,quantity,unit_cost,movement_date,reference_type,reference_id,description,created_by)
 values(gen_random_uuid()::text,prod.id,prod.barcode,prod.product_name,kind,case when kind='purchase' then qty else -qty end,price,inv.invoice_date,'invoice',inv.local_id,coalesce(inv.document_number,'Fatura'),auth.uid());
 if kind='purchase' then update public.products set purchase_price=price,updated_at=clock_timestamp() where id=prod.id;else update public.products set sale_price=price,updated_at=clock_timestamp() where id=prod.id;end if;
 return jsonb_build_object('status','ok','local_id',inv.local_id);
end $$;
revoke all on function public.post_simple_invoice(jsonb) from public,anon;
grant execute on function public.post_simple_invoice(jsonb) to authenticated;

create or replace function public.approve_stock_count(p_local_id text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c public.stock_counts;l record;begin
 if private.staff_role()<>'ADMIN' then raise exception 'Yalnızca yönetici sayım onaylayabilir' using errcode='42501'; end if;
 select * into c from public.stock_counts where local_id=p_local_id and deleted_at is null for update;
 if not found or c.status<>'pending' then raise exception 'Onaylanabilir sayım bulunamadı'; end if;
 for l in select * from public.stock_count_lines where count_id=c.id and deleted_at is null loop
  if l.difference_quantity<>0 then insert into public.stock_movements(local_id,product_id,barcode,product_name,movement_type,quantity,movement_date,reference_type,reference_id,description,created_by)
   values(gen_random_uuid()::text,l.product_id,l.barcode,l.product_name,'count',l.difference_quantity,c.count_date,'stock_count',c.local_id,'Sayım farkı',auth.uid()); end if;
 end loop;
 update public.stock_counts set status='approved',approved_at=clock_timestamp(),approved_by=auth.uid(),updated_at=clock_timestamp() where id=c.id;
 return jsonb_build_object('status','ok','local_id',p_local_id);
end $$;
revoke all on function public.approve_stock_count(text) from public,anon;
grant execute on function public.approve_stock_count(text) to authenticated;

-- Realtime invalidates caches; paginated reads still provide the authoritative snapshot.
do $$ declare t text; begin
 foreach t in array array['staff','suppliers','products','receipts','receipt_lines','shortage_reports','customers','accounts','financial_transactions','invoices','invoice_lines','stock_movements','stock_counts','stock_count_lines','audit_logs'] loop
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then execute format('alter publication supabase_realtime add table public.%I',t); end if;
 end loop;
end $$;
commit;
