-- =====================================================================
--  SCORVIA — Gündəlik məşq 2.0
--   • 100 suallıq baza (qrammatika kitabının mövzuları üzrə): hər gün 5 sual —
--     1 asan + 2 orta + 2 çətin; hər şagirdə ayrı, əvvəl görmədikləri suallar
--   • Sınaq kimi: 6 dəqiqə vaxt, səhifədən çıxmaq / köçürmə → BUGÜNKÜ məşq 0 bal
--     (hesab bloklanmır, sabah yenə iştirak edə bilər); müəllimə Telegram xəbəri
--  Əvvəlcə 32-practice-push.sql işə salınmış olmalıdır.
--  Supabase → SQL Editor → New query → hamısını yapışdır → Run
--  (Faylı ikinci dəfə işə salmaq təhlükəsizdir.)
-- =====================================================================

create table if not exists public.daily_questions (
  id         serial primary key,
  code       text unique,
  topic      text not null,
  level      text not null check (level in ('easy', 'medium', 'hard')),
  text       text not null check (char_length(text) <= 400),
  opts       jsonb not null,
  ans        int  not null,
  expl       text,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.daily_questions enable row level security;
drop policy if exists "dq_admin" on public.daily_questions;
create policy "dq_admin" on public.daily_questions for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.daily_questions from anon;

-- Scorvia: hazır suallar yoxdur — admin "Gündəlik məşq" bölməsindən öz suallarını əlavə edir.

alter table public.daily_sets add column if not exists started_at  timestamptz;
alter table public.daily_sets add column if not exists voided      boolean not null default false;
alter table public.daily_sets add column if not exists void_reason text;
alter table public.daily_sets add column if not exists qids        int[];

-- Vaxt: 5 sual üçün 6 dəqiqə
create or replace function public.daily_limit_sec()
returns int language sql immutable set search_path = '' as $$ select 360; $$;

-- Bugünkü 5 sual: 1 asan + 2 orta + 2 çətin (şagirdin ən az gördüyü suallardan)
create or replace function public.daily_make2(p_user uuid)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare v_out jsonb := '[]'::jsonb; v_ids int[] := '{}'; lv record; q record; v_order int[]; v_new jsonb; k int; v_n int;
begin
  if (select count(*) from public.daily_questions where active) < 5 then
    return jsonb_build_object('questions', public.daily_make(), 'qids', null);   -- baza boşdursa — köhnə üsul (sözlər + sual bankı)
  end if;
  for lv in select * from (values ('easy', 1, 1), ('medium', 2, 2), ('hard', 2, 3), ('any', 5, 4)) v(l, n, o) order by o loop
    for q in
      select dq.* from public.daily_questions dq
        left join (select x.qid, count(*) as n from public.daily_sets d, unnest(d.qids) as x(qid)
                    where d.user_id = p_user group by x.qid) s on s.qid = dq.id
       where dq.active and (lv.l = 'any' or dq.level = lv.l) and not (dq.id = any (v_ids))
       order by coalesce(s.n, 0), random()
       limit greatest(0, case when lv.l = 'any' then 5 - cardinality(v_ids) else lv.n end)
    loop
      v_n := jsonb_array_length(q.opts);
      select array_agg(g order by random()) into v_order from generate_series(1, v_n) g;
      v_new := '[]'::jsonb;
      for k in 1 .. v_n loop v_new := v_new || jsonb_build_array(q.opts -> (v_order[k] - 1)); end loop;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'k', 'q', 'id', q.id, 'topic', q.topic, 'level', q.level, 'text', q.text, 'opts', v_new,
        'ans', (array_position(v_order, q.ans + 1) - 1)::text, 'expl', q.expl));
      v_ids := v_ids || q.id;
    end loop;
  end loop;
  return jsonb_build_object('questions', v_out, 'qids', to_jsonb(v_ids));
end;
$$;
revoke execute on function public.daily_make2(uuid) from public, anon, authenticated;

