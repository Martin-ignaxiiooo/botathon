-- C-01 · Permisos para PostgREST con JWT (corre después de api.sql: 'zz' ordena al final).
-- PostgREST se conecta como web_lectura (authenticator y rol anónimo). Con un JWT {"role":"planificador"} firmado
-- con PGRST_JWT_SECRET hace SET ROLE planificador en esa petición. Para eso web_lectura debe ser miembro de
-- planificador, pero SIN heredar sus permisos (INHERIT FALSE, PG16): sin token sigue siendo solo lectura y no puede
-- ejecutar decidir_escenario().
GRANT planificador TO web_lectura WITH INHERIT FALSE, SET TRUE;

-- Con el token, el front lee las mismas vistas que sin token.
GRANT SELECT ON api.v_kpi, api.v_nacional_mes, api.v_instituto_area_mes,
    api.v_profesional_mes, api.v_cambios, api.v_errores_carga,
    api.v_parametros_vigentes, api.v_cuadratura TO planificador;
