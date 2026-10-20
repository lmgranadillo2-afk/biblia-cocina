-- Recetario de barra — Canta Corazón
-- 24 subrecetas (SUBB, con su rendimiento) + 196 productos de carta (CS, rinden 1 UN).
-- Área "Barra" de: canta-corazon-mtdsga9t. No borra nada: si un código ya existe en esa área, no se duplica.
--
-- Correcciones aplicadas al listado (aprobadas por Miguel):
--   - TG.JAGERMAISTER (CC1101) venía sin cantidad → 45 ML, como los demás tragos
--   - CORDIAL JAMAICA SPICY (SUBB003): el CHILE ARBOL venía sin código → se carga con código SINCODIGO (corregir cuando exista el insumo)
--   - TAMARINDO - NARANJA: un renglón venía con código CC1026 → CC1025 (mismo coctel)
--   - PALETA PAYASO: el bacardí venía con código SUBB025 → SUBB024 (misma subreceta)
--   - PALETA PAYASO: el frangélico venía con código SUBB026 → SUBB024 (misma subreceta)
--   - COCA COLA: SLIC014 → SLIC013 (Coca regular), igual que en Dos Santos
--   - COCA COLA ZERO: SLIC013 → SLIC014 (Coca Zero), igual que en Dos Santos
--   - CREMA DE LECHE: código BAR0045 → BAR045 (formato de 3 dígitos)
--   - CREMA DE LECHE: código BAR0045 → BAR045 (formato de 3 dígitos)
--   - almíbar de maracuyá / zumo de mango usados en UND → ML (rinden en litros)
--   - RED BERRY COLLINS: soda rosas 1 ML → 1 UND
--   - TG.HENNESSY VS venía con 700 ML → 45 ML (estaba cruzado con la botella)
--   - BT.HENNESSY VS venía con 45 ML → 700 ML (estaba cruzado con el trago)
--   - CONCENTRADO DE TAMARINDO: ácido láctico 6 ML → 6 GR
--   - GUAYABADA: limón deshidratado 1 GR → 1 UND
--   - LOS QUE TE FALTARON NEGRO: salsa Hershey's 500 ML → 500 GR
--   - CANTARITO: Gaseosa Cuatro 60 ML → 0,2 UND (botella de 300 ml)
--
-- Ajustes y avisos:
--   - Insumo LIC052: se unifica el nombre "BT. CAZADORES REPOSADO INS" → "BT.CAZADORES REPOSADO INS"
--   - Insumo LIC031: se unifica el nombre "BT. BAILEYS INS" → "BT.BAILEYS INS"
--   - Insumo LIC157: se unifica el nombre "BT. SMIRNOFF TAMARINDO INS" → "BT.SMIRNOFF TAMARINDO INS"
--   - Insumo SUBB024: se unifica el nombre "PALETA PAYASO INS" → "PALETA PAYASO"
--   - Insumo LIC061: se unifica el nombre "BT. COINTREAU INS" → "BT.COINTREAU INS"
--   - Insumo SUBB016: se unifica el nombre "ALMIBAR MARACUYA" → "ALMIBAR DE MARACUYA"
--   - Insumo LIC145: se unifica el nombre "BT. PATRON SILVER INS" → "BT.PATRON SILVER INS"
--   - Insumo LIC135: se unifica el nombre "BT.OJO DE TIGRE INS" → "BT. OJO DE TIGRE INS"
--   - Insumo LIC020: se unifica el nombre "BT. AMARILLO MANZANARES INS" → "BT.AMARILLO MANZANARES INS"
--   - Insumo LIC156: se unifica el nombre "BT. SMIRNOFF INS" → "BT.SMIRNOFF INS"
--   - Insumo BAR005: se unifica el nombre "ACIDO LACTICO INS BAR" → "ACIDO LACTICO BAR INS"
--   - CC1045 DRY MARTINI: el insumo BAR002 está repetido
--   - SUBB008 MIEL DE CHILES: el insumo BAR036 está repetido
--
-- UNIDADES CRUZADAS (se cargan tal cual; la app no puede calcular el costo de estas líneas hasta corregirlas):
--   (ninguno)

-- 0) Verificación: debe existir un área "Barra" en cada punto. Si falta alguna, no se carga nada.
do $$
declare n int;
begin
  select count(*) into n from public.areas a join public.locations l on l.id = a.location_id
  where l.slug in ('canta-corazon-mtdsga9t') and lower(trim(a.name)) = 'barra';
  if n <> 1 then
    raise exception 'Se esperaban 1 áreas "Barra" (una por punto) y hay %: no se cargó nada', n;
  end if;
end $$;

