# Clean It BBVA V8 — gestión de días y auditoría
Actualización sobre V7. Conservar config.js y las credenciales actuales. Antes de actualizar, guardar los cambios pendientes y realizar un backup de la base.

## Instalación (en este orden)
1. En el SQL Editor del proyecto BBVA, ejecutar completo `supabase/migration_v8.sql`. Es una migración incremental, no ejecutar el schema de instalación ni borrar tablas. Requiere la RPC `bbva_save_review_v6` ya operativa. Crea el historial, archivo recuperable y permisos.
2. Reemplazar `index.html`, `app.js`, `style.css` y `supabase/functions/analyze-bbva/index.ts`. Conservar `config.js`; `ocr.js` no cambia.
3. Desde la carpeta del proyecto: `npx supabase@latest functions deploy analyze-bbva --no-verify-jwt --project-ref uzzbvirtxgqxwyxtmxal` (verificar que sea el proyecto correcto). La función conserva la comprobación interna de Auth y agrega atribución de auditoría.
4. `git add .`, `git commit -m "V8 gestion de dias y auditoria"`, `git push`. Abrir app y Ctrl+F5.

## Uso
- Supervisor: Agregar día crea un registro manual sin fotografía; agregar filas y guardar como en V7. Cambiar fecha mueve los metadatos de fotos y el detalle; no modifica la ruta física del archivo. No permite mover a una fecha ocupada.
- Eliminar día exige motivo y escribir ELIMINAR. Retira los registros activos y los excluye del resumen; conserva copia de datos y fotografías privadas. Desde Historial puede restaurarse si la fecha está libre. No es borrado físico ni libera espacio.
- El gráfico muestra particulares realizados (rosa), abonados realizados (azul oscuro) y realizados sin clasificar (ocre). Cada segmento tiene tooltip; no incluye cancelados.
- Historial: triggers registran cambios persistidos de bbva_days y bbva_photos con fecha/hora, sesión, usuario, navegador/sistema y datos antes/después. Eventos adicionales de UI: login, logout explícito, CSV, OCR, Gemini y selección de modelo (best effort). Los eventos anteriores a V8 no pueden reconstruirse; los cambios no guardados, cierres de pestaña y fallos de red no se auditan exhaustivamente. Los operarios ingresan nombre declarado y tienen sesión anónima, sin identidad verificada. No se captura número de serie, ubicación ni MAC. Los datos de auditoría y archivo solo los leen supervisores. No hay eliminación física desde la UI. Revisar retención y privacidad de snapshots.
- Pruebas recomendadas: crear día manual, guardar y recargar; mover a fecha libre; eliminar con motivo y comprobar totales; cargar foto nueva en fecha liberada; restaurar un día sin conflicto; verificar que el operario anónimo no pueda leer historial ni ejecutar RPC de gestión. Comprobar el historial de carga, revisión y eliminación. Validación local de sintaxis JS y ZIP; SQL y Edge Function no ejecutados contra Supabase real.
- Backup externo Drive/Sheets continúa pendiente. CAPTCHA y límites de carga pública siguen recomendados.
