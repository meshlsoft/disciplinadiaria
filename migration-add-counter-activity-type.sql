-- Permite o novo tipo de atividade Contador no banco já existente.
-- Execute uma única vez no Supabase SQL Editor.
alter table public.activities
  drop constraint if exists activities_type_check;

alter table public.activities
  add constraint activities_type_check
  check (type in ('yesno', 'duration', 'number', 'choice', 'counter'));
