# GridRetail · Gestor de Locales (Gridtel)

App ligera para gestionar la adquisición de locales para agencias Movistar: mapa de zonas
priorizadas, capa de operadores (Movistar / Claro / Bitel / Entel), pipeline de locales
(recibido → evaluación → aceptado/descartado → agencia), scoring por ubicación y ficha PDF
para la KAM.

**Este repositorio solo contiene el cascarón de la app.** Toda la data (locales, fotos,
evidencia de mercado) vive en Supabase y requiere iniciar sesión. No subas a este repo
ningún archivo de datos (en particular `seed_confidencial.sql`).

## Puesta en marcha (una sola vez)

1. **Supabase**: crea un proyecto en supabase.com → SQL Editor → pega y ejecuta
   `setup/schema.sql`. Luego ejecuta el archivo `seed_confidencial.sql` (entregado por
   separado, NO está en el repo).
2. **Usuarios**: Dashboard → Authentication → Users → *Add user* (correo + contraseña)
   por cada colaborador. Para nombrar admin:
   `update public.profiles set rol='admin' where email='tucorreo@...';`
3. **Conectar la app**: edita `config.js` con la Project URL y la anon key
   (Dashboard → Settings → API).
4. **Publicar**: repo → Settings → Pages → *Deploy from a branch* → branch `main`, folder
   `/ (root)`. La app queda en `https://<usuario>.github.io/<repo>/`.
5. En Supabase → Authentication → URL Configuration, agrega esa URL como *Site URL*.

## Modo demo

Abre `index.html?demo=1` (o la URL publicada + `?demo=1`) para probar la interfaz sin
conexión a Supabase, con datos ficticios.

## Estructura

- `index.html` — toda la app (Leaflet + supabase-js, sin build).
- `config.js` — credenciales públicas del proyecto Supabase (anon key; la seguridad real
  la dan RLS + login).
- `vendor/` — librerías locales (sin CDN).
- `data/distritos.json` — límites distritales de Lima/Callao (dato público).
- `setup/schema.sql` — tablas, seguridad (RLS) y storage. Idempotente.

© Gridtel — uso interno.
