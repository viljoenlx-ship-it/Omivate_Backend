-- Shop-floor production: settings, blocks, cuts, slabs, job cards.
-- Measures follow the prototype:
--   block m³ = L cm × W cm × H cm / 1_000_000
--   tons     = m³ × 3.65
--   cost     = m³ × m³ cost
--   cut m²   = (L/100) × (W/100) × qty
--   cut m³   = m² × (T/100)
--   slab m²  = L mm × W mm / 1_000_000
--   job m²   = (L/100) × (W/100) × qty
--   job m³   = m² × (T/100)

create table public.quarries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, code)
);

create table public.materials (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, name)
);

create table public.machines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null,
  kind public.machine_kind not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, name)
);

create table public.operators (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.polish_grades (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  code text not null,
  label text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, code)
);

comment on table public.polish_grades is
  'Per-tenant polish grades. New tenants start with CL, C and UP.';

create table public.production_blocks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  block_code text not null,
  order_no text,
  order_date date not null default current_date,
  customer_name text,
  quarry_id uuid references public.quarries (id),
  material_id uuid references public.materials (id),
  length_cm numeric(10, 2) not null,
  width_cm numeric(10, 2) not null,
  height_cm numeric(10, 2) not null,
  m3 numeric(14, 4) generated always as (
    round((length_cm * width_cm * height_cm) / 1000000.0, 4)
  ) stored,
  tons numeric(14, 4) generated always as (
    round(
      round((length_cm * width_cm * height_cm) / 1000000.0, 4) * internal.stone_density(),
      4
    )
  ) stored,
  m3_cost numeric(14, 2) not null default 0,
  block_cost numeric(14, 2) generated always as (
    round(
      round((length_cm * width_cm * height_cm) / 1000000.0, 4) * m3_cost,
      2
    )
  ) stored,
  collected_on date,
  truck text,
  delivery_note text,
  location text,
  stage public.block_stage not null default 'ordered',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, block_code),
  constraint production_blocks_dimensions_positive check (
    length_cm > 0 and width_cm > 0 and height_cm > 0
  ),
  constraint production_blocks_code_format check (
    block_code ~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,40}$'
  )
);

create index production_blocks_stage_idx on public.production_blocks (tenant_id, stage);

comment on table public.production_blocks is
  'A quarry block. m³, tons and block cost are stored generated columns.';
comment on column public.production_blocks.m3 is 'L × W × H / 1e6, centimetres.';
comment on column public.production_blocks.tons is 'm³ × 3.65.';
comment on column public.production_blocks.block_cost is 'm³ × m³ cost.';

create table public.block_cuts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  block_id uuid not null references public.production_blocks (id) on delete cascade,
  cut_date date not null default current_date,
  department public.cut_department not null,
  machine_id uuid references public.machines (id),
  operator_id uuid references public.operators (id),
  qty integer not null,
  length_cm numeric(10, 2) not null,
  width_cm numeric(10, 2) not null,
  thickness_cm numeric(10, 2) not null,
  m2 numeric(14, 4) generated always as (
    round((length_cm / 100.0) * (width_cm / 100.0) * qty, 4)
  ) stored,
  m3 numeric(14, 4) generated always as (
    round((length_cm / 100.0) * (width_cm / 100.0) * qty * (thickness_cm / 100.0), 4)
  ) stored,
  wires integer,
  amps numeric(10, 2),
  rate numeric(10, 2),
  wire_speed numeric(10, 2),
  bead_mm numeric(10, 2),
  new_wire boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint block_cuts_qty_positive check (qty > 0),
  constraint block_cuts_dimensions_positive check (
    length_cm > 0 and width_cm > 0 and thickness_cm > 0
  ),
  constraint block_cuts_wire_params check (
    department <> 'multiwire'
    or (
      wires is not null
      and amps is not null
      and rate is not null
      and wire_speed is not null
      and bead_mm is not null
      and new_wire is not null
    )
  )
);

comment on table public.block_cuts is
  'Blade or multiwire cut. Multiwire rows must carry wire parameters.';

create table public.slabs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  block_id uuid not null references public.production_blocks (id) on delete cascade,
  slab_no integer not null,
  barcode text not null unique,
  polished_on date,
  machine_id uuid references public.machines (id),
  operator_id uuid references public.operators (id),
  length_mm numeric(10, 2),
  width_mm numeric(10, 2),
  thickness_mm numeric(10, 2),
  grade_id uuid references public.polish_grades (id),
  m2 numeric(14, 4) generated always as (
    case
      when length_mm is null or width_mm is null then null
      else round(length_mm * width_mm / 1000000.0, 4)
    end
  ) stored,
  comments text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (block_id, slab_no),
  constraint slabs_no_positive check (slab_no > 0),
  constraint slabs_polish_dimensions check (
    (length_mm is null and width_mm is null and thickness_mm is null)
    or (length_mm > 0 and width_mm > 0 and thickness_mm > 0)
  )
);

