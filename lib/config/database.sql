-- Create profiles table if not exists
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  name text,
  surname text,
  patronymic text,
  phone text,
  updated_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security if not enabled
alter table public.profiles enable row level security;

-- Drop existing policies if they exist
drop policy if exists "Users can view their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
drop policy if exists "Users can insert their own profile" on public.profiles;

-- Create policies
create policy "Users can view their own profile"
  on public.profiles for select
  using ( auth.uid() = id );

create policy "Users can update their own profile"
  on public.profiles for update
  using ( auth.uid() = id );

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check ( auth.uid() = id ); 