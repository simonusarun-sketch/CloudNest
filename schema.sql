-- CloudNest schema for Supabase. Run once: Supabase Dashboard > SQL Editor > New query > paste > Run.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  created_at timestamptz not null default now()
);

create table public.files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  original_filename text not null,
  title text not null,
  description text not null default '',
  file_type text not null check (file_type in ('pdf','jpg','jpeg','png','webp','doc','docx','ppt','pptx','txt')),
  file_size bigint not null check (file_size > 0 and file_size <= 26214400),
  storage_path text not null unique,
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (storage_path like user_id::text || '/%')
);
create index files_user_idx on public.files(user_id, created_at desc);

create table public.trash (
  file_id uuid primary key references public.files(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  deleted_at timestamptz not null default now()
);

-- Triggers
create function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger files_updated before update on public.files
  for each row execute function public.set_updated_at();

create function public.check_quota() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select coalesce(sum(file_size),0) from public.files where user_id = new.user_id) + new.file_size > 10737418240 then
    raise exception 'Storage quota exceeded';
  end if;
  return new;
end $$;
create trigger files_quota before insert on public.files
  for each row execute function public.check_quota();

create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'name',''), lower(new.raw_user_meta_data->>'username'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper functions used by the login / signup screens
create function public.username_available(u text) returns boolean
  language sql security definer set search_path = '' stable as $$
  select not exists (select 1 from public.profiles where username = lower(u)) $$;

create function public.email_for_login(ident text) returns text
  language sql security definer set search_path = '' stable as $$
  select au.email from public.profiles p join auth.users au on au.id = p.id where p.username = lower(ident) $$;

grant execute on function public.username_available(text), public.email_for_login(text) to anon, authenticated;

-- Row Level Security: every row is only visible to its owner
alter table public.profiles enable row level security;
alter table public.files    enable row level security;
alter table public.trash    enable row level security;
revoke all on public.profiles, public.files, public.trash from anon;

create policy "own profile read"   on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "own files read"   on public.files for select to authenticated using (user_id = (select auth.uid()));
create policy "own files insert" on public.files for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own files update" on public.files for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own files delete" on public.files for delete to authenticated using (user_id = (select auth.uid()));

create policy "own trash read"   on public.trash for select to authenticated using (user_id = (select auth.uid()));
create policy "own trash insert" on public.trash for insert to authenticated with check (
  user_id = (select auth.uid()) and exists (select 1 from public.files f where f.id = file_id and f.user_id = (select auth.uid())));
create policy "own trash delete" on public.trash for delete to authenticated using (user_id = (select auth.uid()));

-- Private storage bucket (25 MB per file, allowed types only)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values (
  'files', 'files', false, 26214400,
  array['application/pdf','image/jpeg','image/png','image/webp','application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Users can only touch objects inside their own folder: <user_id>/<file>
create policy "own objects read"   on storage.objects for select to authenticated using (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own objects insert" on storage.objects for insert to authenticated with check (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own objects delete" on storage.objects for delete to authenticated using (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
