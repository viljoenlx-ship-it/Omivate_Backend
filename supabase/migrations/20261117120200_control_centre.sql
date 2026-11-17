-- Control Centre: module catalogue, per-tenant switches, feature flags, column visibility.
-- Catalogue codes M01–M41 mirror the prototype. The shop-floor Production workbook
-- is gated by tenant_features.production, which the Control Centre toggles separately
-- from generic manufacturing (M31).

create table public.modules (
  code text primary key,
  area text not null,
  name text not null,
  description text not null,
  sort_order integer not null
);

comment on table public.modules is 'Product module catalogue shown in the Control Centre.';

create table public.tenant_modules (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  module_code text not null references public.modules (code),
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, module_code)
);

comment on table public.tenant_modules is 'Per-tenant module on/off switch.';

create table public.tenant_features (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  camera_scan boolean not null default false,
  handheld_scan boolean not null default true,
  production boolean not null default false,
  timesheets boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint tenant_features_handheld_always_on check (handheld_scan)
);

comment on table public.tenant_features is
  'Prototype feature switches. production gates the shop-floor workbook. handheld_scan stays on.';

create table public.screen_columns (
  id text primary key,
  module_code text not null,
  screen text not null,
  column_key text not null,
  label text not null,
  data_type text not null,
  sort_order integer not null,
  required boolean not null default false,
  unique (module_code, screen, column_key)
);

comment on table public.screen_columns is
  'Columns the Control Centre can show, hide, rename or reorder per tenant.';

create table public.tenant_column_settings (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  column_id text not null references public.screen_columns (id),
  visible boolean not null default true,
  display_label text,
  sort_order integer,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, column_id)
);

comment on table public.tenant_column_settings is
  'Per-tenant column visibility, label and order. Missing rows mean visible.';

insert into public.modules (code, area, name, description, sort_order) values
  ('M01', 'System', 'Multi-company', 'Legal entities, group structure and per-company settings.', 1),
  ('M02', 'System', 'Users & security', 'Users, roles, permissions and company access.', 2),
  ('M03', 'System', 'Number sequences', 'Automatic document numbering.', 3),
  ('M04', 'System', 'Multi-currency', 'Currencies and exchange rates. ZAR is the example base currency.', 4),
  ('M05', 'System', 'Tax', 'Tax codes used on sales, purchases and journals. VAT 15% is the example standard rate.', 5),
  ('M06', 'System', 'Fiscal calendar', 'Accounting years and periods, including close and lock.', 6),
  ('M07', 'System', 'Notifications', 'In-app, email and SMS notifications.', 7),
  ('M08', 'System', 'Approvals & workflows', 'Reusable workflows and the live approval queue.', 8),
  ('M09', 'System', 'Document management', 'Central document library and version history.', 9),
  ('M10', 'System', 'Integrations', 'External system connections and API logs.', 10),
  ('M11', 'System', 'Audit & parameters', 'Audit trail and global system parameters.', 11),
  ('M12', 'Finance', 'Financials', 'General ledger, journals and financial statements.', 12),
  ('M13', 'Finance', 'Cost centres', 'Cost and profit centres for departmental analysis.', 13),
  ('M14', 'Finance', 'Budgeting', 'Budget versions, lines and budget-versus-actual.', 14),
  ('M15', 'Finance', 'Cash book & banking', 'Bank accounts, statements and reconciliations.', 15),
  ('M16', 'Finance', 'Cash flow', 'Actual and forecast cash movement.', 16),
  ('M17', 'Finance', 'Accounts receivable', 'Customer receipts, allocations and aging.', 17),
  ('M18', 'Finance', 'Accounts payable', 'Supplier payments, allocations and aging.', 18),
  ('M19', 'Finance', 'Tax returns', 'Tax return boxes. A VAT 201-style layout is used as a South African example.', 19),
  ('M20', 'Finance', 'Fixed assets', 'Fixed asset register, depreciation and disposals.', 20),
  ('M21', 'Finance', 'Petty cash', 'Petty cash vouchers.', 21),
  ('M22', 'Sales', 'Sales', 'Customers, pricing, quotes, orders, deliveries, invoicing, returns and commissions.', 22),
  ('M23', 'CRM & Marketing', 'CRM', 'Leads, opportunities and sales activities.', 23),
  ('M24', 'CRM & Marketing', 'Marketing', 'Campaigns, members and marketing lists.', 24),
  ('M25', 'Retail & E-commerce', 'POS / Retail', 'Stores, tills, POS receipts, promotions and loyalty.', 25),
  ('M26', 'Retail & E-commerce', 'E-commerce', 'Web and marketplace channels, catalogues, carts and orders.', 26),
  ('M27', 'Procurement', 'Procurement', 'Suppliers, requisitions, RFQs, purchase orders, goods receipts and supplier invoices.', 27),
  ('M28', 'Procurement', 'Contracts', 'Supplier blanket and term contracts.', 28),
  ('M29', 'Inventory & Warehouse', 'Inventory', 'Items, warehouses, stock on hand, movements, lots/serials and stock takes.', 29),
  ('M30', 'Inventory & Warehouse', 'Warehouse management', 'Bins, putaway, picking, packing and shipping.', 30),
  ('M31', 'Manufacturing & Quality', 'Manufacturing', 'BOMs, routings, work centres, MRP, work orders and production output.', 31),
  ('M32', 'Manufacturing & Quality', 'Quality', 'Inspection plans, inspections, non-conformance, CAPA and certificates.', 32),
  ('M33', 'Projects & Time', 'Project management', 'Projects, tasks, resources, costs and billing milestones.', 33),
  ('M34', 'Projects & Time', 'Timesheets', 'Employee timesheets and time entry against projects or jobs.', 34),
  ('M35', 'Service & Assets', 'Field service', 'Service contracts, field jobs, visits and parts used.', 35),
  ('M36', 'Service & Assets', 'Maintenance', 'Maintainable assets, schedules, requests and maintenance work orders.', 36),
  ('M37', 'Service & Assets', 'Fleet', 'Vehicles, trip logbook, fuel and vehicle services.', 37),
  ('M38', 'HR & Payroll', 'Human resources', 'Employees, leave, attendance, recruitment, training and performance.', 38),
  ('M39', 'HR & Payroll', 'Payroll', 'Payroll runs, payslips and pay-component transactions.', 39),
  ('M40', 'Support & Documents', 'Helpdesk', 'Support tickets, activities, knowledge base and SLA policies.', 40),
  ('M41', 'Support & Documents', 'Contracts', 'Commercial contracts register and obligations.', 41);

