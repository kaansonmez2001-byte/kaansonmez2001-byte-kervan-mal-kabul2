-- Kervan Mal Kabul - merkezi senkronizasyon için Faz 2 şeması
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  barcode text not null unique,
  product_code text,
  product_name text not null,
  unit text check (unit in ('ADET','KOLI','KUTU')),
  case_qty numeric,
  box_qty numeric,
  purchase_price numeric,
  manually_added boolean not null default false,
  manually_defined_unit boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_barcode_idx on public.products(barcode);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  supplier text,
  invoice_no text,
  receipt_date date not null default current_date,
  employee text,
  description text,
  status text not null default 'DRAFT' check(status in ('DRAFT','COMPLETED')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.receipt_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.receipts(id) on delete cascade,
  barcode text not null,
  product_code text,
  product_name text not null,
  quantity numeric not null,
  unit text not null check(unit in ('ADET','KOLI','KUTU')),
  conversion numeric not null default 1,
  total_units numeric not null,
  purchase_price numeric,
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;
alter table public.receipts enable row level security;
alter table public.receipt_lines enable row level security;
-- RLS politikaları Auth modeli netleştikten sonra eklenecek. Service role tarayıcıya konulmayacak.
