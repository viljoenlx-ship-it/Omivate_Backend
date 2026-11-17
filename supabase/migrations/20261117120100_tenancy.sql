-- Companies, branding, profile, platform staff, memberships and invites.

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  legal_name text not null,
  trading_name text not null,
  industry text,
  region text,
  status text not null default 'active' check (status in ('active', 'suspended', 'trial')),
  plan text not null default 'growth' check (plan in ('starter', 'growth', 'professional', 'enterprise')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenants_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

comment on table public.tenants is 'A tenant is one SME company on Omnivate.';

create table public.tenant_branding (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  display_name text not null,
  primary_color text not null default '#334155',
  accent_color text not null default '#0F172A',
  logo_url text,
  updated_at timestamptz not null default now(),
  constraint tenant_branding_primary_color check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  constraint tenant_branding_accent_color check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  constraint tenant_branding_logo_url_len check (logo_url is null or char_length(logo_url) <= 2000)
);

comment on table public.tenant_branding is
  'Control Centre branding: display name, colours and logo URL.';

create table public.tenant_profiles (
  tenant_id uuid primary key references public.tenants (id) on delete cascade,
  email text,
  phone text,
  website text,
  address1 text,
  address2 text,
  city text,
  postal_code text,
  province text,
  country text not null default 'South Africa',
  currency text not null default 'ZAR',
  fiscal_year_start text not null default '01 March',
  registration_number text,
  vat_number text,
  updated_at timestamptz not null default now()
);

comment on table public.tenant_profiles is 'Legal and contact profile for a tenant. VAT invoices arrive in a later phase.';

create table public.platform_staff (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.platform_role not null,
  created_at timestamptz not null default now()
);

comment on table public.platform_staff is
  'Omnivate Control Centre staff. owner and platform_admin can see every tenant.';

create table public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.tenant_role not null,
  status public.membership_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, user_id)
);

create index tenant_memberships_user_idx on public.tenant_memberships (user_id);

comment on table public.tenant_memberships is
  'Links a Supabase Auth user to one company and a tenant role.';

create table public.tenant_invites (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  email text not null,
  role public.tenant_role not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  invited_by uuid references auth.users (id),
  accepted_at timestamptz,
  accepted_user_id uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint tenant_invites_email_len check (char_length(email) between 3 and 320)
);

create index tenant_invites_email_idx on public.tenant_invites (lower(email));

comment on table public.tenant_invites is
  'First-user and later invites. Only a hash of the token is stored.';

create trigger tenants_touch
  before update on public.tenants
  for each row execute function internal.touch_updated_at();

create trigger tenant_branding_touch
  before update on public.tenant_branding
  for each row execute function internal.touch_updated_at();

create trigger tenant_profiles_touch
  before update on public.tenant_profiles
  for each row execute function internal.touch_updated_at();

create trigger tenant_memberships_touch
  before update on public.tenant_memberships
  for each row execute function internal.touch_updated_at();