create or replace function public.daily_streak(p_user uuid)
returns json
language sql stable security definer set search_path = ''
as $$
  with d as (select day from public.daily_sets where user_id = p_user and done_at is not null and not voided),
       g as (select day, day - (row_number() over (order by day))::int as grp from d),
       isl as (select max(day) as e, count(*) as n from g group by grp)
  select json_build_object(
    'current', coalesce((select n from isl where e >= public.baku_today() - 1 order by e desc limit 1), 0),
    'best',    coalesce((select max(n) from isl), 0),
    'total',   (select count(*) from d),
    'today',   exists (select 1 from d where day = public.baku_today()),
    'week',    (select json_agg(json_build_object('day', x::date, 'done', exists (select 1 from d where d.day = x::date)) order by x)
                  from generate_series(public.baku_today() - 6, public.baku_today(), interval '1 day') x));
$$;
revoke execute on function public.daily_streak(uuid) from public, anon, authenticated;

create or replace function public.daily_status()
returns json
language plpgsql stable security definer set search_path = ''
as $$
declare v_s public.daily_sets; v json;
begin
  if auth.uid() is null then return null; end if;
  select * into v_s from public.daily_sets where user_id = auth.uid() and day = public.baku_today();
  v := public.daily_streak(auth.uid());
  return (v::jsonb || jsonb_build_object('today_voided', coalesce(v_s.voided, false), 'void_reason', v_s.void_reason,
                                          'in_progress', v_s.started_at is not null and v_s.done_at is null))::json;
end;
$$;

-- Şagirdə göstərilən hal (cavablar yalnız bitəndən sonra; 0 bal alınıbsa — heç vaxt)
create or replace function public.daily_view(p_set public.daily_sets)
returns json
language sql stable security definer set search_path = ''
as $$
  select json_build_object(
    'day', p_set.day, 'done', p_set.done_at is not null,
    'started_at', p_set.started_at, 'limit', public.daily_limit_sec(),
    'left_ms', case when p_set.started_at is not null and p_set.done_at is null
                    then greatest(0, (extract(epoch from (p_set.started_at + make_interval(secs => public.daily_limit_sec()) - now())) * 1000)::bigint) end,
    'voided', p_set.voided, 'void_reason', p_set.void_reason,
    'questions', case when p_set.started_at is null and p_set.done_at is null then null   -- başlamamış — suallar görünmür
                      else (select coalesce(jsonb_agg(
                    (q - 'ans' - 'expl') || case when p_set.done_at is not null and not p_set.voided
                                        then jsonb_build_object('ans', q->'ans', 'expl', q->'expl', 'my', p_set.answers->((i - 1)::int), 'ok', p_set.results->((i - 1)::int))
                                        else '{}'::jsonb end order by i), '[]'::jsonb)
                    from jsonb_array_elements(p_set.questions) with ordinality as x(q, i)) end,
    'count', jsonb_array_length(p_set.questions),
    'levels', (select jsonb_agg(coalesce(q->>'level', 'medium') order by i) from jsonb_array_elements(p_set.questions) with ordinality as x(q, i)),
    'correct', p_set.correct, 'total', p_set.total,
    'streak', public.daily_streak(p_set.user_id));
$$;
revoke execute on function public.daily_view(public.daily_sets) from public, anon, authenticated;

-- Vaxtı keçmiş, bitirilməmiş məşqi bağla (0 bal, amma "köçürmə" sayılmır)
create or replace function public.daily_close_late(p_user uuid)
returns void
language sql security definer set search_path = ''
as $$
  update public.daily_sets
     set done_at = now(), correct = 0, total = jsonb_array_length(questions), answers = '[]'::jsonb,
         results = (select coalesce(jsonb_agg(false), '[]'::jsonb) from jsonb_array_elements(questions)),
         void_reason = 'Vaxt bitdi — cavablar göndərilmədi'
   where user_id = p_user and done_at is null and started_at is not null
     and now() > started_at + make_interval(secs => public.daily_limit_sec() + 60);
$$;
revoke execute on function public.daily_close_late(uuid) from public, anon, authenticated;

