-- =====================================================================
--  SCORVIA — Fənlər
--  Sınaqlar, materiallar, ev tapşırıqları və sual bankı fənnə bağlanır.
--  Fənlərin siyahısı saytda: assets/js/config.js → SUBJECTS
--  (Faylı ikinci dəfə işə salmaq təhlükəsizdir.)
-- =====================================================================

alter table public.tests         add column if not exists subject text;
alter table public.materials     add column if not exists subject text;
alter table public.homework      add column if not exists subject text;
alter table public.question_bank add column if not exists subject text;

do $$
declare t text;
begin
  foreach t in array array['tests', 'materials', 'homework', 'question_bank'] loop
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_subject_chk');
    execute format('alter table public.%I add constraint %I check (subject is null or subject ~ ''^[a-z]{1,12}$'')', t, t || '_subject_chk');
    execute format('create index if not exists %I on public.%I (subject)', t || '_subject_idx', t);
  end loop;
end $$;