comment on table public.slabs is
  'One slab from a block. Barcode is block code, a hyphen, and n (blockID-n).';
comment on column public.slabs.barcode is 'Scannable id, for example GW-B204-1.';
comment on column public.slabs.m2 is 'L mm × W mm / 1e6 once the slab is measured for polish.';

create table public.cut_jobs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  slab_id uuid not null references public.slabs (id) on delete cascade,
  job_date date not null default current_date,
  machine_id uuid references public.machines (id),
  job_type public.job_type not null,
  length_cm numeric(10, 2) not null,
  width_cm numeric(10, 2) not null,
  thickness_cm numeric(10, 2) not null,
  qty integer not null,
  grade_id uuid references public.polish_grades (id),
  m2 numeric(14, 4) generated always as (
    round((length_cm / 100.0) * (width_cm / 100.0) * qty, 4)
  ) stored,
  m3 numeric(14, 4) generated always as (
    round((length_cm / 100.0) * (width_cm / 100.0) * (thickness_cm / 100.0) * qty, 4)
  ) stored,
  waste_pct numeric(6, 2) not null default 0,
  sales_order_no text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cut_jobs_qty_positive check (qty > 0),
  constraint cut_jobs_dimensions_positive check (
    length_cm > 0 and width_cm > 0 and thickness_cm > 0
  ),
  constraint cut_jobs_waste_range check (waste_pct >= 0 and waste_pct <= 100)
);

comment on table public.cut_jobs is 'Cut-to-size job card taken from a source slab.';

create index quarries_tenant_idx on public.quarries (tenant_id);
create index materials_tenant_idx on public.materials (tenant_id);
create index machines_tenant_idx on public.machines (tenant_id);
create index operators_tenant_idx on public.operators (tenant_id);
create index polish_grades_tenant_idx on public.polish_grades (tenant_id);
create index block_cuts_block_idx on public.block_cuts (block_id);
create index slabs_block_idx on public.slabs (block_id);
create index cut_jobs_slab_idx on public.cut_jobs (slab_id);

create trigger quarries_touch before update on public.quarries
  for each row execute function internal.touch_updated_at();
create trigger materials_touch before update on public.materials
  for each row execute function internal.touch_updated_at();
create trigger machines_touch before update on public.machines
  for each row execute function internal.touch_updated_at();
create trigger operators_touch before update on public.operators
  for each row execute function internal.touch_updated_at();
create trigger polish_grades_touch before update on public.polish_grades
  for each row execute function internal.touch_updated_at();
create trigger production_blocks_touch before update on public.production_blocks
  for each row execute function internal.touch_updated_at();
create trigger block_cuts_touch before update on public.block_cuts
  for each row execute function internal.touch_updated_at();
create trigger slabs_touch before update on public.slabs
  for each row execute function internal.touch_updated_at();
create trigger cut_jobs_touch before update on public.cut_jobs
  for each row execute function internal.touch_updated_at();

-- Keep child rows inside the parent block's company.
create or replace function internal.bind_block_child()
returns trigger
language plpgsql
as $$
declare
  parent_tenant uuid;
  parent_code text;
begin
  select tenant_id, block_code
    into parent_tenant, parent_code
  from public.production_blocks
  where id = new.block_id;

  if parent_tenant is null then
    raise exception 'block not found' using errcode = '23503';
  end if;
  if new.tenant_id is distinct from parent_tenant then
    raise exception 'tenant_id must match the block' using errcode = '42501';
  end if;

  if tg_table_name = 'slabs' then
    new.barcode := parent_code || '-' || new.slab_no::text;
  end if;
  return new;
end;
$$;

create trigger block_cuts_bind
  before insert or update of tenant_id, block_id on public.block_cuts
  for each row execute function internal.bind_block_child();

create trigger slabs_bind
  before insert or update of tenant_id, block_id, slab_no on public.slabs
  for each row execute function internal.bind_block_child();

create or replace function internal.bind_job_slab()
returns trigger
language plpgsql
as $$
declare
  parent_tenant uuid;