insert into public.screen_columns
  (id, module_code, screen, column_key, label, data_type, sort_order, required)
values
  ('production.blocks.order_date', 'production', 'blocks', 'order_date', 'Date', 'date', 10, true),
  ('production.blocks.customer_name', 'production', 'blocks', 'customer_name', 'Customer', 'text', 20, false),
  ('production.blocks.quarry', 'production', 'blocks', 'quarry', 'Quarry', 'text', 30, true),
  ('production.blocks.material', 'production', 'blocks', 'material', 'Material', 'text', 40, true),
  ('production.blocks.block_code', 'production', 'blocks', 'block_code', 'Block', 'text', 50, true),
  ('production.blocks.order_no', 'production', 'blocks', 'order_no', 'Order', 'text', 60, false),
  ('production.blocks.dimensions', 'production', 'blocks', 'dimensions', 'L×W×H', 'text', 70, true),
  ('production.blocks.m3', 'production', 'blocks', 'm3', 'm³', 'decimal', 80, true),
  ('production.blocks.tons', 'production', 'blocks', 'tons', 'Tons', 'decimal', 90, false),
  ('production.blocks.m3_cost', 'production', 'blocks', 'm3_cost', 'm³ cost', 'currency', 100, false),
  ('production.blocks.block_cost', 'production', 'blocks', 'block_cost', 'Block cost', 'currency', 110, false),
  ('production.blocks.collected_on', 'production', 'blocks', 'collected_on', 'Collected', 'date', 120, false),
  ('production.blocks.truck', 'production', 'blocks', 'truck', 'Truck', 'text', 130, false),
  ('production.blocks.delivery_note', 'production', 'blocks', 'delivery_note', 'Del. note', 'text', 140, false),
  ('production.blocks.location', 'production', 'blocks', 'location', 'Location', 'text', 150, false),
  ('production.blocks.stage', 'production', 'blocks', 'stage', 'Status', 'enum', 160, true),
  ('production.cutting.cut_date', 'production', 'cutting', 'cut_date', 'Date', 'date', 10, true),
  ('production.cutting.block_code', 'production', 'cutting', 'block_code', 'Block', 'text', 20, true),
  ('production.cutting.machine', 'production', 'cutting', 'machine', 'Machine', 'text', 30, true),
  ('production.cutting.qty', 'production', 'cutting', 'qty', 'Qty', 'integer', 40, true),
  ('production.cutting.dimensions', 'production', 'cutting', 'dimensions', 'L×W×T cm', 'text', 50, true),
  ('production.cutting.m2', 'production', 'cutting', 'm2', 'm²', 'decimal', 60, true),
  ('production.cutting.m3', 'production', 'cutting', 'm3', 'm³', 'decimal', 70, true),
  ('production.cutting.waste_pct', 'production', 'cutting', 'waste_pct', 'Waste', 'percent', 80, false),
  ('production.cutting.wires', 'production', 'cutting', 'wires', 'Wires', 'integer', 90, false),
  ('production.cutting.amps', 'production', 'cutting', 'amps', 'Amps', 'decimal', 100, false),
  ('production.cutting.rate', 'production', 'cutting', 'rate', 'Rate', 'decimal', 110, false),
  ('production.cutting.wire_speed', 'production', 'cutting', 'wire_speed', 'Wire speed', 'decimal', 120, false),
  ('production.cutting.bead_mm', 'production', 'cutting', 'bead_mm', 'Bead mm', 'decimal', 130, false),
  ('production.cutting.new_wire', 'production', 'cutting', 'new_wire', 'New wire', 'boolean', 140, false),
  ('production.polishing.polished_on', 'production', 'polishing', 'polished_on', 'Date', 'date', 10, false),
  ('production.polishing.machine', 'production', 'polishing', 'machine', 'Dept', 'text', 20, false),
  ('production.polishing.barcode', 'production', 'polishing', 'barcode', 'Slab', 'text', 30, true),
  ('production.polishing.dimensions', 'production', 'polishing', 'dimensions', 'L×W×T mm', 'text', 40, true),
  ('production.polishing.grade', 'production', 'polishing', 'grade', 'Grade', 'enum', 50, true),
  ('production.polishing.m2', 'production', 'polishing', 'm2', 'm²', 'decimal', 60, true),
  ('production.polishing.comments', 'production', 'polishing', 'comments', 'Comments', 'text', 70, false),
  ('production.polishing.operator', 'production', 'polishing', 'operator', 'Operator', 'text', 80, false),
  ('production.jobs.job_date', 'production', 'jobs', 'job_date', 'Date', 'date', 10, true),
  ('production.jobs.barcode', 'production', 'jobs', 'barcode', 'Source slab', 'text', 20, true),
  ('production.jobs.machine', 'production', 'jobs', 'machine', 'Machine', 'text', 30, true),
  ('production.jobs.job_type', 'production', 'jobs', 'job_type', 'Type', 'enum', 40, true),
  ('production.jobs.dimensions', 'production', 'jobs', 'dimensions', 'L×W×T', 'text', 50, true),
  ('production.jobs.qty', 'production', 'jobs', 'qty', 'Qty', 'integer', 60, true),
  ('production.jobs.grade', 'production', 'jobs', 'grade', 'Grade', 'enum', 70, false),
  ('production.jobs.m2', 'production', 'jobs', 'm2', 'm²', 'decimal', 80, true),
  ('production.jobs.m3', 'production', 'jobs', 'm3', 'm³', 'decimal', 90, true),
  ('production.jobs.waste_pct', 'production', 'jobs', 'waste_pct', 'Waste', 'percent', 100, false),
  ('production.jobs.sales_order_no', 'production', 'jobs', 'sales_order_no', 'SO', 'text', 110, false),
  ('production.recovery.block_code', 'production', 'recovery', 'block_code', 'Block', 'text', 10, true),
  ('production.recovery.qty_cut', 'production', 'recovery', 'qty_cut', 'Qty cut', 'integer', 20, true),
  ('production.recovery.m2_cut', 'production', 'recovery', 'm2_cut', 'm² cut', 'decimal', 30, true),
  ('production.recovery.qty_polished', 'production', 'recovery', 'qty_polished', 'Qty polished', 'integer', 40, true),
  ('production.recovery.m2_polished', 'production', 'recovery', 'm2_polished', 'm² polished', 'decimal', 50, true),
  ('production.recovery.recovery_pct', 'production', 'recovery', 'recovery_pct', 'Recovery', 'percent', 60, true),
  ('production.recovery.waste_pct', 'production', 'recovery', 'waste_pct', 'Waste', 'percent', 70, true);

