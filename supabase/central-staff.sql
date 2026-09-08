-- Central identity and authorization for the existing Kervan database.
create table if not exists public.staff (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique,
 name text not null,
 role text not null check (role in ('ADMIN','PERSONNEL')),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.staff enable row level security;
revoke all on public.staff from anon, authenticated;
grant select on public.staff to authenticated;
grant all on public.staff to service_role;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create or replace function private.staff_role() returns text
language sql stable security definer set search_path = '' as $$
 select role from public.staff where id = (select auth.uid()) and active = true
$$;
revoke all on function private.staff_role() from public, anon;
grant execute on function private.staff_role() to authenticated;
create policy staff_read on public.staff for select to authenticated
 using ((select private.staff_role()) is not null);

do $$ declare p record; begin
 for p in select tablename, policyname from pg_policies where schemaname='public' and tablename in ('products','suppliers','receipts','receipt_lines','audit_logs') loop
 execute format('drop policy %I on public.%I',p.policyname,p.tablename);
 end loop;
end $$;
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path='' as $$ select coalesce(private.staff_role() = 'ADMIN',false) $$;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;
create policy products_read on public.products for select to authenticated using ((select private.staff_role()) is not null);
create policy products_admin on public.products for all to authenticated using ((select private.staff_role()) = 'ADMIN') with check ((select private.staff_role()) = 'ADMIN');
create policy suppliers_read on public.suppliers for select to authenticated using ((select private.staff_role()) is not null);
create policy suppliers_admin on public.suppliers for all to authenticated using ((select private.staff_role()) = 'ADMIN') with check ((select private.staff_role()) = 'ADMIN');
alter table public.receipts add column if not exists employee_id uuid references public.staff(id);
create policy receipts_read on public.receipts for select to authenticated using ((select private.staff_role()) is not null);
create policy receipts_insert on public.receipts for insert to authenticated with check ((select private.staff_role()) = 'ADMIN' or ((select private.staff_role()) = 'PERSONNEL' and employee_id = (select auth.uid())));
create policy receipts_update on public.receipts for update to authenticated using ((select private.staff_role()) = 'ADMIN' or ((select private.staff_role()) = 'PERSONNEL' and employee_id = (select auth.uid()) and status = 'draft')) with check ((select private.staff_role()) = 'ADMIN' or ((select private.staff_role()) = 'PERSONNEL' and employee_id = (select auth.uid())));
create policy lines_read on public.receipt_lines for select to authenticated using ((select private.staff_role()) is not null);
create policy lines_write on public.receipt_lines for all to authenticated using ((select private.staff_role()) = 'ADMIN' or ((select private.staff_role()) = 'PERSONNEL' and exists(select 1 from public.receipts r where r.id = receipt_id and r.employee_id = (select auth.uid()) and r.status = 'draft'))) with check ((select private.staff_role()) = 'ADMIN' or ((select private.staff_role()) = 'PERSONNEL' and exists(select 1 from public.receipts r where r.id = receipt_id and r.employee_id = (select auth.uid()) and r.status = 'draft')));
create policy audit_read on public.audit_logs for select to authenticated using ((select private.staff_role()) = 'ADMIN');
create policy audit_admin on public.audit_logs for all to authenticated using ((select private.staff_role()) = 'ADMIN') with check ((select private.staff_role()) = 'ADMIN');
create index if not exists receipts_employee_id_idx on public.receipts(employee_id);
create index if not exists receipt_lines_receipt_local_id_idx on public.receipt_lines(receipt_id);