create or replace function public.daily_get()
returns json
language plpgsql security definer set search_path = ''
as $$
declare v_s public.daily_sets; v_p public.profiles; v_m jsonb;
begin
  select * into v_p from public.profiles where id = auth.uid();
  if not found or v_p.status <> 'approved' then raise exception 'Hesabın aktiv deyil'; end if;
  perform public.daily_close_late(v_p.id);
  select * into v_s from public.daily_sets where user_id = v_p.id and day = public.baku_today();
  if not found then
    v_m := public.daily_make2(v_p.id);
    insert into public.daily_sets (user_id, day, questions, qids)
    values (v_p.id, public.baku_today(), v_m->'questions',
            case when jsonb_typeof(v_m->'qids') = 'array' then array(select jsonb_array_elements_text(v_m->'qids')::int) end)
    on conflict do nothing;
    select * into v_s from public.daily_sets where user_id = v_p.id and day = public.baku_today();
  end if;
  if jsonb_array_length(v_s.questions) = 0 then
    delete from public.daily_sets where user_id = v_p.id and day = v_s.day and done_at is null;
    return json_build_object('empty', true, 'streak', public.daily_streak(v_p.id));
  end if;
  return public.daily_view(v_s);
end;
$$;

-- "Başla" düyməsi — vaxt buradan sayılır
create or replace function public.daily_start()
returns json
language plpgsql security definer set search_path = ''
as $$
declare v_s public.daily_sets;
begin
  update public.daily_sets set started_at = now()
   where user_id = auth.uid() and day = public.baku_today() and started_at is null and done_at is null;
  select * into v_s from public.daily_sets where user_id = auth.uid() and day = public.baku_today();
  if not found then raise exception 'Bugünkü məşq tapılmadı — səhifəni yenilə'; end if;
  return public.daily_view(v_s);
end;
$$;

-- Qayda pozuntusu: bugünkü məşq 0 bal ilə bağlanır (hesab BLOKLANMIR)
create or replace function public.daily_void(p_reason text)
returns json
language plpgsql security definer set search_path = ''
as $$
declare v_s public.daily_sets; v_p public.profiles;
begin
  select * into v_s from public.daily_sets where user_id = auth.uid() and day = public.baku_today() for update;
  if not found then return null; end if;
  if v_s.done_at is not null or v_s.started_at is null then return public.daily_view(v_s); end if;
  update public.daily_sets
     set done_at = now(), voided = true, void_reason = left(coalesce(nullif(trim(p_reason), ''), 'Qayda pozuntusu'), 200),
         correct = 0, total = jsonb_array_length(questions), answers = '[]'::jsonb,
         results = (select coalesce(jsonb_agg(false), '[]'::jsonb) from jsonb_array_elements(questions))
   where user_id = v_s.user_id and day = v_s.day
  returning * into v_s;
  select * into v_p from public.profiles where id = auth.uid();
  perform public.notify_telegram(format(E'🔥 <b>Gündəlik məşq — 0 bal</b>\n%s (%s)\n%s',
    public.tg_esc(v_p.full_name), public.tg_esc(coalesce(v_p.class_name, '')), public.tg_esc(v_s.void_reason)));
  return public.daily_view(v_s);
end;
$$;

