# Protección de datos · PlanBot

Documento de diseño para la demo, revisado al 7 de noviembre de 2026. El tratamiento debe tener una base habilitante y finalidad definidas; reemplazar identificadores no elimina por sí solo el carácter personal del dato. La Ley 19.628 vigente exige autorización legal o consentimiento en los casos que regula, finalidad, secreto y deber de cuidado; la selección de la base aplicable corresponde al responsable institucional. [BCN: Ley 19.628, versión vigente antes de diciembre de 2026](https://www.bcn.cl/leychile/Navegar?idNorma=141599&idVersion=2023-05-09).

La reforma de la Ley 21.719 entra en vigor el **1 de diciembre de 2026**; no se presenta como ya vigente a la fecha de este documento. El despliegue debe preparar su adaptación antes de operar bajo ese régimen. [BCN: Ley 21.719](https://www.leychile.cl/leychile/Navegar?idNorma=1209272&idParte=8).

## Controles del diseño y verificación necesaria

| Ámbito | Decisión de PlanBot | Qué verificar antes de operar |
|---|---|---|
| Mínimo de datos | persona_id es el único identificador de persona del motor; se conservan solo atributos de contrato, instituto y planificación necesarios. No se incorporan nombres, RUT ni datos de pacientes. Limpieza descarta Fecha de Nacimiento, Tipo_Trab_161225 y Reg_SIC. | Revisar también Excel originales, CSV temporales, colas, logs y respaldos. La copia idéntica D-04 no anonimiza el original. |
| Roles | owner_planbot administra; bot_carga carga/ejecuta las funciones autorizadas; web_lectura consulta vistas; planificador usa las operaciones aprobadas para su función. | Comprobar GRANT reales y permisos por instituto cuando corresponda. No usar owner_planbot en el navegador ni en el robot. El rol web_lectura por sí solo no identifica usuarios ni restringe institutos. |
| Autenticación y red | El acceso al tablero y API debe quedar en la red/entorno autorizado y aplicar autenticación institucional cuando corresponda. | No publicar vistas de profesionales mediante un endpoint anónimo accesible a Internet. Probar autorización por usuario/ámbito y conexiones cifradas fuera del host local. |
| Credenciales | PlanBot_Postgres en Credential Manager; Get Login añade usuario/clave al abrir conexión. .env local y protegido para servicios; sin secretos en Git. | Autorizar solo procesos/runtime necesarios, rotar claves y desactivar logging de parámetros sensibles. No incrustar claves de base ni JWT administrativos en JS. |
| Auditoría | carga_id, hash y estado de archivo; cambios antes/después y vigencia; motivo y versión de regla; auditoría SQL según contratos. | Comprobar quién puede leer/modificar logs, su conservación y la trazabilidad del usuario que aprueba. Un hash de archivo detecta igualdad; no cifra ni anonimiza. |
| Repositorio privado | Mantener el repositorio privado y con acceso limitado al equipo; compartir solo datos de ensayo autorizados. | Verificar la visibilidad real en el servidor Git antes de alojarlo; este trabajo solo tiene commits locales y no certifica que ya exista un remoto privado. Revisar historial además de archivos actuales. |
| Conservación | Acordar plazos para entradas, procesados, errores, colas, logs y backups; eliminar copias temporales según política. | El responsable debe fijar plazos y procedimiento de eliminación/restauración; no se impone aquí un número de días sin acuerdo. |
| Atención a titulares e incidentes | Definir un canal institucional para acceso/rectificación y escalamiento de incidentes. | Identificar responsable, procedimiento, plazos legales aplicables y gestión de proveedores antes del uso real. No poner esa decisión en un Code stage. |

## Pseudonimización y finalidad

persona_id puede relacionarse con una persona mediante otros sistemas: se trata como identificador pseudonimizado, **no como anonimización irreversible**. La finalidad del MVP es planificación de capacidad asistencial de profesionales. No reutilizar estos registros para fines ajenos ni agregar información clínica de niños, niñas o jóvenes al tablero de demostración.

La demo usa archivos de ensayo bajo acceso controlado. Si un archivo contiene datos reales o no se ha confirmado su autorización, sustituirlo por datos autorizados antes de proyectarlo o compartirlo. El código de limpieza reduce la carga al motor, pero no borra los campos del archivo recibido.

## Estado

Se han entregado código y guías para estos controles; aún deben comprobarse en infraestructura, permisos SQL, release Blue Prism y acceso al dashboard. Este documento no certifica cumplimiento integral. La habilitación de un entorno real requiere revisión del responsable institucional, incluyendo las obligaciones aplicables al momento de despliegue.
