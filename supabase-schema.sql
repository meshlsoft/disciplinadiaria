-- Disciplina Diária: schema compartilhado com administrador e convidados somente leitura.
create extension if not exists pgcrypto;

create table if not exists public.trackers (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Disciplina Diária',
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.tracker_members (
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','viewer')),
  created_at timestamptz not null default now(),
  primary key (tracker_id,user_id)
);
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  name text not null,
  group_name text not null default 'Outras atividades',
  type text not null default 'yesno' check (type in ('yesno','duration','number','choice','counter')),
  config jsonb not null default '{}'::jsonb,
  position integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.daily_entries (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  entry_date date not null,
  value jsonb not null default '{"done":false,"comment":""}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (tracker_id,activity_id,entry_date)
);
create index if not exists daily_entries_tracker_date_idx on public.daily_entries(tracker_id,entry_date);
create index if not exists activities_tracker_position_idx on public.activities(tracker_id,position);

create or replace function public.is_tracker_member(tid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.tracker_members where tracker_id=tid and user_id=auth.uid()) $$;
create or replace function public.is_tracker_owner(tid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.tracker_members where tracker_id=tid and user_id=auth.uid() and role='owner') $$;
revoke all on function public.is_tracker_member(uuid) from public;
revoke all on function public.is_tracker_owner(uuid) from public;
grant execute on function public.is_tracker_member(uuid) to authenticated;
grant execute on function public.is_tracker_owner(uuid) to authenticated;

create or replace function public.create_personal_tracker()
returns uuid language plpgsql security definer set search_path=public,auth
as $$
declare tid uuid;
begin
  if auth.uid() is null then raise exception 'É necessário entrar na conta.'; end if;
  select tracker_id into tid from public.tracker_members where user_id=auth.uid() limit 1;
  if tid is not null then return tid; end if;
  insert into public.trackers(owner_id) values(auth.uid()) returning id into tid;
  insert into public.tracker_members(tracker_id,user_id,role) values(tid,auth.uid(),'owner');
  insert into public.activities(tracker_id,name,group_name,type,position) values
    (tid,'Oração a São Miguel','Orações','yesno',1),
    (tid,'Consagração a Nossa Senhora','Orações','yesno',2),
    (tid,'Leitura do Evangelho do dia','Orações','yesno',3),
    (tid,'Rezar o terço','Orações','yesno',4),
    (tid,'Oração antes de dormir','Orações','yesno',5),
    (tid,'Javé Nissi','Vida espiritual e comunitária','choice',6),
    (tid,'Missa','Vida espiritual e comunitária','yesno',7),
    (tid,'Confissão','Vida espiritual e comunitária','yesno',8),
    (tid,'Lectio Divina','Vida espiritual e comunitária','duration',9),
    (tid,'Leitura Vida de Santo','Vida espiritual e comunitária','duration',10),
    (tid,'Exame de consciência','Vida espiritual e comunitária','yesno',11);
  update public.activities set config='{"choices":["Abastecimento","Discipulado","Pequeno Grupo","Casa de Oração"]}'::jsonb where tracker_id=tid and name='Javé Nissi';
  return tid;
end $$;
grant execute on function public.create_personal_tracker() to authenticated;

-- O usuário convidado precisa primeiro existir em Authentication -> Users.
create or replace function public.add_tracker_viewer(viewer_email text)
returns void language plpgsql security definer set search_path=public,auth
as $$
declare tid uuid; target uuid;
begin
  select tracker_id into tid from public.tracker_members where user_id=auth.uid() and role='owner' limit 1;
  if tid is null then raise exception 'Somente o administrador pode convidar visualizadores.'; end if;
  select id into target from auth.users where lower(email)=lower(viewer_email) limit 1;
  if target is null then raise exception 'Este e-mail ainda não tem conta. Convide-o primeiro em Authentication -> Users.'; end if;
  insert into public.tracker_members(tracker_id,user_id,role) values(tid,target,'viewer')
  on conflict (tracker_id,user_id) do update set role='viewer';
end $$;
grant execute on function public.add_tracker_viewer(text) to authenticated;

alter table public.trackers enable row level security;
alter table public.tracker_members enable row level security;
alter table public.activities enable row level security;
alter table public.daily_entries enable row level security;

drop policy if exists tracker_read_member on public.trackers;
create policy tracker_read_member on public.trackers for select to authenticated using(public.is_tracker_member(id));
drop policy if exists member_list_self_or_owner on public.tracker_members;
create policy member_list_self_or_owner on public.tracker_members for select to authenticated using(user_id=auth.uid() or public.is_tracker_owner(tracker_id));
drop policy if exists activities_read_member on public.activities;
create policy activities_read_member on public.activities for select to authenticated using(public.is_tracker_member(tracker_id));
drop policy if exists activities_owner_insert on public.activities;
create policy activities_owner_insert on public.activities for insert to authenticated with check(public.is_tracker_owner(tracker_id));
drop policy if exists activities_owner_update on public.activities;
create policy activities_owner_update on public.activities for update to authenticated using(public.is_tracker_owner(tracker_id)) with check(public.is_tracker_owner(tracker_id));
drop policy if exists activities_owner_delete on public.activities;
create policy activities_owner_delete on public.activities for delete to authenticated using(public.is_tracker_owner(tracker_id));
drop policy if exists entries_read_member on public.daily_entries;
create policy entries_read_member on public.daily_entries for select to authenticated using(public.is_tracker_member(tracker_id));
drop policy if exists entries_owner_insert on public.daily_entries;
create policy entries_owner_insert on public.daily_entries for insert to authenticated with check(public.is_tracker_owner(tracker_id));
drop policy if exists entries_owner_update on public.daily_entries;
create policy entries_owner_update on public.daily_entries for update to authenticated using(public.is_tracker_owner(tracker_id)) with check(public.is_tracker_owner(tracker_id));
drop policy if exists entries_owner_delete on public.daily_entries;
create policy entries_owner_delete on public.daily_entries for delete to authenticated using(public.is_tracker_owner(tracker_id));

-- Membership is managed only by the SECURITY DEFINER invitation/bootstrap functions.
