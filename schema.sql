-- =====================================================================
-- GridRetail (Gridtel) - Esquema Supabase
-- Ejecutar UNA VEZ en: Supabase Dashboard -> SQL Editor -> New query
-- =====================================================================

-- ---------- PERFILES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  nombre text,
  rol text not null default 'editor' check (rol in ('admin','editor')),
  created_at timestamptz default now()
);

-- auto-crear perfil al registrarse un usuario
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, nombre)
  values (new.id, new.email, split_part(new.email,'@',1))
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and rol = 'admin') $$;

-- ---------- DATA DE ANALISIS (confidencial, solo lectura desde la app) ----------
create table if not exists public.clusters (
  id serial primary key,
  nombre text unique not null,
  macrozona text, recomendacion text, fase_sugerida text, racional text,
  score numeric, ss_mejor numeric, mejor_tienda text,
  sat_movistar text, sat_claro text, coment_competencia text,
  renta_rango text, renta_m2 text, renta_confianza text, coment_renta text,
  evidencia text, n_tiendas int, lat numeric, lon numeric
);

create table if not exists public.tiendas_tex (
  id serial primary key,
  nombre text unique not null,
  distrito text, eje text, direccion text, socio text, pdv int, status_jul25 text,
  lat numeric, lon numeric, confianza text,
  ss_mayo numeric, ss_junio numeric,
  fraude boolean default false, modulo boolean default false,
  pbd boolean default false, cerrada boolean default false,
  vigente boolean default true,
  cluster_nombre text, notas text
);

create table if not exists public.operadores (
  id serial primary key,
  operador text not null check (operador in ('Movistar','Claro','Bitel','Entel')),
  tipo text, nombre text not null, direccion text, distrito text,
  lat numeric, lon numeric, confianza text, fuente text,
  activo boolean default true,
  creado_por uuid references public.profiles(id),
  updated_at timestamptz default now()
);

-- ---------- PIPELINE DE LOCALES ----------
create table if not exists public.locales (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  created_by uuid references public.profiles(id),
  updated_at timestamptz default now(),
  estado text not null default 'recibido'
    check (estado in ('recibido','evaluacion','aceptado','descartado','agencia')),
  nombre text not null,
  direccion text, distrito text,
  lat numeric, lon numeric, link_maps text,
  descripcion text, caracteristicas text, area_m2 numeric,
  precio_soles numeric, garantia_soles numeric, adelanto_meses numeric, plazo_meses int,
  corredora text, contacto text,
  notas_internas text,
  senales jsonb not null default '{}'::jsonb,
  operadores_cerca jsonb not null default '{}'::jsonb,
  score numeric, score_detalle jsonb,
  cluster_nombre text
);

create table if not exists public.local_media (
  id uuid primary key default gen_random_uuid(),
  local_id uuid not null references public.locales(id) on delete cascade,
  tipo text check (tipo in ('foto','video')),
  origen text default 'corredora' check (origen in ('corredora','pbd')),
  path text not null,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

create table if not exists public.local_eventos (
  id bigserial primary key,
  local_id uuid not null references public.locales(id) on delete cascade,
  estado_anterior text, estado_nuevo text, motivo text,
  user_id uuid, user_email text,
  created_at timestamptz default now()
);

create table if not exists public.trafico (
  id bigserial primary key,
  local_id uuid not null references public.locales(id) on delete cascade,
  fecha date not null,
  franja text not null,
  conteo int not null,
  minutos int not null default 15,
  medido_por text, notas text,
  created_at timestamptz default now()
);

create table if not exists public.app_config (
  key text primary key,
  value jsonb not null
);
insert into public.app_config (key, value) values
  ('pesos_scoring', '{"entorno":30,"trafico":25,"senales":20,"operadores":15,"condiciones":10}')
  on conflict (key) do nothing;

-- ---------- SEGURIDAD (RLS): todo requiere sesion iniciada ----------
alter table public.profiles      enable row level security;
alter table public.clusters      enable row level security;
alter table public.tiendas_tex   enable row level security;
alter table public.operadores    enable row level security;
alter table public.locales       enable row level security;
alter table public.local_media   enable row level security;
alter table public.local_eventos enable row level security;
alter table public.trafico       enable row level security;
alter table public.app_config    enable row level security;

-- lectura: cualquier usuario autenticado
create policy "read_profiles"  on public.profiles      for select to authenticated using (true);
create policy "read_clusters"  on public.clusters      for select to authenticated using (true);
create policy "read_tex"       on public.tiendas_tex   for select to authenticated using (true);
create policy "read_oper"      on public.operadores    for select to authenticated using (true);
create policy "read_locales"   on public.locales       for select to authenticated using (true);
create policy "read_media"     on public.local_media   for select to authenticated using (true);
create policy "read_eventos"   on public.local_eventos for select to authenticated using (true);
create policy "read_trafico"   on public.trafico       for select to authenticated using (true);
create policy "read_config"    on public.app_config    for select to authenticated using (true);

-- escritura del pipeline: autenticados
create policy "ins_locales"  on public.locales       for insert to authenticated with check (true);
create policy "upd_locales"  on public.locales       for update to authenticated using (true);
create policy "ins_media"    on public.local_media   for insert to authenticated with check (true);
create policy "ins_eventos"  on public.local_eventos for insert to authenticated with check (true);
create policy "ins_trafico"  on public.trafico       for insert to authenticated with check (true);
create policy "ins_oper"     on public.operadores    for insert to authenticated with check (true);
create policy "upd_oper"     on public.operadores    for update to authenticated using (true);
create policy "upd_profile_self" on public.profiles  for update to authenticated using (id = auth.uid());

-- borrado y configuracion: solo admin
create policy "del_locales"  on public.locales       for delete to authenticated using (public.is_admin());
create policy "del_media"    on public.local_media   for delete to authenticated using (public.is_admin());
create policy "del_trafico"  on public.trafico       for delete to authenticated using (public.is_admin());
create policy "del_oper"     on public.operadores    for delete to authenticated using (public.is_admin());
create policy "upd_config"   on public.app_config    for update to authenticated using (public.is_admin());
create policy "adm_profiles" on public.profiles      for update to authenticated using (public.is_admin());

-- ---------- STORAGE (fotos/videos) ----------
insert into storage.buckets (id, name, public) values ('media','media', false)
  on conflict (id) do nothing;
create policy "media_read"   on storage.objects for select to authenticated using (bucket_id = 'media');
create policy "media_insert" on storage.objects for insert to authenticated with check (bucket_id = 'media');
create policy "media_delete" on storage.objects for delete to authenticated using (bucket_id = 'media' and public.is_admin());

-- =====================================================================
-- LISTO. Luego ejecuta el archivo seed_confidencial.sql (entregado aparte,
-- NO lo subas a GitHub) para cargar microclusters, tiendas TEX y operadores.
-- Para nombrar un admin (reemplaza el correo):
--   update public.profiles set rol='admin' where email='luismartin@gmail.com';
-- =====================================================================
