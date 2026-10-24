-- Módulo Horarios — paso 11: salario fijo y valor de la hora con las horas legales. Correr después de horarios_1 a 10.
-- No borra datos; se puede correr más de una vez.
--
-- Decisiones de Miguel (24 oct 2026):
--  * Los líderes de salario fijo NO reciben horas extra ni recargos (cargos de dirección, confianza y manejo).
--    Se marca por persona en Horarios → Configuración → Personal ("Salario fijo").
--  * Valor de la hora = salario ÷ horas legales del mes. Con la jornada de 42 h: 7 h × 30 días = 210 (antes quedó en 180).

alter table public.horario_personal add column if not exists salario_fijo boolean not null default false;

alter table public.horario_config alter column horas_mes set default 210;
update public.horario_config set horas_mes = 210 where horas_mes = 180;

notify pgrst, 'reload schema';

-- Debe mostrar las horas al mes en 210
select a.name as area, c.horas_mes from public.horario_config c join public.areas a on a.id = c.area_id;
