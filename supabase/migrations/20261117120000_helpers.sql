-- Omnivate phase 1: types and private helpers.
-- Helper functions live in schema internal so PostgREST does not publish them.

create schema if not exists internal;

revoke all on schema internal from public;
grant usage on schema internal to postgres, service_role, authenticated;

comment on schema internal is
  'Private helpers for RLS and triggers. Not exposed by the Data API.';

-- Density used for block tons. The prototype uses a single factor, not a per-material density.
create or replace function internal.stone_density()
returns numeric
language sql
immutable
as $$
  select 3.65::numeric;
$$;

create or replace function internal.jsonb_diff(old_data jsonb, new_data jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  result jsonb := '{}'::jsonb;
  key text;
  keys text[];
begin
  select coalesce(array_agg(k), '{}')
    into keys
  from (
    select jsonb_object_keys(coalesce(old_data, '{}'::jsonb)) as k
    union
    select jsonb_object_keys(coalesce(new_data, '{}'::jsonb))
  ) s;

  foreach key in array keys loop
    if (old_data -> key) is distinct from (new_data -> key) then
      result := result || jsonb_build_object(
        key,
        jsonb_build_object('old', old_data -> key, 'new', new_data -> key)
      );
    end if;
  end loop;
  return result;
end;
$$;

create or replace function internal.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(auth.jwt(), '{}'::jsonb);
$$;

create or replace function internal.jwt_text(claim text)
returns text
language sql
stable
as $$
  select nullif(internal.jwt() ->> claim, '');
$$;

create or replace function internal.jwt_uuid(claim text)
returns uuid
language plpgsql
stable
as $$
declare
  raw text;
begin
  raw := internal.jwt_text(claim);
  if raw is null then
    return null;
  end if;
  return raw::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

create or replace function internal.has_aal2()
returns boolean
language sql
stable
as $$
  select internal.jwt_text('aal') = 'aal2';
$$;

create type public.platform_role as enum ('owner', 'platform_admin');
create type public.tenant_role as enum ('tenant_admin', 'manager', 'operator', 'viewer');
create type public.membership_status as enum ('active', 'suspended');
create type public.block_stage as enum (
  'ordered', 'collected', 'received', 'cutting', 'polishing', 'done'
);
create type public.cut_department as enum ('blades', 'multiwire');
create type public.machine_kind as enum ('blades', 'multiwire', 'cts');
create type public.job_type as enum ('benchtop', 'splashback', 'island', 'vanity');

create or replace function internal.next_stage(current_stage public.block_stage)
returns public.block_stage
language sql
immutable
as $$
  select case current_stage
    when 'ordered' then 'collected'::public.block_stage
    when 'collected' then 'received'::public.block_stage
    when 'received' then 'cutting'::public.block_stage
    when 'cutting' then 'polishing'::public.block_stage
    when 'polishing' then 'done'::public.block_stage
    else null
  end;
$$;

create or replace function internal.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