begin
  select tenant_id into parent_tenant from public.slabs where id = new.slab_id;
  if parent_tenant is null then
    raise exception 'slab not found' using errcode = '23503';
  end if;
  if new.tenant_id is distinct from parent_tenant then
    raise exception 'tenant_id must match the slab' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger cut_jobs_bind
  before insert or update of tenant_id, slab_id on public.cut_jobs
  for each row execute function internal.bind_job_slab();

create or replace function internal.guard_block_stage()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.stage is distinct from old.stage then
    if internal.next_stage(old.stage) is distinct from new.stage then
      raise exception 'stage can only advance one step' using errcode = '42501';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger production_blocks_stage
  before update on public.production_blocks
  for each row execute function internal.guard_block_stage();

create or replace function internal.guard_tenant_id()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger quarries_tenant_guard
  before update on public.quarries
  for each row execute function internal.guard_tenant_id();
create trigger materials_tenant_guard
  before update on public.materials
  for each row execute function internal.guard_tenant_id();
create trigger machines_tenant_guard
  before update on public.machines
  for each row execute function internal.guard_tenant_id();
create trigger operators_tenant_guard
  before update on public.operators
  for each row execute function internal.guard_tenant_id();
create trigger polish_grades_tenant_guard
  before update on public.polish_grades
  for each row execute function internal.guard_tenant_id();
create trigger block_cuts_tenant_guard
  before update on public.block_cuts
  for each row execute function internal.guard_tenant_id();
create trigger slabs_tenant_guard
  before update on public.slabs
  for each row execute function internal.guard_tenant_id();
create trigger cut_jobs_tenant_guard
  before update on public.cut_jobs
  for each row execute function internal.guard_tenant_id();

create or replace function internal.refs_on_block()
returns trigger
language plpgsql
as $$
declare
  found uuid;
begin
  if new.quarry_id is not null then
    select tenant_id into found from public.quarries where id = new.quarry_id;
    if found is distinct from new.tenant_id then
      raise exception 'quarry belongs to another tenant' using errcode = '42501';
    end if;
  end if;
  if new.material_id is not null then
    select tenant_id into found from public.materials where id = new.material_id;
    if found is distinct from new.tenant_id then
      raise exception 'material belongs to another tenant' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create or replace function internal.refs_on_cut()
returns trigger
language plpgsql
as $$
declare
  found uuid;
  machine_kind public.machine_kind;
begin
  if new.machine_id is not null then
    select tenant_id, kind into found, machine_kind from public.machines where id = new.machine_id;
    if found is distinct from new.tenant_id then
      raise exception 'machine belongs to another tenant' using errcode = '42501';
    end if;
    if machine_kind::text is distinct from new.department::text then
      raise exception 'machine kind must match the cut department' using errcode = '42501';
    end if;
  end if;
  if new.operator_id is not null then
    select tenant_id into found from public.operators where id = new.operator_id;
    if found is distinct from new.tenant_id then
      raise exception 'operator belongs to another tenant' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create or replace function internal.refs_on_slab_or_job()
returns trigger
language plpgsql
as $$
declare
  found uuid;
begin
  if new.machine_id is not null then
    select tenant_id into found from public.machines where id = new.machine_id;
    if found is distinct from new.tenant_id then
      raise exception 'machine belongs to another tenant' using errcode = '42501';
    end if;
  end if;
  if tg_table_name = 'slabs' then
    if new.operator_id is not null then
      select tenant_id into found from public.operators where id = new.operator_id;
      if found is distinct from new.tenant_id then
        raise exception 'operator belongs to another tenant' using errcode = '42501';
      end if;
    end if;
  end if;
  if new.grade_id is not null then
    select tenant_id into found from public.polish_grades where id = new.grade_id;
    if found is distinct from new.tenant_id then
      raise exception 'grade belongs to another tenant' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger production_blocks_refs
  before insert or update on public.production_blocks
  for each row execute function internal.refs_on_block();
create trigger block_cuts_refs
  before insert or update on public.block_cuts
  for each row execute function internal.refs_on_cut();
create trigger slabs_refs
  before insert or update on public.slabs
  for each row execute function internal.refs_on_slab_or_job();
create trigger cut_jobs_refs
  before insert or update on public.cut_jobs
  for each row execute function internal.refs_on_slab_or_job();

-- Defaults (modules, branding, CL/C/UP grades) once polish_grades exists.
create trigger tenants_seed_defaults
  after insert on public.tenants
  for each row execute function internal.seed_tenant_defaults();
