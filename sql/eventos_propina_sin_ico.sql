-- Eventos que aún no han pasado (fecha de hoy en adelante, hora Colombia) y que todavía usan el cálculo viejo
-- ("Servicio" sobre el total CON ICO) pasan al cálculo nuevo: "Propina voluntaria sugerida" sobre el total SIN ICO,
-- con la nota de la Ley 1935 de 2018. La propina se limita a 10 % (máximo legal).
-- No toca eventos pasados ni eventos sin fecha. No cambia el IVA de personal/extras (sigue como estaba).
-- No borra nada. Se puede correr más de una vez (la segunda vez no encuentra nada que cambiar).

update public.costeo_eventos
set version_calculo = 2,
    servicio_pct = least(servicio_pct, 10)
where version_calculo < 2
  and fecha >= (now() at time zone 'America/Bogota')::date
returning nombre, cliente, fecha, servicio_pct as propina_pct, estado;