create or replace function public.daily_submit(p_answers jsonb)
returns json
language plpgsql security definer set search_path = ''
as $$
declare v_s public.daily_sets; q jsonb; i int := 0; v_my text; v_ok boolean; v_res jsonb := '[]'::jsonb; v_c int := 0; alt text;
begin
  select * into v_s from public.daily_sets where user_id = auth.uid() and day = public.baku_today() for update;
  if not found then raise exception 'Bugünkü məşq tapılmadı — səhifəni yenilə'; end if;
  if v_s.done_at is not null then return public.daily_view(v_s); end if;
  if v_s.started_at is null then
    update public.daily_sets set started_at = now() where user_id = v_s.user_id and day = v_s.day returning * into v_s;
  end if;
  if now() > v_s.started_at + make_interval(secs => public.daily_limit_sec() + 45) then
    perform public.daily_close_late(v_s.user_id);
    update public.daily_sets set void_reason = 'Vaxt bitdi — cavablar gec göndərildi', done_at = coalesce(done_at, now()),
           correct = 0, total = jsonb_array_length(questions), answers = '[]'::jsonb,
           results = (select coalesce(jsonb_agg(false), '[]'::jsonb) from jsonb_array_elements(questions))
     where user_id = v_s.user_id and day = v_s.day returning * into v_s;
    return public.daily_view(v_s);
  end if;
  if jsonb_typeof(p_answers) <> 'array' then raise exception 'Cavablar düzgün deyil'; end if;
  for q in select value from jsonb_array_elements(v_s.questions) loop
    v_my := left(trim(coalesce(p_answers->>i, '')), 120);
    v_ok := false;
    if q->'opts' is null or jsonb_typeof(q->'opts') = 'null' then
      foreach alt in array string_to_array(q->>'ans', '/') loop
        if public.practice_norm(alt) <> '' and public.practice_norm(alt) = public.practice_norm(v_my) then v_ok := true; end if;
      end loop;
    else
      v_ok := v_my <> '' and v_my = q->>'ans';
    end if;
    v_res := v_res || to_jsonb(v_ok);
    if v_ok then v_c := v_c + 1; end if;
    i := i + 1;
  end loop;
  update public.daily_sets
     set answers = (select coalesce(jsonb_agg(left(trim(coalesce(p_answers->>(g - 1), '')), 120) order by g), '[]'::jsonb)
                      from generate_series(1, jsonb_array_length(v_s.questions)) g),
         results = v_res, correct = v_c, total = jsonb_array_length(v_s.questions), done_at = now()
   where user_id = v_s.user_id and day = v_s.day
  returning * into v_s;
  return public.daily_view(v_s);
end;
$$;
revoke execute on function public.daily_start()          from public, anon;
revoke execute on function public.daily_void(text)       from public, anon;
grant  execute on function public.daily_start()          to authenticated;
grant  execute on function public.daily_void(text)       to authenticated;

-- Səhvlər dəftəri, mövzular, valideyn hesabatı: 0 bal alınmış (pozuntulu) günlər sayılmır
create or replace function public.my_mistakes()
returns json
language plpgsql stable security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid(); v_out jsonb := '[]'::jsonb; r record; q jsonb; o jsonb; v_key jsonb; v_on public.test_online;
        n text; v_pass jsonb; v_found boolean; d record; i int; L text := 'ABCDE';