create trigger tenant_modules_touch
  before update on public.tenant_modules
  for each row execute function internal.touch_updated_at();

create trigger tenant_features_touch
  before update on public.tenant_features
  for each row execute function internal.touch_updated_at();

create trigger tenant_column_settings_touch
  before update on public.tenant_column_settings
  for each row execute function internal.touch_updated_at();

-- New companies start with the prototype core set, production off, grades ready.
create or replace function internal.seed_tenant_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  core text[] := array[
    'M01','M02','M03','M04','M05','M06','M07','M08','M11','M12',
    'M09','M15','M17','M18','M22','M23','M27','M29','M30'
  ];
begin
  insert into public.tenant_branding (tenant_id, display_name)
  values (new.id, new.trading_name)
  on conflict (tenant_id) do nothing;

  insert into public.tenant_profiles (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  insert into public.tenant_features (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;

  insert into public.tenant_modules (tenant_id, module_code, enabled)
  select new.id, m.code, m.code = any (core)
  from public.modules m
  on conflict (tenant_id, module_code) do nothing;

  insert into public.polish_grades (tenant_id, code, label, sort_order)
  values
    (new.id, 'CL', 'CL', 1),
    (new.id, 'C', 'C', 2),
    (new.id, 'UP', 'UP', 3)
  on conflict (tenant_id, code) do nothing;

  return new;
end;
$$;