with destino as (
  select a.id as area_id, a.location_id
  from public.areas a join public.locations l on l.id = a.location_id
  where l.slug in ('canta-corazon-mtdsga9t') and lower(trim(a.name)) = 'barra'
),
datos(code, name, yield_qty, yield_unit, ingredients) as (values
  ('SUBB001', 'ALMIBAR SIMPLE', 2.8, 'L', '[{"qty":"3000","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"}]'),
  ('SUBB002', 'MERMELADA DE GUAYABA', 1.2, 'L', '[{"qty":"1000","code":"BAR063","name":"GUAYABA BLANCA BAR INS","unit":"GR"},{"qty":"600","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"8","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"}]'),
  ('SUBB003', 'CORDIAL JAMAICA SPICY', 1, 'L', '[{"qty":"100","code":"BAR055","name":"FLOR DE JAMAICA BAR INS","unit":"GR"},{"qty":"500","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"10","code":"BAR035","name":"CHILE GUAJILLO BAR INS","unit":"GR"},{"qty":"10","code":"SINCODIGO","name":"CHILE ARBOL INS","unit":"GR"},{"qty":"5","code":"BAR027","name":"CANELA EN ASTILLA BAR INS","unit":"GR"},{"qty":"3","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"},{"qty":"10","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"}]'),
  ('SUBB004', 'AZUCAR ACIDA', 0.4, 'L', '[{"qty":"400","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"10","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"},{"qty":"4","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"}]'),
  ('SUBB005', 'ALMIBAR DE PANELA', 0.9, 'L', '[{"qty":"400","code":"BAR097","name":"PANELA BAR","unit":"GR"},{"qty":"10","code":"BAR027","name":"CANELA EN ASTILLA BAR INS","unit":"GR"},{"qty":"3","code":"BAR042","name":"CLAVOS DE OLOR BAR INS","unit":"GR"},{"qty":"100","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"},{"qty":"3","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"}]'),
  ('SUBB006', 'CORDIAL PIMIENTA ROSA', 1.5, 'L', '[{"qty":"30","code":"BAR102","name":"PIMIENTA ROSADA BAR INS","unit":"GR"},{"qty":"750","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"10","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"},{"qty":"5","code":"BAR005","name":"ACIDO LACTICO BAR INS","unit":"GR"}]'),
  ('SUBB007', 'CORDIAL HIERBABUENA EUCALIPTO', 1, 'L', '[{"qty":"30","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"},{"qty":"5","code":"BAR051","name":"EUCALIPTO BAR INS","unit":"GR"},{"qty":"80","code":"BAR074","name":"LIMON BAR INS","unit":"GR"},{"qty":"500","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"10","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"},{"qty":"3","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"}]'),
  ('SUBB008', 'MIEL DE CHILES', 0.5, 'KG', '[{"qty":"250","code":"BAR093","name":"MIEL DE AGAVE BAR INS","unit":"ML"},{"qty":"10","code":"BAR036","name":"CHILE MORITA BAR INS","unit":"GR"},{"qty":"15","code":"BAR036","name":"CHILE MORITA BAR INS","unit":"GR"}]'),
  ('SUBB009', 'ZUMO DE PEPINO', 0.55, 'L', '[{"qty":"500","code":"BAR098","name":"PEPINO BAR INS","unit":"GR"},{"qty":"3","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"}]'),
  ('SUBB010', 'ZUMO DE PIÑA', 0.75, 'L', '[{"qty":"1500","code":"BAR103","name":"PIÑA BAR INS","unit":"GR"},{"qty":"1","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"},{"qty":"2","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"}]'),
  ('SUBB011', 'CONCENTRADO DE TAMARINDO', 0.75, 'L', '[{"qty":"300","code":"BAR123","name":"TAMARINDO BAR INS","unit":"GR"},{"qty":"80","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"2","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"4","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"},{"qty":"6","code":"BAR005","name":"ACIDO LACTICO BAR INS","unit":"GR"}]'),
  ('SUBB012', 'PURE DE DURAZNO', 0.75, 'KG', '[{"qty":"820","code":"BAR047","name":"DURAZNO BAR INS","unit":"GR"},{"qty":"10","code":"BAR132","name":"ZUMO LIMON BAR INS","unit":"ML"},{"qty":"1","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"1","code":"BAR028","name":"CANELA EN POLVO BAR INS","unit":"GR"}]'),
  ('SUBB013', 'ZUMO DE TORONJA', 1, 'L', '[{"qty":"2500","code":"BAR125","name":"TORONJA BAR INS","unit":"GR"}]'),
  ('SUBB014', 'MERMELADA DE CHAMOY', 0.8, 'KG', '[{"qty":"250","code":"BAR047","name":"DURAZNO BAR INS","unit":"GR"},{"qty":"150","code":"BAR039","name":"CIRUELAS PASAS BAR INS","unit":"GR"},{"qty":"100","code":"BAR123","name":"TAMARINDO BAR INS","unit":"GR"},{"qty":"150","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"15","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"50","code":"BAR055","name":"FLOR DE JAMAICA BAR INS","unit":"GR"},{"qty":"100","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"},{"qty":"5","code":"BAR128","name":"VINAGRE BLANCO BAR INS","unit":"ML"}]'),
  ('SUBB015', 'ALMIBAR DE JENGIBRE', 2.2, 'L', '[{"qty":"2500","code":"BAR070","name":"JENGIBRE BAR INS","unit":"GR"},{"qty":"1000","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"}]'),
  ('SUBB016', 'ALMIBAR DE MARACUYA', 3.5, 'L', '[{"qty":"10000","code":"BAR086","name":"MARACUYA BAR INS","unit":"GR"},{"qty":"1800","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"}]'),
  ('SUBB017', 'ZUMO DE MANGO', 1, 'L', '[{"qty":"1000","code":"BAR080","name":"MANGO BAR INS","unit":"GR"}]'),
  ('SUBB018', 'GRANIZADO BABY MANGO', 4.5, 'L', '[{"qty":"1500","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"2000","code":"SUBB017","name":"ZUMO DE MANGO","unit":"ML"},{"qty":"500","code":"BAR132","name":"ZUMO LIMON BAR INS","unit":"ML"},{"qty":"500","code":"SUBB016","name":"ALMIBAR DE MARACUYA","unit":"ML"},{"qty":"100","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"}]'),
  ('SUBB019', 'CORDIAL LAVANDA JAMAICA', 1.4, 'L', '[{"qty":"25","code":"BAR072","name":"LAVANDA BAR INS","unit":"GR"},{"qty":"10","code":"BAR055","name":"FLOR DE JAMAICA BAR INS","unit":"GR"},{"qty":"800","code":"BAR017","name":"AZUCAR BLANCA BAR INS","unit":"GR"},{"qty":"10","code":"BAR004","name":"ACIDO CITRICO BAR INS","unit":"GR"},{"qty":"2","code":"BAR006","name":"ACIDO MALICO INS BAR","unit":"GR"},{"qty":"10","code":"LIC156","name":"BT.SMIRNOFF INS","unit":"ML"}]'),
  ('SUBB020', 'ZUMO LIMON BAR', 3.5, 'L', '[{"qty":"10","code":"BAR074","name":"LIMON BAR INS","unit":"KG"},{"qty":"1","code":"SLIC037","name":"SODA INS","unit":"UN"}]'),
  ('SUBB021', 'LOS QUE TE FALTARON NEGRO', 1.6, 'L', '[{"qty":"200","code":"BAR140","name":"LECHE CONDENSADA","unit":"ML"},{"qty":"400","code":"BAR045","name":"CREMA DE LECHE BAR INS","unit":"ML"},{"qty":"300","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"500","code":"BAR117","name":"SALSA HERSHEYS INS","unit":"GR"},{"qty":"200","code":"BAR142","name":"LECHE BAR INS","unit":"ML"}]'),
  ('SUBB022', 'LOS QUE TE FALTARON BLANCO', 1.6, 'L', '[{"qty":"200","code":"BAR140","name":"LECHE CONDENSADA","unit":"ML"},{"qty":"400","code":"BAR045","name":"CREMA DE LECHE BAR INS","unit":"ML"},{"qty":"150","code":"LIC082","name":"BT. FRANGELICO INS","unit":"ML"},{"qty":"350","code":"LIC156","name":"BT.SMIRNOFF INS","unit":"ML"},{"qty":"300","code":"LIC283","name":"BT. CONVIER CACAO INS","unit":"ML"},{"qty":"200","code":"BAR142","name":"LECHE BAR INS","unit":"ML"}]'),
  ('SUBB023', 'SAL DE HORMIGA', 0.45, 'L', '[{"qty":"50","code":"BAR143","name":"HORMIGA CULONA BAR INS","unit":"GR"},{"qty":"400","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"15","code":"BAR035","name":"CHILE GUAJILLO BAR INS","unit":"GR"}]'),
  ('SUBB024', 'PALETA PAYASO', 0.9, 'L', '[{"qty":"300","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"300","code":"LIC029","name":"BT. BACARDI AÑEJO INS","unit":"ML"},{"qty":"300","code":"LIC082","name":"BT. FRANGELICO INS","unit":"ML"}]'),
  ('CC1051', 'GUAVADELICIA', 1, 'UN', '[{"qty":"60","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"60","code":"SUBB002","name":"MERMELADA DE GUAYABA","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"22.5","code":"SUBB003","name":"CORDIAL JAMAICA SPICY","unit":"ML"},{"qty":"1","code":"SLIC037","name":"SODA INS","unit":"UN"},{"qty":"20","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"},{"qty":"1","code":"SUBB004","name":"AZUCAR ACIDA","unit":"ML"}]'),
  ('CC1052', 'MUNDO DE CARAMELO', 1, 'UN', '[{"qty":"45","code":"LIC029","name":"BT. BACARDI AÑEJO INS","unit":"ML"},{"qty":"15","code":"LIC097","name":"BT.HEERING INS","unit":"ML"},{"qty":"30","code":"SUBB005","name":"ALMIBAR DE PANELA","unit":"ML"},{"qty":"20","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"BAR061","name":"GLITTER COMESTIBLE INS","unit":"GR"},{"qty":"2","code":"BAR015","name":"ALGODÓN DE AZUCAR INS","unit":"GR"}]'),
  ('CC1053', 'RED BERRY COLLINS', 1, 'UN', '[{"qty":"45","code":"LIC284","name":"BT.BEEFEATER INS","unit":"ML"},{"qty":"22.5","code":"BAR109","name":"REAL DE FRAMBUESA BAR INS","unit":"ML"},{"qty":"15","code":"SUBB006","name":"CORDIAL PIMIENTA ROSA","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC038","name":"SODA ROSAS INS","unit":"UN"},{"qty":"10","code":"BAR057","name":"FRAMBUESA BAR INS","unit":"GR"},{"qty":"10","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"}]'),
  ('CC1054', 'EL CHAPULIN', 1, 'UN', '[{"qty":"60","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"30","code":"SUBB009","name":"ZUMO DE PEPINO","unit":"ML"},{"qty":"30","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"},{"qty":"2","code":"BAR138","name":"SAL DE CHILES BAR INS","unit":"GR"},{"qty":"1","code":"BAR135","name":"PIÑA DESHIDRATADA BAR INS","unit":"UN"},{"qty":"5","code":"BAR098","name":"PEPINO BAR INS","unit":"GR"}]'),
  ('CC1055', 'CAFÉ CON ALMA', 1, 'UN', '[{"qty":"30","code":"LIC121","name":"BT.LICOR TIA MARIA INS","unit":"ML"},{"qty":"30","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"30","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"15","code":"SUBB005","name":"ALMIBAR DE PANELA","unit":"ML"},{"qty":"10","code":"BAR027","name":"CANELA EN ASTILLA BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"}]'),
  ('CC1056', 'LISTERINE (500 ML)', 1, 'UN', '[{"qty":"100","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"30","code":"LIC063","name":"BT.CONVIER DURAZNO INS","unit":"ML"},{"qty":"22.5","code":"BAR053","name":"FINEST CALL BLUE CURACAO INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"22.5","code":"SUBB007","name":"CORDIAL HIERBABUENA EUCALIPTO","unit":"ML"},{"qty":"1","code":"SLIC040","name":"SPRITE INS","unit":"UN"},{"qty":"1","code":"BAR068","name":"HIELO SECO INS","unit":"GR"}]'),
  ('CC1057', 'FELICES X SIEMPRE (350 ML)', 1, 'UN', '[{"qty":"60","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"22.5","code":"LIC016","name":"BT.ABSENTA INS","unit":"ML"},{"qty":"15","code":"BAR053","name":"FINEST CALL BLUE CURACAO INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"BAR111","name":"REAL KIWI INS","unit":"ML"},{"qty":"1","code":"SLIC010","name":"AMPER BLUE INS","unit":"UN"},{"qty":"1","code":"BAR061","name":"GLITTER COMESTIBLE INS","unit":"GR"}]'),
  ('CC1058', 'TRES PATADAS (280 ML)', 1, 'UN', '[{"qty":"90","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"45","code":"LIC174","name":"BT.CONVIER MARACUYA INS","unit":"ML"},{"qty":"45","code":"SUBB011","name":"CONCENTRADO DE TAMARINDO","unit":"ML"},{"qty":"20","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"},{"qty":"60","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"90","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"1","code":"SLIC018","name":"G. NARANJA INS","unit":"UN"}]'),
  ('CC1059', 'PALETA PAYASO (10 UND)', 1, 'UN', '[{"qty":"450","code":"SUBB024","name":"PALETA PAYASO","unit":"ML"},{"qty":"100","code":"BAR117","name":"SALSA HERSHEYS INS","unit":"GR"},{"qty":"200","code":"BAR034","name":"CHANTILLY BAR INS","unit":"GR"},{"qty":"20","code":"BAR087","name":"MASHMELLOW BAR INS","unit":"GR"}]'),
  ('CC1060', 'LA TORERA PARA COMPARTIR (600 ML)', 1, 'UN', '[{"qty":"45","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"15","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"},{"qty":"180","code":"LIC273","name":"VT. RAMON BILBAO CRIANZA INS","unit":"ML"},{"qty":"40","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"30","code":"SUBB003","name":"CORDIAL JAMAICA SPICY","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC023","name":"GINGER BEER INS","unit":"UN"}]'),
  ('CC1061', 'GRANIZADO BABY MANGO', 1, 'UN', '[{"qty":"200","code":"SUBB018","name":"GRANIZADO BABY MANGO","unit":"ML"}]'),
  ('CC1022', 'PIÑA - TAMARINDO', 1, 'UN', '[{"qty":"60","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"30","code":"SUBB011","name":"CONCENTRADO DE TAMARINDO","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC019","name":"G. PIÑA INS","unit":"UN"}]'),
  ('CC1023', 'UVA - PIÑA', 1, 'UN', '[{"qty":"60","code":"LIC024","name":"BT.ANTIOQUEÑO ROJO INS","unit":"ML"},{"qty":"60","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC021","name":"G. UVA INS","unit":"UN"}]'),
  ('CC1024', 'NARANJA - DURAZNO', 1, 'UN', '[{"qty":"45","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"22.5","code":"LIC063","name":"BT.CONVIER DURAZNO INS","unit":"ML"},{"qty":"22.5","code":"SUBB012","name":"PURE DE DURAZNO","unit":"GR"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC018","name":"G. NARANJA INS","unit":"UN"}]'),
  ('CC1025', 'TAMARINDO - NARANJA', 1, 'UN', '[{"qty":"60","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"45","code":"BAR134","name":"ZUMO NARANJA BAR INS","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"22.5","code":"SUBB016","name":"ALMIBAR DE MARACUYA","unit":"ML"},{"qty":"1","code":"SLIC020","name":"G. TAMARINDO INS","unit":"UN"}]'),
  ('CC1033', 'CARAJILLO', 1, 'UN', '[{"qty":"45","code":"LIC119","name":"BT.LICOR 43 INS","unit":"ML"},{"qty":"1","code":"SLIC016","name":"ESPRESSO INS","unit":"UN"},{"qty":"2","code":"BAR025","name":"CAFE EN GRANO BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"}]'),
  ('CC1034', 'CARAJILLA', 1, 'UN', '[{"qty":"45","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"1","code":"SLIC016","name":"ESPRESSO INS","unit":"UN"},{"qty":"2","code":"BAR025","name":"CAFE EN GRANO BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"}]'),
  ('CC1035', 'ESPRESSO MARTINI', 1, 'UN', '[{"qty":"60","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"15","code":"LIC121","name":"BT.LICOR TIA MARIA INS","unit":"ML"},{"qty":"10","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"1","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"1","code":"SLIC016","name":"ESPRESSO INS","unit":"UN"},{"qty":"1","code":"BAR025","name":"CAFE EN GRANO BAR INS","unit":"GR"}]'),
  ('CC1036', 'MARGARITA PATRON', 1, 'UN', '[{"qty":"45","code":"LIC145","name":"BT.PATRON SILVER INS","unit":"ML"},{"qty":"20","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"7.5","code":"ABA106","name":"MIEL DE AGAVE INS","unit":"ML"},{"qty":"2","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"7","code":"BAR074","name":"LIMON BAR INS","unit":"GR"}]'),
  ('CC1037', 'PALOMA BY PATRON', 1, 'UN', '[{"qty":"30","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"30","code":"LIC145","name":"BT.PATRON SILVER INS","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"ABA106","name":"MIEL DE AGAVE INS","unit":"ML"},{"qty":"1","code":"SLIC039","name":"SODA TORONJA INS","unit":"UN"},{"qty":"1","code":"BAR136","name":"TORONJA DESHIDRATADA BAR INS","unit":"UN"},{"qty":"5","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"}]'),
  ('CC1038', 'CANTARITO', 1, 'UN', '[{"qty":"75","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"BAR134","name":"ZUMO NARANJA BAR INS","unit":"ML"},{"qty":"30","code":"SUBB013","name":"ZUMO DE TORONJA","unit":"ML"},{"qty":"0.2","code":"SLIC017","name":"G. CUATRO INS","unit":"UN"},{"qty":"0.29","code":"SLIC039","name":"SODA TORONJA INS","unit":"UN"},{"qty":"5","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"2","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"},{"qty":"10","code":"SUBB014","name":"MERMELADA DE CHAMOY","unit":"GR"}]'),
  ('CC1039', 'APEROL SPRITZ', 1, 'UN', '[{"qty":"60","code":"LIC027","name":"BT.APEROL INS","unit":"ML"},{"qty":"90","code":"LIC219","name":"VE. CINZANO TO SPRIT INS","unit":"ML"},{"qty":"0.1","code":"SLIC037","name":"SODA INS","unit":"UN"},{"qty":"15","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"}]'),
  ('CC1040', 'BLOODY MARY', 1, 'UN', '[{"qty":"45","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"90","code":"BAR040","name":"CLAMATO BAR INS","unit":"ML"},{"qty":"20","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"10","code":"BAR118","name":"SALSA INGLESA BAR INS","unit":"ML"},{"qty":"1","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"2","code":"BAR101","name":"PIMIENTA BAR INS","unit":"GR"},{"qty":"4","code":"BAR121","name":"TABASCO BAR INS","unit":"ML"},{"qty":"4","code":"BAR002","name":"ACEITUNA VERDE BAR INS","unit":"GR"},{"qty":"5","code":"BAR074","name":"LIMON BAR INS","unit":"GR"}]'),
  ('CC1041', 'COSMOPOLITAN', 1, 'UN', '[{"qty":"50","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"15","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"},{"qty":"45","code":"BAR071","name":"JUGO DE ARANDANOS INS","unit":"ML"},{"qty":"20","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"}]'),
  ('CC1042', 'LYCHEE MARTINI', 1, 'UN', '[{"qty":"45","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"20","code":"LIC158","name":"BT.SOHO LYCHEE INS","unit":"ML"},{"qty":"15","code":"BAR120","name":"SUGG LYCHEE INS","unit":"ML"},{"qty":"20","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"BAR078","name":"LYCHEE BAR INS","unit":"GR"}]'),
  ('CC1043', 'MOSCOW MULE', 1, 'UN', '[{"qty":"60","code":"LIC017","name":"BT.ABSOLUT VODKA INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"SUBB015","name":"ALMIBAR DE JENGIBRE","unit":"ML"},{"qty":"1","code":"SLIC023","name":"GINGER BEER INS","unit":"UN"},{"qty":"7","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"}]'),
  ('CC1044', 'MOJITO', 1, 'UN', '[{"qty":"60","code":"LIC030","name":"BT.BACARDI SUPERIOR BLANCO INS","unit":"ML"},{"qty":"20","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"15","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"},{"qty":"20","code":"BAR074","name":"LIMON BAR INS","unit":"GR"},{"qty":"0.5","code":"SLIC037","name":"SODA INS","unit":"UN"}]'),
  ('CC1045', 'DRY MARTINI', 1, 'UN', '[{"qty":"15","code":"LIC169","name":"BT.VERMUT DRY INS","unit":"ML"},{"qty":"75","code":"LIC284","name":"BT.BEEFEATER INS","unit":"ML"},{"qty":"2","code":"BAR021","name":"BITTERS NARANJA INS","unit":"ML"},{"qty":"12","code":"BAR002","name":"ACEITUNA VERDE BAR INS","unit":"GR"},{"qty":"30","code":"BAR002","name":"ACEITUNA VERDE BAR INS","unit":"GR"}]'),
  ('CC1046', 'NEGRONI', 1, 'UN', '[{"qty":"30","code":"LIC284","name":"BT.BEEFEATER INS","unit":"ML"},{"qty":"30","code":"LIC168","name":"BT.VERMUT ROSSO INS","unit":"ML"},{"qty":"30","code":"LIC049","name":"BT.CAMPARI INS","unit":"ML"},{"qty":"9","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"}]'),
  ('CC1047', 'OLD FASHIONED', 1, 'UN', '[{"qty":"60","code":"LIC047","name":"BT.BULLEIT INS","unit":"ML"},{"qty":"3","code":"BAR018","name":"AZUCAR PULVERIZADA BAR INS","unit":"GR"},{"qty":"2","code":"BAR062","name":"GOTAS AMARGAS INS","unit":"ML"},{"qty":"1","code":"BAR021","name":"BITTERS NARANJA INS","unit":"ML"},{"qty":"10","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"}]'),
  ('CC1048', 'WHISKY SOUR', 1, 'UN', '[{"qty":"60","code":"LIC110","name":"BT.JACK DANIELS OLD N7 INS","unit":"ML"},{"qty":"30","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"BAR041","name":"CLARAS DE HUEVO BAR INS","unit":"GR"},{"qty":"1","code":"BAR066","name":"HIELO EN CUBO INS","unit":"UN"},{"qty":"1","code":"BAR062","name":"GOTAS AMARGAS INS","unit":"ML"}]'),
  ('CC1049', 'PALOMA MEZCAL', 1, 'UN', '[{"qty":"45","code":"LIC135","name":"BT. OJO DE TIGRE INS","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"ABA106","name":"MIEL DE AGAVE INS","unit":"ML"},{"qty":"1","code":"SLIC039","name":"SODA TORONJA INS","unit":"UN"},{"qty":"12","code":"BAR125","name":"TORONJA BAR INS","unit":"GR"},{"qty":"5","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"}]'),
  ('CC1050', 'MEZCAL MULE', 1, 'UN', '[{"qty":"45","code":"LIC135","name":"BT. OJO DE TIGRE INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"SUBB015","name":"ALMIBAR DE JENGIBRE","unit":"ML"},{"qty":"1","code":"SLIC023","name":"GINGER BEER INS","unit":"UN"},{"qty":"7","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"},{"qty":"7","code":"BAR074","name":"LIMON BAR INS","unit":"GR"}]'),
  ('CC1027', 'CHELADA', 1, 'UN', '[{"qty":"1","code":"LIC193","name":"SOL INS","unit":"UN"},{"qty":"2","code":"BAR121","name":"TABASCO BAR INS","unit":"ML"},{"qty":"5","code":"BAR118","name":"SALSA INGLESA BAR INS","unit":"ML"},{"qty":"90","code":"BAR040","name":"CLAMATO BAR INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"4","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"},{"qty":"2","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"1","code":"BAR101","name":"PIMIENTA BAR INS","unit":"GR"}]'),
  ('CC1093', 'PEPINADA', 1, 'UN', '[{"qty":"60","code":"SUBB009","name":"ZUMO DE PEPINO","unit":"ML"},{"qty":"60","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"2","code":"BAR138","name":"SAL DE CHILES BAR INS","unit":"GR"},{"qty":"1","code":"BAR135","name":"PIÑA DESHIDRATADA BAR INS","unit":"UN"}]'),
  ('CC1094', 'GUAYABADA', 1, 'UN', '[{"qty":"80","code":"SUBB002","name":"MERMELADA DE GUAYABA","unit":"ML"},{"qty":"22.5","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"10","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"1","code":"SLIC037","name":"SODA INS","unit":"UN"},{"qty":"3","code":"SUBB004","name":"AZUCAR ACIDA","unit":"ML"},{"qty":"1","code":"BAR139","name":"LIMON DESHIDRATADO BAR INS","unit":"UN"},{"qty":"5","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"}]'),
  ('CC1095', 'TAMARINDADA', 1, 'UN', '[{"qty":"60","code":"SUBB011","name":"CONCENTRADO DE TAMARINDO","unit":"ML"},{"qty":"30","code":"BAR134","name":"ZUMO NARANJA BAR INS","unit":"ML"},{"qty":"10","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"30","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"2","code":"BAR138","name":"SAL DE CHILES BAR INS","unit":"GR"},{"qty":"1","code":"BAR137","name":"NARANJA DESHIDRATADA BAR INS","unit":"UN"}]'),
  ('CC1096', 'LA ROSADA', 1, 'UN', '[{"qty":"60","code":"BAR109","name":"REAL DE FRAMBUESA BAR INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC030","name":"JUNIPER COCO INS","unit":"UN"},{"qty":"10","code":"BAR057","name":"FRAMBUESA BAR INS","unit":"GR"},{"qty":"10","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"}]'),
  ('CC1115', 'PERLA NEGRA', 1, 'UN', '[{"qty":"45","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"},{"qty":"1","code":"SLIC010","name":"AMPER BLUE INS","unit":"UN"}]'),
  ('CC1116', 'JAGERBOOM', 1, 'UN', '[{"qty":"45","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"},{"qty":"1","code":"SLIC032","name":"RED BULL INS","unit":"UN"}]'),
  ('CC1117', 'ALA VERDE', 1, 'UN', '[{"qty":"45","code":"LIC016","name":"BT.ABSENTA INS","unit":"ML"},{"qty":"1","code":"SLIC032","name":"RED BULL INS","unit":"UN"}]'),
  ('CC1118', 'REXODON', 1, 'UN', '[{"qty":"45","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"45","code":"BAR071","name":"JUGO DE ARANDANOS INS","unit":"ML"},{"qty":"1","code":"SLIC032","name":"RED BULL INS","unit":"UN"}]'),
  ('CC1119', 'BABY MANGO', 1, 'UN', '[{"qty":"45","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"60","code":"SUBB017","name":"ZUMO DE MANGO","unit":"ML"},{"qty":"15","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"15","code":"SUBB016","name":"ALMIBAR DE MARACUYA","unit":"ML"},{"qty":"7.5","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"}]'),
  ('CC1120', 'ABC', 1, 'UN', '[{"qty":"15","code":"LIC019","name":"BT.AMARETO INS","unit":"ML"},{"qty":"15","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"15","code":"LIC100","name":"BT.HENESSY INS","unit":"ML"}]'),
  ('CC1121', 'CAQUITA DE CUPIDO', 1, 'UN', '[{"qty":"15","code":"LIC121","name":"BT.LICOR TIA MARIA INS","unit":"ML"},{"qty":"15","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"},{"qty":"15","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"},{"qty":"15","code":"BAR034","name":"CHANTILLY BAR INS","unit":"GR"}]'),
  ('CC1009', 'MIX DE SANGRIA ROSE', 1, 'UN', '[{"qty":"75","code":"LIC160","name":"BT.TANQUERAY LONDON INS","unit":"ML"},{"qty":"30","code":"LIC027","name":"BT.APEROL INS","unit":"ML"},{"qty":"75","code":"SUBB019","name":"CORDIAL LAVANDA JAMAICA","unit":"ML"},{"qty":"60","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"45","code":"BAR132","name":"ZUMO LIMON BAR INS","unit":"ML"},{"qty":"30","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"},{"qty":"1","code":"SLIC039","name":"SODA TORONJA INS","unit":"UN"},{"qty":"20","code":"SUBB016","name":"ALMIBAR DE MARACUYA","unit":"ML"},{"qty":"20","code":"BAR058","name":"FRESA BAR INS","unit":"GR"},{"qty":"20","code":"BAR125","name":"TORONJA BAR INS","unit":"GR"}]'),
  ('CC1010', 'MIX DE SANGRIA TINTO', 1, 'UN', '[{"qty":"75","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"30","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"},{"qty":"150","code":"SUBB011","name":"CONCENTRADO DE TAMARINDO","unit":"ML"},{"qty":"45","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"},{"qty":"45","code":"BAR134","name":"ZUMO NARANJA BAR INS","unit":"ML"},{"qty":"1","code":"SLIC023","name":"GINGER BEER INS","unit":"UN"},{"qty":"20","code":"BAR103","name":"PIÑA BAR INS","unit":"GR"},{"qty":"20","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"},{"qty":"20","code":"BAR080","name":"MANGO BAR INS","unit":"GR"}]'),
  ('CC1011', 'BT.ANTIOQUEÑO ROJO', 1, 'UN', '[{"qty":"750","code":"LIC024","name":"BT.ANTIOQUEÑO ROJO INS","unit":"ML"}]'),
  ('CC1012', 'BT.ANTIOQUEÑO AZUL', 1, 'UN', '[{"qty":"750","code":"LIC023","name":"BT.ANTIOQUEÑO AZUL INS","unit":"ML"}]'),
  ('CC1013', 'BT.ANTIOQUEÑO VERDE', 1, 'UN', '[{"qty":"750","code":"LIC025","name":"BT.ANTIOQUEÑO VERDE INS","unit":"ML"}]'),
  ('CC1014', 'TG.ANTIOQUEÑO ROJO', 1, 'UN', '[{"qty":"45","code":"LIC024","name":"BT.ANTIOQUEÑO ROJO INS","unit":"ML"}]'),
  ('CC1015', 'TG.ANTIOQUEÑO AZUL', 1, 'UN', '[{"qty":"45","code":"LIC023","name":"BT.ANTIOQUEÑO AZUL INS","unit":"ML"}]'),
  ('CC1016', 'TG.ANTIOQUEÑO VERDE', 1, 'UN', '[{"qty":"45","code":"LIC025","name":"BT.ANTIOQUEÑO VERDE INS","unit":"ML"}]'),
  ('CC1017', 'TG.AGUARDIENTE MANZANARES', 1, 'UN', '[{"qty":"45","code":"LIC020","name":"BT.AMARILLO MANZANARES INS","unit":"ML"}]'),
  ('CC1018', 'BT.AGUARDIENTE MANZANARES', 1, 'UN', '[{"qty":"750","code":"LIC020","name":"BT.AMARILLO MANZANARES INS","unit":"ML"}]'),
  ('CC1019', 'MD.ANTIOQUEÑO ROJO', 1, 'UN', '[{"qty":"1","code":"LIC185","name":"MD. ANTIOQUEÑO ROJA INS","unit":"UN"}]'),
  ('CC1020', 'MD.ANTIOQUEÑO AZUL', 1, 'UN', '[{"qty":"1","code":"LIC184","name":"MD. ANTIOQUEÑO AZUL INS","unit":"UN"}]'),
  ('CC1021', 'MD.AGUARDIENTE MANZANARES', 1, 'UN', '[{"qty":"1","code":"LIC183","name":"MD. AMARILLO MANZANARES INS","unit":"UN"}]'),
  ('CC1028', 'SOL', 1, 'UN', '[{"qty":"1","code":"LIC193","name":"SOL INS","unit":"UN"}]'),
  ('CC1029', 'HEINEKEN', 1, 'UN', '[{"qty":"1","code":"LIC182","name":"HEINEKEN INS","unit":"UN"}]'),
  ('CC1030', 'BT.DOM PERIGNON VINTAGE', 1, 'UN', '[{"qty":"1","code":"LIC220","name":"VE.DOM PERI BRUT INS","unit":"UN"}]'),
  ('CC1031', 'BT.MOET BRUT', 1, 'UN', '[{"qty":"1","code":"LIC233","name":"VE.MOET & CHANDON IMPERIAL INS","unit":"UN"}]'),
  ('CC1032', 'BT.MOET ROSE', 1, 'UN', '[{"qty":"1","code":"LIC234","name":"VE. MOET & CHANDON IMPERIAL ROSE INS","unit":"UN"}]'),
  ('CC1062', 'TG.HENNESSY VS', 1, 'UN', '[{"qty":"45","code":"LIC100","name":"BT.HENESSY INS","unit":"ML"}]'),
  ('CC1063', 'BT.HENNESSY VS', 1, 'UN', '[{"qty":"700","code":"LIC101","name":"BT.HENNESSY VS INS","unit":"ML"}]'),
  ('CC1064', 'BT.BOMBAY', 1, 'UN', '[{"qty":"700","code":"LIC040","name":"BT.BOMBAY SHAPIRE INS","unit":"ML"}]'),
  ('CC1065', 'BT.HENDRICKS', 1, 'UN', '[{"qty":"750","code":"LIC098","name":"BT.HENDRICKS INS","unit":"ML"}]'),
  ('CC1066', 'BT.TANQUERAY LONDON', 1, 'UN', '[{"qty":"700","code":"LIC160","name":"BT.TANQUERAY LONDON INS","unit":"ML"}]'),
  ('CC1067', 'TG.BOMBAY', 1, 'UN', '[{"qty":"60","code":"LIC040","name":"BT.BOMBAY SHAPIRE INS","unit":"ML"}]'),
  ('CC1068', 'TG.HENDRICKS', 1, 'UN', '[{"qty":"60","code":"LIC098","name":"BT.HENDRICKS INS","unit":"ML"}]'),
  ('CC1069', 'TG.TANQUERAY LONDON', 1, 'UN', '[{"qty":"60","code":"LIC160","name":"BT.TANQUERAY LONDON INS","unit":"ML"}]'),
  ('CC1070', 'BT.400 CONEJOS', 1, 'UN', '[{"qty":"750","code":"LIC011","name":"BT.400 CONEJOS INS","unit":"ML"}]'),
  ('CC1071', 'BT.MONTELOBOS', 1, 'UN', '[{"qty":"750","code":"LIC133","name":"BT.MONTELOBOS INS","unit":"ML"}]'),
  ('CC1072', 'BT.UNIÓN', 1, 'UN', '[{"qty":"700","code":"LIC167","name":"BT.UNION INS","unit":"ML"}]'),
  ('CC1073', 'BT.OJO DE TIGRE', 1, 'UN', '[{"qty":"750","code":"LIC135","name":"BT. OJO DE TIGRE INS","unit":"ML"}]'),
  ('CC1074', 'TG.400 CONEJOS', 1, 'UN', '[{"qty":"45","code":"LIC011","name":"BT.400 CONEJOS INS","unit":"ML"}]'),
  ('CC1075', 'TG.MONTELOBOS', 1, 'UN', '[{"qty":"45","code":"LIC133","name":"BT.MONTELOBOS INS","unit":"ML"}]'),
  ('CC1076', 'TG.UNIÓN', 1, 'UN', '[{"qty":"45","code":"LIC167","name":"BT.UNION INS","unit":"ML"}]'),
  ('CC1077', 'TG.OJO DE TIGRE', 1, 'UN', '[{"qty":"45","code":"LIC135","name":"BT. OJO DE TIGRE INS","unit":"ML"}]'),
  ('CC1078', 'SODA', 1, 'UN', '[{"qty":"1","code":"SLIC037","name":"SODA INS","unit":"UN"}]'),
  ('CC1079', 'JUNIPER ROSAS', 1, 'UN', '[{"qty":"1","code":"SLIC038","name":"SODA ROSAS INS","unit":"UN"}]'),
  ('CC1080', 'JUNIPER COCONUT', 1, 'UN', '[{"qty":"1","code":"SLIC030","name":"JUNIPER COCO INS","unit":"UN"}]'),
  ('CC1081', 'MIL 976 GINGER BEER', 1, 'UN', '[{"qty":"1","code":"SLIC023","name":"GINGER BEER INS","unit":"UN"}]'),
  ('CC1082', 'MIL 976 TORONJA', 1, 'UN', '[{"qty":"1","code":"SLIC039","name":"SODA TORONJA INS","unit":"UN"}]'),
  ('CC1083', 'MIL 976 OCEAN', 1, 'UN', '[{"qty":"1","code":"SLIC041","name":"TONIC OCEAN INS","unit":"UN"}]'),
  ('CC1084', 'RED BULL', 1, 'UN', '[{"qty":"1","code":"SLIC032","name":"RED BULL INS","unit":"UN"}]'),
  ('CC1085', 'RED BULL FREE', 1, 'UN', '[{"qty":"1","code":"SLIC034","name":"RED BULL SUGAR FREE INS","unit":"UN"}]'),
  ('CC1086', 'AGUA EVIAN', 1, 'UN', '[{"qty":"1","code":"SLIC001","name":"AGUA EVIAN INS","unit":"UN"}]'),
  ('CC1087', 'AGUA PERRIER', 1, 'UN', '[{"qty":"1","code":"SLIC005","name":"AGUA PERRIER INS","unit":"UN"}]'),
  ('CC1088', 'AGUA HATSU', 1, 'UN', '[{"qty":"1","code":"SLIC003","name":"AGUA HATSU INS","unit":"UN"}]'),
  ('CC1089', 'AGUA HATSU CON GAS', 1, 'UN', '[{"qty":"1","code":"SLIC002","name":"AGUA HATSU CON GAS INS","unit":"UN"}]'),
  ('CC1090', 'COCA COLA', 1, 'UN', '[{"qty":"1","code":"SLIC013","name":"COCA REGULAR INS","unit":"UN"}]'),
  ('CC1091', 'COCA COLA ZERO', 1, 'UN', '[{"qty":"1","code":"SLIC014","name":"COCA COLA ZERO INS","unit":"UN"}]'),
  ('CC1092', 'GATORLYTE', 1, 'UN', '[{"qty":"1","code":"SLIC022","name":"GATORLYTE INS","unit":"UN"}]'),
  ('CC1097', 'BT.BAILEYS', 1, 'UN', '[{"qty":"700","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"}]'),
  ('CC1098', 'BT.JAGERMAISTER', 1, 'UN', '[{"qty":"700","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"}]'),
  ('CC1099', 'BT.APEROL', 1, 'UN', '[{"qty":"750","code":"LIC027","name":"BT.APEROL INS","unit":"ML"}]'),
  ('CC1100', 'TG.BAILEYS', 1, 'UN', '[{"qty":"60","code":"LIC031","name":"BT.BAILEYS INS","unit":"ML"}]'),
  ('CC1101', 'TG.JAGERMAISTER', 1, 'UN', '[{"qty":"45","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"}]'),
  ('CC1102', 'TG.APEROL', 1, 'UN', '[{"qty":"45","code":"LIC027","name":"BT.APEROL INS","unit":"ML"}]'),
  ('CC1103', 'BT.BACARDI BLANCO', 1, 'UN', '[{"qty":"750","code":"LIC030","name":"BT.BACARDI SUPERIOR BLANCO INS","unit":"ML"}]'),
  ('CC1104', 'BT.FLOR DE CAÑA 12', 1, 'UN', '[{"qty":"750","code":"LIC079","name":"BT.FLOR DE CAÑA ORO 12 INS","unit":"ML"}]'),
  ('CC1105', 'BT.MEDELLÍN 8', 1, 'UN', '[{"qty":"750","code":"LIC129","name":"BT.MEDELLIN 8 AÑOS INS","unit":"ML"}]'),
  ('CC1106', 'BT.CALDAS 8', 1, 'UN', '[{"qty":"750","code":"LIC048","name":"BT.CALDAS 8 INS","unit":"ML"}]'),
  ('CC1107', 'BT.LA HECHICERA', 1, 'UN', '[{"qty":"700","code":"LIC026","name":"BT.LA HECHICERA INS","unit":"ML"}]'),
  ('CC1108', 'BT.ZACAPA 23', 1, 'UN', '[{"qty":"700","code":"LIC172","name":"BT.ZACAPA 23 INS","unit":"ML"}]'),
  ('CC1109', 'TG.BACARDI BLANCO', 1, 'UN', '[{"qty":"45","code":"LIC030","name":"BT.BACARDI SUPERIOR BLANCO INS","unit":"ML"}]'),
  ('CC1110', 'TG.FLOR DE CAÑA 12', 1, 'UN', '[{"qty":"45","code":"LIC079","name":"BT.FLOR DE CAÑA ORO 12 INS","unit":"ML"}]'),
  ('CC1111', 'TG.MEDELLÍN 8', 1, 'UN', '[{"qty":"45","code":"LIC129","name":"BT.MEDELLIN 8 AÑOS INS","unit":"ML"}]'),
  ('CC1112', 'TG.CALDAS 8', 1, 'UN', '[{"qty":"45","code":"LIC048","name":"BT.CALDAS 8 INS","unit":"ML"}]'),
  ('CC1113', 'TG.LA HECHICERA', 1, 'UN', '[{"qty":"45","code":"LIC026","name":"BT.LA HECHICERA INS","unit":"ML"}]'),
  ('CC1114', 'TG.ZACAPA 23', 1, 'UN', '[{"qty":"45","code":"LIC172","name":"BT.ZACAPA 23 INS","unit":"ML"}]'),
  ('CC1122', 'BT.1800 BLANCO', 1, 'UN', '[{"qty":"700","code":"LIC009","name":"BT.1800 SILVER INS","unit":"ML"}]'),
  ('CC1123', 'BT.1800 CRISTALINO', 1, 'UN', '[{"qty":"700","code":"LIC006","name":"BT.1800 CRISTALINO INS","unit":"ML"}]'),
  ('CC1124', 'BT.DON JULIO BLANCO', 1, 'UN', '[{"qty":"750","code":"LIC073","name":"BT.DON JULIO BLANCO INS","unit":"ML"}]'),
  ('CC1125', 'BT.DON JULIO REPOSADO', 1, 'UN', '[{"qty":"700","code":"LIC076","name":"BT.DON JULIO REPOSADO INS","unit":"ML"}]'),
  ('CC1126', 'BT.DON JULIO 70', 1, 'UN', '[{"qty":"700","code":"LIC071","name":"BT.DON JULIO 70 INS","unit":"ML"}]'),
  ('CC1127', 'BT.CLASE AZUL REP', 1, 'UN', '[{"qty":"750","code":"LIC060","name":"BT.CLASE AZUL REPOSADO INS","unit":"ML"}]'),
  ('CC1128', 'BT.MAESTRO DOBEL', 1, 'UN', '[{"qty":"750","code":"LIC126","name":"BT.MAESTRO DOBEL INS","unit":"ML"}]'),
  ('CC1129', 'BT.MAESTRO DOBEL 1750 ML', 1, 'UN', '[{"qty":"1750","code":"LIC280","name":"BT.MAESTRO DOBEL 1750ML INS","unit":"ML"}]'),
  ('CC1130', 'BT.PATRON SILVER', 1, 'UN', '[{"qty":"700","code":"LIC145","name":"BT.PATRON SILVER INS","unit":"ML"}]'),
  ('CC1131', 'BT.PATRON REPOSADO', 1, 'UN', '[{"qty":"700","code":"LIC144","name":"BT.PATRON REPOSADO INS","unit":"ML"}]'),
  ('CC1132', 'BT.PATRON AÑEJO', 1, 'UN', '[{"qty":"750","code":"LIC141","name":"BT.PATRON AÑEJO INS","unit":"ML"}]'),
  ('CC1133', 'BT.PATRON CRISTALINO', 1, 'UN', '[{"qty":"700","code":"LIC142","name":"BT.PATRON CRISTALINO INS","unit":"ML"}]'),
  ('CC1134', 'BT.PATRON EL CIELO', 1, 'UN', '[{"qty":"700","code":"LIC143","name":"BT.PATRON EL CIELO INS","unit":"ML"}]'),
  ('CC1135', 'TG.1800 BLANCO', 1, 'UN', '[{"qty":"45","code":"LIC009","name":"BT.1800 SILVER INS","unit":"ML"}]'),
  ('CC1136', 'TG.1800 CRISTALINO', 1, 'UN', '[{"qty":"45","code":"LIC006","name":"BT.1800 CRISTALINO INS","unit":"ML"}]'),
  ('CC1137', 'TG.DON JULIO BLANCO', 1, 'UN', '[{"qty":"45","code":"LIC073","name":"BT.DON JULIO BLANCO INS","unit":"ML"}]'),
  ('CC1138', 'TG.DON JULIO REPOSADO', 1, 'UN', '[{"qty":"45","code":"LIC076","name":"BT.DON JULIO REPOSADO INS","unit":"ML"}]'),
  ('CC1139', 'TG.DON JULIO 70', 1, 'UN', '[{"qty":"45","code":"LIC071","name":"BT.DON JULIO 70 INS","unit":"ML"}]'),
  ('CC1140', 'TG.CLASE AZUL REP', 1, 'UN', '[{"qty":"45","code":"LIC060","name":"BT.CLASE AZUL REPOSADO INS","unit":"ML"}]'),
  ('CC1141', 'TG.MAESTRO DOBEL', 1, 'UN', '[{"qty":"45","code":"LIC126","name":"BT.MAESTRO DOBEL INS","unit":"ML"}]'),
  ('CC1143', 'TG.PATRON SILVER', 1, 'UN', '[{"qty":"45","code":"LIC145","name":"BT.PATRON SILVER INS","unit":"ML"}]'),
  ('CC1144', 'TG.PATRON REPOSADO', 1, 'UN', '[{"qty":"45","code":"LIC144","name":"BT.PATRON REPOSADO INS","unit":"ML"}]'),
  ('CC1145', 'TG.PATRON AÑEJO', 1, 'UN', '[{"qty":"45","code":"LIC141","name":"BT.PATRON AÑEJO INS","unit":"ML"}]'),
  ('CC1146', 'TG.PATRON CRISTALINO', 1, 'UN', '[{"qty":"45","code":"LIC142","name":"BT.PATRON CRISTALINO INS","unit":"ML"}]'),
  ('CC1147', 'TG.PATRON EL CIELO', 1, 'UN', '[{"qty":"45","code":"LIC143","name":"BT.PATRON EL CIELO INS","unit":"ML"}]'),
  ('CC1148', 'BT.RAMON BILBAO TINTO', 1, 'UN', '[{"qty":"750","code":"LIC273","name":"VT. RAMON BILBAO CRIANZA INS","unit":"ML"}]'),
  ('CC1149', 'BT.COTO BLANCO', 1, 'UN', '[{"qty":"750","code":"LIC196","name":"VB. EL COTO BLANCO INS","unit":"ML"}]'),
  ('CC1150', 'CP. RAMON BILBAO TINTO', 1, 'UN', '[{"qty":"150","code":"LIC273","name":"VT. RAMON BILBAO CRIANZA INS","unit":"ML"}]'),
  ('CC1151', 'CP. COTO BLANCO', 1, 'UN', '[{"qty":"150","code":"LIC196","name":"VB. EL COTO BLANCO INS","unit":"ML"}]'),
  ('CC1152', 'BT.SMIRNOFF', 1, 'UN', '[{"qty":"750","code":"LIC156","name":"BT.SMIRNOFF INS","unit":"ML"}]'),
  ('CC1153', 'BT.SMIRNOFF SPICY TAMARIDO', 1, 'UN', '[{"qty":"750","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"}]'),
  ('CC1154', 'BT.GREY GOOSE', 1, 'UN', '[{"qty":"750","code":"LIC096","name":"BT.GREY GOOSE INS","unit":"ML"}]'),
  ('CC1155', 'BT.TITOS', 1, 'UN', '[{"qty":"750","code":"LIC165","name":"BT.TITOS VODKA INS","unit":"ML"}]'),
  ('CC1156', 'TG.SMIRNOFF', 1, 'UN', '[{"qty":"45","code":"LIC156","name":"BT.SMIRNOFF INS","unit":"ML"}]'),
  ('CC1157', 'TG.SMIRNOFF SPICY TAMARIDO', 1, 'UN', '[{"qty":"45","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"}]'),
  ('CC1158', 'TG.GREY GOOSE', 1, 'UN', '[{"qty":"45","code":"LIC096","name":"BT.GREY GOOSE INS","unit":"ML"}]'),
  ('CC1159', 'TG.TITOS', 1, 'UN', '[{"qty":"45","code":"LIC165","name":"BT.TITOS VODKA INS","unit":"ML"}]'),
  ('CC1160', 'BT.BUCHANANS 12 AÑOS', 1, 'UN', '[{"qty":"750","code":"LIC042","name":"BT.BUCHANANS 12 INS","unit":"ML"}]'),
  ('CC1161', 'BT.BUCHANANS 18 AÑOS', 1, 'UN', '[{"qty":"750","code":"LIC043","name":"BT.BUCHANANS 18 INS","unit":"ML"}]'),
  ('CC1162', 'BT.JACK DANIELS N7', 1, 'UN', '[{"qty":"750","code":"LIC110","name":"BT.JACK DANIELS OLD N7 INS","unit":"ML"}]'),
  ('CC1163', 'BT.JACK DANIELS HONEY', 1, 'UN', '[{"qty":"750","code":"LIC109","name":"BT.JACK DANIELS HONEY INS","unit":"ML"}]'),
  ('CC1164', 'BT.OLD PARR', 1, 'UN', '[{"qty":"750","code":"LIC136","name":"BT.OLD PARR 12 INS","unit":"ML"}]'),
  ('CC1165', 'BT.GLENFIDDICH 12', 1, 'UN', '[{"qty":"750","code":"LIC085","name":"BT.GLENFIDDICH 12 INS","unit":"ML"}]'),
  ('CC1166', 'BT.MACALLAN 12', 1, 'UN', '[{"qty":"700","code":"LIC163","name":"BT.THE MACALLAN 12 AÑOS SHERRY CASK INS","unit":"ML"}]'),
  ('CC1167', 'BT.J.W BLACK LABEL', 1, 'UN', '[{"qty":"750","code":"LIC036","name":"BT.BLACK LABEL INS","unit":"ML"}]'),
  ('CC1168', 'TG.BUCHANANS 12 AÑOS', 1, 'UN', '[{"qty":"45","code":"LIC042","name":"BT.BUCHANANS 12 INS","unit":"ML"}]'),
  ('CC1169', 'TG.BUCHANANS 18 AÑOS', 1, 'UN', '[{"qty":"45","code":"LIC043","name":"BT.BUCHANANS 18 INS","unit":"ML"}]'),
  ('CC1170', 'TG.JACK DANIELS N7', 1, 'UN', '[{"qty":"45","code":"LIC110","name":"BT.JACK DANIELS OLD N7 INS","unit":"ML"}]'),
  ('CC1171', 'TG.JACK DANIELS HONEY', 1, 'UN', '[{"qty":"45","code":"LIC109","name":"BT.JACK DANIELS HONEY INS","unit":"ML"}]'),
  ('CC1172', 'TG.OLD PARR', 1, 'UN', '[{"qty":"45","code":"LIC136","name":"BT.OLD PARR 12 INS","unit":"ML"}]'),
  ('CC1173', 'TG.GLENFIDDICH 12', 1, 'UN', '[{"qty":"45","code":"LIC085","name":"BT.GLENFIDDICH 12 INS","unit":"ML"}]'),
  ('CC1174', 'TG.MACALLAN 12', 1, 'UN', '[{"qty":"45","code":"LIC163","name":"BT.THE MACALLAN 12 AÑOS SHERRY CASK INS","unit":"ML"}]'),
  ('CC1175', 'TG.J.W BLACK LABEL', 1, 'UN', '[{"qty":"45","code":"LIC036","name":"BT.BLACK LABEL INS","unit":"ML"}]'),
  ('CC1176', 'BT. BUCHANANS MASTER', 1, 'UN', '[{"qty":"750","code":"LIC044","name":"BT.BUCHANANS MASTER","unit":"ML"}]'),
  ('CC1177', 'TG. BUCHANANS MASTER', 1, 'UN', '[{"qty":"45","code":"LIC044","name":"BT.BUCHANANS MASTER","unit":"ML"}]'),
  ('CC1178', 'BT.DON JULIO 1942', 1, 'UN', '[{"qty":"750","code":"LIC070","name":"BT.DON JULIO 1942","unit":"ML"}]'),
  ('CC1179', 'TG.DON JULIO 1942', 1, 'UN', '[{"qty":"45","code":"LIC070","name":"BT.DON JULIO 1942","unit":"ML"}]'),
  ('CC1180', 'BT.DISARONNO', 1, 'UN', '[{"qty":"750","code":"LIC069","name":"BT.DISARONNO","unit":"ML"}]'),
  ('CC1181', 'TG.DISARONNO', 1, 'UN', '[{"qty":"45","code":"LIC069","name":"BT.DISARONNO","unit":"ML"}]'),
  ('CC1182', 'TRES CORDILLERAS ROSADA', 1, 'UN', '[{"qty":"1","code":"LIC003","name":"3 CORDILLERAS ROSADA","unit":"UN"}]'),
  ('CC1183', 'TRES CORDILLERAS MULATA', 1, 'UN', '[{"qty":"1","code":"LIC001","name":"3 CORDILLERAS MULATA","unit":"UN"}]'),
  ('CC1184', 'AD. ZUMO DE LIMON', 1, 'UN', '[{"qty":"60","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"}]'),
  ('CC1185', 'AD. MICHELADO', 1, 'UN', '[{"qty":"60","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"2","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"}]'),
  ('CC1186', 'SHOT CLAMATO', 1, 'UN', '[{"qty":"45","code":"BAR040","name":"CLAMATO BAR INS","unit":"ML"}]'),
  ('CC1190', 'AD. BANDEJA CITRICOS', 1, 'UN', '[{"qty":"150","code":"BAR096","name":"NARANJA BAR INS","unit":"GR"},{"qty":"120","code":"BAR074","name":"LIMON BAR INS","unit":"GR"},{"qty":"20","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"10","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"}]'),
  ('CC1191', 'TG. COINTREAU', 1, 'UN', '[{"qty":"45","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"}]'),
  ('CC1193', 'MARACUYADA', 1, 'UN', '[{"qty":"60","code":"SUBB016","name":"ALMIBAR DE MARACUYA","unit":"ML"},{"qty":"15","code":"BAR093","name":"MIEL DE AGAVE BAR INS","unit":"ML"},{"qty":"30","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"1","code":"SLIC037","name":"SODA INS","unit":"UN"},{"qty":"2","code":"BAR122","name":"TAJIN BAR INS","unit":"GR"},{"qty":"10","code":"BAR069","name":"HIERBABUENA BAR INS","unit":"GR"}]'),
  ('CC1194', 'SPRITE', 1, 'UN', '[{"qty":"1","code":"SLIC040","name":"SPRITE INS","unit":"UN"}]'),
  ('CC1195', 'GASEOSA CUATRO', 1, 'UN', '[{"qty":"1","code":"SLIC017","name":"G. CUATRO INS","unit":"UN"}]'),
  ('CC1196', 'AD. ZUMO PIÑA', 1, 'UN', '[{"qty":"60","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"}]'),
  ('CC1197', 'AD. DECANTER DE NARANJA', 1, 'UN', '[{"qty":"210","code":"BAR134","name":"ZUMO NARANJA BAR INS","unit":"ML"}]'),
  ('CC1198', '2X1 FORASTERO', 1, 'UN', '[{"qty":"1.5","code":"LIC020","name":"BT.AMARILLO MANZANARES INS","unit":"L"}]'),
  ('CC1199', 'AGUA VOSS', 1, 'UN', '[{"qty":"1","code":"SLIC008","name":"AGUA VOSS INS","unit":"UN"}]'),
  ('CC1206', 'CHANDON ROSE', 1, 'UN', '[{"qty":"1","code":"LIC216","name":"VE. BRUT ROSE CHANDON","unit":"UN"}]'),
  ('CC1208', 'MARGARITAS 2X1', 1, 'UN', '[{"qty":"120","code":"LIC052","name":"BT.CAZADORES REPOSADO INS","unit":"ML"},{"qty":"45","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"},{"qty":"15","code":"BAR093","name":"MIEL DE AGAVE BAR INS","unit":"ML"},{"qty":"60","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"5","code":"BAR114","name":"SAL FINA BAR INS","unit":"GR"},{"qty":"2","code":"BAR139","name":"LIMON DESHIDRATADO BAR INS","unit":"UN"}]'),
  ('CC1209', 'CANADA DRY', 1, 'UN', '[{"qty":"1","code":"SLIC011","name":"CANADA DRY INS","unit":"UN"}]'),
  ('CC1211', 'AGUA VOSS CON GAS', 1, 'UN', '[{"qty":"1","code":"SLIC007","name":"AGUA VOS CARBONATADA INS","unit":"UN"}]'),
  ('CC1212', 'TRES PATADAS HAPPENIN', 1, 'UN', '[{"qty":"90","code":"LIC157","name":"BT.SMIRNOFF TAMARINDO INS","unit":"ML"},{"qty":"45","code":"LIC174","name":"BT.CONVIER MARACUYA INS","unit":"ML"},{"qty":"45","code":"SUBB011","name":"CONCENTRADO DE TAMARINDO","unit":"ML"},{"qty":"20","code":"SUBB008","name":"MIEL DE CHILES","unit":"GR"},{"qty":"60","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"},{"qty":"90","code":"SUBB010","name":"ZUMO DE PIÑA","unit":"ML"},{"qty":"1","code":"SLIC018","name":"G. NARANJA INS","unit":"UN"}]'),
  ('CC1213', 'PERLA NEGRA CUMPLEAÑOS', 1, 'UN', '[{"qty":"45","code":"LIC112","name":"BT.JAGERMAISTER INS","unit":"ML"},{"qty":"1","code":"SLIC010","name":"AMPER BLUE INS","unit":"UN"}]'),
  ('CC1214', 'AD. DECANTER LIMON', 1, 'UN', '[{"qty":"210","code":"SUBB020","name":"ZUMO LIMON BAR","unit":"ML"}]'),
  ('CC1215', 'AD. DECANTER CRANBERRY', 1, 'UN', '[{"qty":"210","code":"BAR071","name":"JUGO DE ARANDANOS INS","unit":"ML"}]'),
  ('CC1216', 'AD. DECANTER COINTREAU', 1, 'UN', '[{"qty":"210","code":"LIC061","name":"BT.COINTREAU INS","unit":"ML"}]'),
  ('CC1217', 'AD. DECANTER ALMIBAR SIMPLE', 1, 'UN', '[{"qty":"210","code":"SUBB001","name":"ALMIBAR SIMPLE","unit":"ML"}]'),
  ('CC1218', 'MD. ANTIOQUEÑO VERDE', 1, 'UN', '[{"qty":"1","code":"LIC281","name":"MD. ANTIOQUEÑO VERDE","unit":"UN"}]')
)
insert into public.recipes (code, name, yield_qty, yield_unit, ingredients, location_id, area_id)
select d.code, d.name, d.yield_qty::numeric, d.yield_unit, d.ingredients::jsonb, t.location_id, t.area_id
from datos d cross join destino t
where not exists (select 1 from public.recipes r where r.area_id = t.area_id and r.code = d.code);

-- Resultado: recetas de barra por punto
select l.name as punto,
       count(*) filter (where r.code like 'SUBB%') as subrecetas,
       count(*) filter (where r.code not like 'SUBB%') as productos
from public.recipes r join public.areas a on a.id = r.area_id join public.locations l on l.id = r.location_id
where lower(trim(a.name)) = 'barra' and l.slug in ('canta-corazon-mtdsga9t')
group by l.name;