begin
  if v_uid is null then return '[]'::json; end if;
  -- sınaqlar (yalnız nəticəsi açılmışlar)
  for r in
    select t.id, t.title, t.questions, t.pdf_path, x.answers, x.details, x.variant, x.at_
      from (select test_id, answers, details, variant, coalesce(submitted_at, started_at) as at_
              from public.attempts where user_id = v_uid and status <> 'in_progress'
            union all
            select test_id, answers, details, variant, created_at from public.paper_entries where user_id = v_uid) x
      join public.tests t on t.id = x.test_id
     where t.results_released and x.details is not null
     order by x.at_ desc limit 40
  loop
    v_key := public.variant_key(r.id, r.variant);
    select * into v_on from public.test_online where test_id = r.id;
    v_found := found;
    for q in select value from jsonb_array_elements(r.questions) loop
      continue when q->>'type' = 'essay';
      n := q->>'n';
      continue when coalesce((r.details->n->>'frac')::numeric, 0) >= 1;
      continue when exists (select 1 from public.mistake_fixed f where f.user_id = v_uid and f.src = 'test' and f.ref = r.id::text and f.qn = n::int);
      o := null; v_pass := null;
      if v_found then
        select e into o from jsonb_array_elements(v_on.questions) e where e->>'n' = n limit 1;
        if o ? 'pid' then
          select jsonb_build_object('title', p->>'title', 'text', left(p->>'text', 4000)) into v_pass
            from jsonb_array_elements(v_on.passages) p where p->>'id' = o->>'pid' limit 1;
        end if;
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'src', 'test', 'ref', r.id, 'title', r.title, 'at', r.at_, 'n', n::int,
        'type', q->>'type', 'options', coalesce(q->>'options', 'ABCDE'), 'parts', q->'parts',
        'my', r.answers->>n, 'key', v_key->>n,
        'text', o->>'text', 'opts', o->'opts', 'passage', v_pass));
      exit when jsonb_array_length(v_out) >= 200;
    end loop;
    exit when jsonb_array_length(v_out) >= 200;
  end loop;
  -- gündəlik məşq
  for d in select day, questions, answers, results from public.daily_sets
            where user_id = v_uid and done_at is not null and not voided order by day desc limit 60 loop
    i := 0;
    for q in select value from jsonb_array_elements(d.questions) loop
      if coalesce((d.results->>i)::boolean, true) = false
         and not exists (select 1 from public.mistake_fixed f where f.user_id = v_uid and f.src = 'daily' and f.ref = d.day::text and f.qn = i) then
        v_out := v_out || jsonb_build_array(jsonb_build_object(
          'src', 'daily', 'ref', d.day::text, 'title', 'Gündəlik məşq', 'at', d.day, 'n', i,
          'type', case when q->'opts' is null or jsonb_typeof(q->'opts') = 'null' then 'open' else 'choice' end,
          'options', substr(L, 1, greatest(2, coalesce(jsonb_array_length(case when jsonb_typeof(q->'opts') = 'array' then q->'opts' end), 0))),
          'my', case when jsonb_typeof(q->'opts') = 'array' and coalesce(d.answers->>i, '') ~ '^\d$'
                     then substr(L, (d.answers->>i)::int + 1, 1) else d.answers->>i end,
          'key', case when jsonb_typeof(q->'opts') = 'array' then substr(L, (q->>'ans')::int + 1, 1) else q->>'ans' end,
          'text', q->>'text', 'opts', case when jsonb_typeof(q->'opts') = 'array' then q->'opts' end, 'topic', q->>'topic', 'expl', q->>'expl'));
      end if;
      i := i + 1;
    end loop;
    exit when jsonb_array_length(v_out) >= 260;
  end loop;
  return v_out;
end;
$$;

create or replace function public.topic_facts(p_user uuid, p_from timestamptz default null, p_to timestamptz default null)
returns table (user_id uuid, topic text, frac numeric)
language sql stable security definer set search_path = ''
as $$
  with res as (
    select a.user_id, a.test_id, a.details, coalesce(a.submitted_at, a.started_at) as at_
      from public.attempts a where a.status <> 'in_progress' and a.details is not null
    union all
    select p.user_id, p.test_id, p.details, p.created_at
      from public.paper_entries p where p.user_id is not null and p.details is not null
  ), t as (
    select id, questions,
           case when jsonb_typeof(content->'topics') = 'array' and jsonb_array_length(content->'topics') > 0 then content->'topics'
                when jsonb_typeof(content->'sections') = 'array' then content->'sections' else '[]'::jsonb end as tp
      from public.tests where results_released or results_mode = 'instant'
  )
  select r.user_id, trim(tpc->>'name'), least(1, greatest(0, coalesce((r.details -> (q->>'n') ->> 'frac')::numeric, 0)))
    from res r join t on t.id = r.test_id
    cross join jsonb_array_elements(t.tp) tpc
    cross join jsonb_array_elements(t.questions) q
   where (q->>'n')::int between (tpc->>'from')::int and (tpc->>'to')::int
     and q->>'type' <> 'essay' and r.details ? (q->>'n')
     and (p_user is null or r.user_id = p_user)
     and (p_from is null or r.at_ >= p_from) and (p_to is null or r.at_ < p_to)
  union all
  select d.user_id, coalesce(q->>'topic', 'Sözlər'), case when (d.results->>((i - 1)::int))::boolean then 1 else 0 end
    from public.daily_sets d
    cross join jsonb_array_elements(d.questions) with ordinality as x(q, i)
   where d.done_at is not null and not d.voided
     and (p_user is null or d.user_id = p_user)
     and (p_from is null or d.done_at >= p_from) and (p_to is null or d.done_at < p_to);
