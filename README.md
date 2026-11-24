# BBVA V5 — OCR automático y lectura de fotografías guardadas
Conservar config.js y las tablas existentes. Reemplazar index.html, style.css, app.js, ocr.js y supabase/functions/analyze-bbva/index.ts. Desplegar una vez:

`npx supabase@latest functions deploy analyze-bbva --no-verify-jwt --project-ref uzzbvirtxgqxwyxtmxal`

Publicar archivos frontend en GitHub Pages y recargar Ctrl+F5. No ejecutar SQL ni modificar usuarios. No publicar claves secretas.

## Operación
- Operario: al guardar cierre se ejecuta OCR local automáticamente sobre la misma foto y se envían las filas sugeridas a Supabase por la Edge Function autenticada. Mantener abierta la pestaña hasta terminar. Inicio se guarda como respaldo; el cierre manda. Si falla, la foto sigue guardada.
- Supervisor: elegir fecha y pulsar Leer cierre con OCR local: descarga el último cierre privado desde Supabase y genera filas automáticamente, sin subir otro archivo. Revisar cada fila y marcar Revisada; agregar faltantes, quitar falsos positivos y guardar revisión. No se debe confirmar sin comparar el total de filas contra la foto. Texto OCR visible temporalmente; no se almacena como texto completo.
- OCR realiza dos lecturas y elige por puntuación heurística. Reconoce filas por cochera aunque patente sea dudosa; conserva estado/tipo desconocidos como vacíos. Valores reconocidos en la parte posterior al tipo son sugerencias, no garantía. Valor vacío usa tarifa del día; abonados y NO siempre $0. Gemini sigue disponible como alternativa y admite valor por fila. Configuración de modelos de supervisor permanece local al navegador.
- La lectura automática no confirma los días. El supervisor revisa. Los totales de lecturas sin confirmar son provisorios. Se usa último cierre, no múltiples páginas.
- OCR no compara inicio/cierre ni garantiza recuperación de filas desplazadas. Gemini puede detectar diferencias si está disponible. Las fotos originales reales no fueron proporcionadas para calibrar. Backup Drive/Sheets aún pendiente. Los datos extraídos deben manejarse de acuerdo con permisos y confidencialidad del cliente.
