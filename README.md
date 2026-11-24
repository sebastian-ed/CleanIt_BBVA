# Clean It · Lavados BBVA V2
Frontend estático HTML/CSS/JS, Supabase Auth/Postgres/Storage y Edge Function Gemini. No depende de Apps Script.

## Instalación
1. Crear proyecto Supabase (recomendado separado de insumos). También se puede usar el mismo proyecto: todas las tablas y función tienen nombres independientes. Ejecutar `supabase/schema.sql` una sola vez en SQL Editor.
2. En Authentication > Users crear usuarios con correo/contraseña. Copiar UUID y ejecutar `insert into public.bbva_roles(user_id,role) values ('UUID','supervisor');` o `'operario'` según corresponda. No habilitar registros públicos si no se necesitan.
3. En config.js reemplazar URL y anon/publishable key del proyecto. Nunca pegar service role ni Gemini API key allí. Cupo 200 y tarifa inicial 14656 (tomada de la base; verificar contrato).
4. Desde terminal en la carpeta del proyecto: `npx supabase@latest login`, `npx supabase@latest link --project-ref TU_PROJECT_REF`, `npx supabase@latest secrets set GEMINI_API_KEY=TU_CLAVE`. Si ya existe en el mismo proyecto, no hace falta reemplazarla. Configurar `GEMINI_MODEL` con el modelo que esté funcionando en insumos; opcionalmente `GEMINI_FALLBACK_MODEL` con otro modelo habilitado en tu API. El valor predeterminado es gemini-2.5-flash, sujeto a disponibilidad. Si se comparte el proyecto, estos nombres de secretos podrían afectar insumos: preferir proyecto separado o conservar valores existentes.
5. `npx supabase@latest functions deploy analyze-bbva --no-verify-jwt`. La función verifica el token y rol internamente; no admite usuarios anónimos.
6. Publicar index.html, style.css, app.js, config.js en GitHub Pages o Netlify. No publicar secretos. Abrir por HTTPS para cámara. Probar con usuario operario y supervisor.

## Operación
Foto de inicio y foto de cierre por fecha. Se usa la última foto de cada momento; el cierre manda. Si Gemini falla, las fotos persisten y el supervisor puede reintentar o cargar filas manualmente. Revisión explícita antes de usar para facturar. Importe particulares = cantidad SI particular × tarifa del día. Abonados SI cuentan en cupo pero no generan importe particular. Exceso = max(0,total SI - 200). Extra estimado = exceso × tarifa extra introducida en navegador (no se suma al importe particular ni se factura automáticamente, para evitar doble cobro). Tarifa extra debe verificarse contra contrato. Los NO son cancelados/no realizados; desapariciones del inicio se muestran como alerta, no como cancelación definitiva. No se interpreta columna de importe: tarifa configurable por día.

## Alcance y limitaciones
- La versión guarda imágenes comprimidas en Storage privado y datos en Supabase; exporta detalle CSV para Sheets. **No incluye sincronización automática con Drive/Sheets**: queda pendiente configurar una integración corporativa autenticada. Si se requiere conservar el original sin compresión, modificar carga.
- Una foto completa por momento; las fotos posteriores reemplazan a la anterior como fuente, pero conservan historial en Storage. Si la planilla no entra en una foto, usar captura completa o carga manual. No deduplica filas automáticamente: revisar contra cierre.
- Reintentos por errores transitorios y modelo alternativo opcional. No elimina saturación del proveedor. Las llamadas pueden alcanzar límites de tiempo de Edge Functions.
- No se ha desplegado ni probado con credenciales reales; verificar RLS, login, Storage y lectura con planillas de prueba sin datos personales antes de producción. Confirmar autorización de BBVA para procesar fotos con Gemini y limitar datos visibles a los necesarios.
- No borrar datos históricos ni cambiar la tarifa sin revisar el contrato. Los totales incluyen lecturas pendientes de confirmar y se muestran como provisionales.
