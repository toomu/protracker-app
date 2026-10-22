-- ProTracker (hosted at protracker.indexhomes.in): where each person's ProTracker data lives in Supabase.
-- Same shape as the claude.ai artifact's per-user collection: one row per document. Task documents use the
-- task id; the people list, saved tags, tag categories and team ticks are the documents _people, _tags,
-- _tagcats and _team. Run once in the SQL Editor (safe to run again). Needs team/schema.sql first.
create table if not exists public.pt_docs (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (char_length(id) between 1 and 200),
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.pt_docs enable row level security;

-- Each person reads and writes only their own documents.
drop policy if exists "own docs: read" on public.pt_docs;
create policy "own docs: read" on public.pt_docs for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "own docs: add" on public.pt_docs;
create policy "own docs: add" on public.pt_docs for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "own docs: change" on public.pt_docs;
create policy "own docs: change" on public.pt_docs for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "own docs: remove" on public.pt_docs;
create policy "own docs: remove" on public.pt_docs for delete to authenticated using (user_id = (select auth.uid()));

-- Live updates between devices (rows still filtered by the policies above).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'pt_docs'
  ) then
    alter publication supabase_realtime add table public.pt_docs;
  end if;
end $$;
