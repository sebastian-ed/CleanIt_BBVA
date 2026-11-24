# Clean It BBVA V7 — guardado y edición

Actualización de V6. Reemplazar index.html, app.js y style.css; conservar config.js y ocr.js. No hace falta desplegar Edge Function ni ejecutar SQL si la migración V6 se aplicó correctamente. Se incluye la migración V6 solo para reparar una instalación incompleta (por ejemplo si falta bbva_save_review_v6). No ejecutar schema.sql de versiones anteriores.

Publicar en GitHub y recargar con Ctrl+F5. Los cambios aún no guardados en la pestaña anterior no se migran automáticamente: intentar guardar borrador antes de actualizar.

Confirmar revisión guarda como borrador si hay filas pendientes, e informa cuántas faltan. Si todas están completas y revisadas, pide confirmación y guarda como confirmado. Verifica la escritura consultando nuevamente la base. En caso de error conserva el detalle visible y muestra el error junto al botón. Los días confirmados siguen editables: editar y guardar borrador o confirmar de nuevo. El botón Editar lleva al detalle. No se crean días duplicados. No modifica las fotos ni los permisos existentes.

Prueba: editar fila, guardar borrador, recargar, comprobar persistencia; completar y revisar filas, confirmar, recargar; editar un día confirmado y guardar otra vez. Si aparece error de RPC faltante ejecutar supabase/migration_v6.sql en el proyecto correcto. Prueba real en Supabase pendiente. No incluye backup Drive/Sheets.
