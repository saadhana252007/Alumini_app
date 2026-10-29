-- Migration 0006_alumni_portal.sql
-- Enables Alumni features: Departments, Alumni Registry, Profile extension, Donation intents, and Activity logs

-- 1. Departments table
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text not null unique,
  created_at timestamptz not null default now()
);

-- Seed departments
insert into public.departments (name, code) values
  ('Applied Geology', 'AGL'),
  ('Applied Geophysics', 'AGP'),
  ('Chemical Engineering', 'CHE'),
  ('Civil Engineering', 'CIV'),
  ('Computer Science and Engineering', 'CSE'),
  ('Electrical Engineering', 'ELE'),
  ('Electronics Engineering', 'ECE'),
  ('Environmental Science and Engineering', 'ESE'),
  ('Fuel, Minerals and Metallurgical Engineering', 'FMME'),
  ('Humanities and Social Sciences', 'HSS'),
  ('Management Studies & Industrial Engineering', 'MSIE'),
  ('Mathematics and Computing', 'MNC'),
  ('Mechanical Engineering', 'MEC'),
  ('Mining Engineering', 'MIN'),
  ('Mining Machinery Engineering', 'MME'),
  ('Petroleum Engineering', 'PET'),
  ('Physics', 'PHY')
on conflict (code) do nothing;

-- 2. Alumni Registry (for auto verification matching)
create table if not exists public.alumni_registry (
  id uuid primary key default gen_random_uuid(),
  admission_no text not null unique,
  full_name text not null,
  batch_year int not null,
  department_code text not null,
  created_at timestamptz not null default now()
);

-- Seed a few sample records for testing auto-verification
insert into public.alumni_registry (admission_no, full_name, batch_year, department_code) values
  ('19JE0001', 'Arun Kumar', 2023, 'CSE'),
  ('18JE0542', 'Priya Sharma', 2022, 'ELE'),
  ('98JE0124', 'Rajesh Gupta', 2002, 'MIN'),
  ('86JE0045', 'Sanjay Verma', 1990, 'PET')
on conflict (admission_no) do nothing;

-- 3. Extend profiles table
alter table public.profiles 
  drop constraint if exists profiles_role_check;

alter table public.profiles 
  add constraint profiles_role_check check (role in ('edc_admin','dean_admin','super_admin','alumni'));

alter table public.profiles
  add column if not exists admission_no text,
  add column if not exists contact_no text,
  add column if not exists whatsapp_no text,
  add column if not exists department_id uuid references public.departments(id),
  add column if not exists batch_year int,
  add column if not exists current_position text,
  add column if not exists organisation text,
  add column if not exists address_line text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists country text default 'India',
  add column if not exists pincode text,
  add column if not exists photo_url text,
  add column if not exists verification_status text default 'pending' check (verification_status in ('pending','verified','rejected')),
  add column if not exists consent_at timestamptz;

-- 4. Extend notices table
alter table public.notices
  add column if not exists is_featured boolean not null default false,
  add column if not exists event_date timestamptz;

-- 5. Donation Intents table
create table if not exists public.donation_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  amount numeric(12,2) not null,
  currency text not null default 'INR',
  status text not null default 'redirected' check (status in ('redirected', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

-- 6. User Activity Log
create table if not exists public.user_activity_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  action_type text not null, -- 'registration', 'booking_requested', 'booking_approved', 'donation_intent', 'profile_updated'
  title text not null,
  description text not null,
  reference_id text,
  created_at timestamptz not null default now()
);

-- 7. App settings seeding
insert into public.app_settings (key, value) values
  ('donation_url', '"https://www.iitism.ac.in/donation"'::jsonb),
  ('centenary_content', '{"title": "100 Years of Excellence (1926–2026)", "tagline": "A Century of Mining, Technology & Heritage", "description": "Founded in 1926 by Lord Irwin, IIT (ISM) Dhanbad has pioneered mining and earth sciences education in India and evolved into a premier institute of national importance."}'::jsonb),
  ('tax_benefit_text', '"Donations to IIT (ISM) Dhanbad are eligible for 100% tax deduction under Section 80G of the Income Tax Act."'::jsonb)
on conflict (key) do nothing;

-- 8. Row Level Security for Alumni
alter table public.departments enable row level security;
create policy "Allow read access to departments" on public.departments
  for select using (true);

alter table public.alumni_registry enable row level security;
create policy "Allow read access to alumni registry for validation" on public.alumni_registry
  for select using (auth.role() = 'authenticated');

alter table public.donation_intents enable row level security;
create policy "Users can read and insert their own donation intents" on public.donation_intents
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.user_activity_log enable row level security;
create policy "Users can read their own activity" on public.user_activity_log
  for select using (user_id = auth.uid());
create policy "Users can insert their own activity" on public.user_activity_log
  for insert with check (user_id = auth.uid());

-- Extend booking requests policy so alumni can see and create their Category D bookings
drop policy if exists "Alumni can create Category D requests" on public.booking_requests;
create policy "Alumni can create Category D requests" on public.booking_requests
  for insert with check (
    auth.uid() is not null and 
    visitor_category = 'D'
  );

drop policy if exists "Alumni can read their own booking requests" on public.booking_requests;
create policy "Alumni can read their own booking requests" on public.booking_requests
  for select using (
    email = auth.jwt() ->> 'email' or 
    indenter_name = (select full_name from public.profiles where id = auth.uid()) or
    auth.role() = 'authenticated'
  );

-- 9. Published Notices Read Policy for Alumni and Mobile App
drop policy if exists "Allow read access to published notices" on public.notices;
create policy "Allow read access to published notices" on public.notices
  for select using (status = 'published');

-- Allow storage read access for notice images in storage.objects
drop policy if exists "Public read access to notice images" on storage.objects;
create policy "Public read access to notice images" on storage.objects
  for select using (bucket_id = 'notices');

-- 10. Self Profile Access Policy
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile" on public.profiles
  for insert with check (id = auth.uid());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update using (id = auth.uid());