$$;

create or replace function public.parent_month(p_code text, p_month date default null)
returns json
language plpgsql stable security definer set search_path = ''
as $$
declare v_p public.profiles; v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
        v_m date := date_trunc('month', coalesce(p_month, public.baku_today()))::date;
        v_from timestamptz; v_to timestamptz; v_pfrom timestamptz;
begin
  if length(v_code) <> 10 then raise exception 'Kod düzgün deyil'; end if;
  select * into v_p from public.profiles
   where replace(parent_code, '-', '') = v_code and role = 'student' and status in ('approved', 'blocked');
  if not found then raise exception 'Kod tapılmadı'; end if;
  v_from  := v_m::timestamp at time zone 'Asia/Baku';
  v_to    := (v_m + interval '1 month')::timestamp at time zone 'Asia/Baku';
  v_pfrom := (v_m - interval '1 month')::timestamp at time zone 'Asia/Baku';

  return (with res as (
      select a.user_id, a.test_id, a.score, coalesce(a.submitted_at, a.started_at) as at_, a.status
        from public.attempts a where a.status <> 'in_progress'
      union all
      select p.user_id, p.test_id, p.score, p.created_at, p.status from public.paper_entries p where p.user_id is not null
    ), scored as (
      select r.*, t.title, public.test_total(t.questions) as total, pr.class_name
        from res r join public.tests t on t.id = r.test_id join public.profiles pr on pr.id = r.user_id
       where (t.results_released or t.results_mode = 'instant') and r.score is not null and public.test_total(t.questions) > 0
    )
    select json_build_object(
      'name', v_p.full_name, 'class', v_p.class_name, 'month', v_m,
      'tests', (select coalesce(json_agg(json_build_object('title', title, 'date', at_, 'pct', round(score / total * 100)) order by at_), '[]'::json)
                  from scored where user_id = v_p.id and at_ >= v_from and at_ < v_to),
      'avg', (select round(avg(score / total * 100)) from scored where user_id = v_p.id and at_ >= v_from and at_ < v_to),
      'prev_avg', (select round(avg(score / total * 100)) from scored where user_id = v_p.id and at_ >= v_pfrom and at_ < v_from),
      'class_avg', (select round(avg(score / total * 100)) from scored where class_name = v_p.class_name and at_ >= v_from and at_ < v_to),
      'attendance', (select json_build_object('present', count(*) filter (where status = 'present'), 'late', count(*) filter (where status = 'late'),
                                              'absent', count(*) filter (where status = 'absent'), 'excused', count(*) filter (where status = 'excused'))
                       from public.attendance where user_id = v_p.id and att_date >= v_m and att_date < (v_m + interval '1 month')::date),
      'homework', (select json_build_object('given', count(*), 'done', count(s.id), 'avg', round(avg(s.grade / nullif(h.max_points, 0) * 100)))
                     from public.homework h left join public.hw_submissions s on s.homework_id = h.id and s.user_id = v_p.id
                    where h.is_published and h.created_at >= v_from and h.created_at < v_to and public.target_ok(h.target_classes, v_p.class_name)),
      'live', (select json_build_object('games', count(*), 'points', coalesce(sum(score), 0))
                 from public.live_players where user_id = v_p.id and joined_at >= v_from and joined_at < v_to),
      'daily', (select json_build_object('days', count(*), 'correct', coalesce(sum(correct), 0), 'total', coalesce(sum(total), 0),
                                        'voided', (select count(*) from public.daily_sets x where x.user_id = v_p.id and x.voided and x.day >= v_m and x.day < (v_m + interval '1 month')::date))
                  from public.daily_sets where user_id = v_p.id and done_at is not null and not voided and day >= v_m and day < (v_m + interval '1 month')::date),
      'streak', public.daily_streak(v_p.id),
      'topics', public.topics_of(v_p.id)));
end;
$$;
