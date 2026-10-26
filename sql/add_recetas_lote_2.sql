-- Lote de 7 recetas/subrecetas nuevas
-- Área: Cocina — Puntos: Cantina Dos Santos y Dos Santos Cali
-- Códigos asignados: SUBC098 a SUBC104 (siguiente disponible tras SUBC097)
--
-- Supuestos tomados al mapear ingredientes de la ficha al catálogo (revisar y corregir
-- desde el recetario si algún SKU no es el correcto):
--   - AZUCAR -> AZUCAR BLANCA INS (ABA022)
--   - SAL -> SAL FINA INS (ABA145)
--   - LIMON / JUGO DE LIMON -> LIMON TAHITI INS (FRV063), no hay subreceta "jugo de limón"
--     cargada en estos dos puntos (sí existe en Canta Corazón, SUBC004)
--   - CLARAS HUEVO -> HUEVOS INS (ABA089), no hay SKU separado de claras
--   - CEBOLLA BLANCA -> CEBOLLA CABEZONA INS (FRV019)
--   - ACEITE GIRASOL / ACEITE VEGETAL -> ACEITE DE GIRASOL INS (ABA003)
--   - OREGANO -> OREGANO EN POLVO INS (ABA117)
--   - JUGO DE NARANJA -> NARANJA VALENCIA INS (FRV078), sin subreceta de jugo cargada
--   - ACHIOTE EN PASTA -> subreceta PASTA ACHIOTE (SUBC053), ya cargada en ambos puntos
--   - ASADO DE TIRA -> COSTILLA DE RES INS (PRO014), confirmado con el usuario
--   - LECHE DE TIGRE, CALDO DE BIRRIA, BIRRIA PORCION, MIX QUESO FUERTE -> subrecetas ya
--     existentes (SUBC031, SUBC009, SUBC014, SUBC047)
--   - AGUA -> sin código de insumo (se usa code="AGUA", igual que otras recetas ya cargadas)
--
-- Rendimientos no indicados en la ficha:
--   - MERENGUE PAVLOVA: se deja yield_qty/yield_unit en NULL (no vino dato)
--   - COCCION ASADO DE TIRA: 20 UNIDAD, confirmado con el usuario (piezas de asado de
--     tira de 450g c/u; verduras y vino tinto son aromáticos de la cocción)
--   - PASTA PIMENTO VERDE Y CHILE SECO: sin vida útil/almacenamiento en la ficha, no se
--     agrega observación para esa receta

insert into recipes (code, name, yield_qty, yield_unit, ingredients, location_id, area_id)
values
-- SUBC098 - SEMILLA DE CALABAZA GARRAPIÑADA
('SUBC098','SEMILLA DE CALABAZA GARRAPIÑADA',0.1,'KG',
 '[{"qty":"100","code":"FRV103","name":"SEMILLAS DE CALABAZA INS","unit":"GR"},
   {"qty":"60","code":"ABA022","name":"AZUCAR BLANCA INS","unit":"GR"},
   {"qty":"20","code":"AGUA","name":"AGUA","unit":"GR"},
   {"qty":"1","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC098','SEMILLA DE CALABAZA GARRAPIÑADA',0.1,'KG',
 '[{"qty":"100","code":"FRV103","name":"SEMILLAS DE CALABAZA INS","unit":"GR"},
   {"qty":"60","code":"ABA022","name":"AZUCAR BLANCA INS","unit":"GR"},
   {"qty":"20","code":"AGUA","name":"AGUA","unit":"GR"},
   {"qty":"1","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC099 - MERENGUE PAVLOVA
('SUBC099','MERENGUE PAVLOVA',null,null,
 '[{"qty":"150","code":"ABA089","name":"HUEVOS INS","unit":"GR"},
   {"qty":"270","code":"ABA022","name":"AZUCAR BLANCA INS","unit":"GR"},
   {"qty":"12","code":"ABA070","name":"FECULA INS","unit":"GR"},
   {"qty":"8","code":"ABA173","name":"VINAGRE BLANCO INS","unit":"GR"},
   {"qty":"2","code":"FRV063","name":"LIMON TAHITI INS","unit":"GR"},
   {"qty":"1","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC099','MERENGUE PAVLOVA',null,null,
 '[{"qty":"150","code":"ABA089","name":"HUEVOS INS","unit":"GR"},
   {"qty":"270","code":"ABA022","name":"AZUCAR BLANCA INS","unit":"GR"},
   {"qty":"12","code":"ABA070","name":"FECULA INS","unit":"GR"},
   {"qty":"8","code":"ABA173","name":"VINAGRE BLANCO INS","unit":"GR"},
   {"qty":"2","code":"FRV063","name":"LIMON TAHITI INS","unit":"GR"},
   {"qty":"1","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC100 - COCCION ASADO DE TIRA
('SUBC100','COCCION ASADO DE TIRA',20,'UNIDAD',
 '[{"qty":"20","code":"PRO014","name":"COSTILLA DE RES INS","unit":"UNIDAD"},
   {"qty":"300","code":"FRV117","name":"ZANAHORIA INS","unit":"GR"},
   {"qty":"300","code":"FRV019","name":"CEBOLLA CABEZONA INS","unit":"GR"},
   {"qty":"60","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"7","code":"FRV114","name":"TOMILLO INS","unit":"GR"},
   {"qty":"300","code":"FRV011","name":"APIO INS","unit":"GR"},
   {"qty":"2000","code":"ABA177","name":"VINO TINTO INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC100','COCCION ASADO DE TIRA',20,'UNIDAD',
 '[{"qty":"20","code":"PRO014","name":"COSTILLA DE RES INS","unit":"UNIDAD"},
   {"qty":"300","code":"FRV117","name":"ZANAHORIA INS","unit":"GR"},
   {"qty":"300","code":"FRV019","name":"CEBOLLA CABEZONA INS","unit":"GR"},
   {"qty":"60","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"7","code":"FRV114","name":"TOMILLO INS","unit":"GR"},
   {"qty":"300","code":"FRV011","name":"APIO INS","unit":"GR"},
   {"qty":"2000","code":"ABA177","name":"VINO TINTO INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC101 - PASTA PIMENTO VERDE Y CHILE SECO
('SUBC101','PASTA PIMENTO VERDE Y CHILE SECO',0.6,'KG',
 '[{"qty":"450","code":"FRV091","name":"PIMENTON VERDE INS","unit":"GR"},
   {"qty":"180","code":"FRV004","name":"AJI DULCE INS","unit":"GR"},
   {"qty":"180","code":"FRV019","name":"CEBOLLA CABEZONA INS","unit":"GR"},
   {"qty":"20","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"25","code":"ABA046","name":"CHILE PASILLA INS","unit":"GR"},
   {"qty":"25","code":"ABA003","name":"ACEITE DE GIRASOL INS","unit":"GR"},
   {"qty":"10","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC101','PASTA PIMENTO VERDE Y CHILE SECO',0.6,'KG',
 '[{"qty":"450","code":"FRV091","name":"PIMENTON VERDE INS","unit":"GR"},
   {"qty":"180","code":"FRV004","name":"AJI DULCE INS","unit":"GR"},
   {"qty":"180","code":"FRV019","name":"CEBOLLA CABEZONA INS","unit":"GR"},
   {"qty":"20","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"25","code":"ABA046","name":"CHILE PASILLA INS","unit":"GR"},
   {"qty":"25","code":"ABA003","name":"ACEITE DE GIRASOL INS","unit":"GR"},
   {"qty":"10","code":"ABA145","name":"SAL FINA INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC102 - MARINACION PESCA
('SUBC102','MARINACION PESCA',0.25,'KG',
 '[{"qty":"35","code":"ABA042","name":"CHILE GUAJILLO INS","unit":"GR"},
   {"qty":"15","code":"ABA038","name":"CHILE ANCHO INS","unit":"GR"},
   {"qty":"20","code":"SUBC053","name":"PASTA ACHIOTE","unit":"GR"},
   {"qty":"7","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"60","code":"FRV063","name":"LIMON TAHITI INS","unit":"GR"},
   {"qty":"90","code":"FRV078","name":"NARANJA VALENCIA INS","unit":"GR"},
   {"qty":"50","code":"ABA003","name":"ACEITE DE GIRASOL INS","unit":"GR"},
   {"qty":"10","code":"ABA145","name":"SAL FINA INS","unit":"GR"},
   {"qty":"1","code":"ABA059","name":"COMINO EN POLVO INS","unit":"GR"},
   {"qty":"1","code":"ABA117","name":"OREGANO EN POLVO INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC102','MARINACION PESCA',0.25,'KG',
 '[{"qty":"35","code":"ABA042","name":"CHILE GUAJILLO INS","unit":"GR"},
   {"qty":"15","code":"ABA038","name":"CHILE ANCHO INS","unit":"GR"},
   {"qty":"20","code":"SUBC053","name":"PASTA ACHIOTE","unit":"GR"},
   {"qty":"7","code":"FRV009","name":"AJO INS","unit":"GR"},
   {"qty":"60","code":"FRV063","name":"LIMON TAHITI INS","unit":"GR"},
   {"qty":"90","code":"FRV078","name":"NARANJA VALENCIA INS","unit":"GR"},
   {"qty":"50","code":"ABA003","name":"ACEITE DE GIRASOL INS","unit":"GR"},
   {"qty":"10","code":"ABA145","name":"SAL FINA INS","unit":"GR"},
   {"qty":"1","code":"ABA059","name":"COMINO EN POLVO INS","unit":"GR"},
   {"qty":"1","code":"ABA117","name":"OREGANO EN POLVO INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC103 - LECHE DE TIGRE MARACUYA
('SUBC103','LECHE DE TIGRE MARACUYA',0.5,'KG',
 '[{"qty":"350","code":"SUBC031","name":"LECHE DE TIGRE","unit":"GR"},
   {"qty":"180","code":"FRV071","name":"MARACUYA INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC103','LECHE DE TIGRE MARACUYA',0.5,'KG',
 '[{"qty":"350","code":"SUBC031","name":"LECHE DE TIGRE","unit":"GR"},
   {"qty":"180","code":"FRV071","name":"MARACUYA INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

-- SUBC104 - CROQUETA BIRRIA
('SUBC104','CROQUETA BIRRIA',35,'UNIDAD',
 '[{"qty":"10","code":"SUBC014","name":"CARNE DE BIRRIA PORCION","unit":"UNIDAD"},
   {"qty":"5","code":"SUBC047","name":"MIX QUESOS FUERTES","unit":"UNIDAD"},
   {"qty":"60","code":"ABA085","name":"HARINA DE TRIGO INS","unit":"GR"},
   {"qty":"60","code":"LAC006","name":"MANTEQUILLA INS","unit":"GR"},
   {"qty":"300","code":"SUBC009","name":"CALDO DE BIRRIA","unit":"GR"},
   {"qty":"5","code":"ABA089","name":"HUEVOS INS","unit":"UNIDAD"},
   {"qty":"500","code":"ABA124","name":"PANKO INS","unit":"GR"}]'::jsonb,
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC104','CROQUETA BIRRIA',35,'UNIDAD',
 '[{"qty":"10","code":"SUBC014","name":"CARNE DE BIRRIA PORCION","unit":"UNIDAD"},
   {"qty":"5","code":"SUBC047","name":"MIX QUESOS FUERTES","unit":"UNIDAD"},
   {"qty":"60","code":"ABA085","name":"HARINA DE TRIGO INS","unit":"GR"},
   {"qty":"60","code":"LAC006","name":"MANTEQUILLA INS","unit":"GR"},
   {"qty":"300","code":"SUBC009","name":"CALDO DE BIRRIA","unit":"GR"},
   {"qty":"5","code":"ABA089","name":"HUEVOS INS","unit":"UNIDAD"},
   {"qty":"500","code":"ABA124","name":"PANKO INS","unit":"GR"}]'::jsonb,
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d');

insert into observations (recipe_code, author, note, location_id, area_id)
values
('SUBC098','Sistema','Vida útil: 15 días. Almacenamiento: Ambiente.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC098','Sistema','Vida útil: 15 días. Almacenamiento: Ambiente.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

('SUBC099','Sistema','Vida útil: 5 días. Almacenamiento: Ambiente. Claras de huevo = 6 huevos. Fécula tamizada. Ralladura de limón.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC099','Sistema','Vida útil: 5 días. Almacenamiento: Ambiente. Claras de huevo = 6 huevos. Fécula tamizada. Ralladura de limón.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

('SUBC100','Sistema','Vida útil: 20 días. Almacenamiento: Congelación. Rendimiento = piezas de asado de tira (450g c/u); verduras y vino tinto son aromáticos de la cocción.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC100','Sistema','Vida útil: 20 días. Almacenamiento: Congelación. Rendimiento = piezas de asado de tira (450g c/u); verduras y vino tinto son aromáticos de la cocción.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

('SUBC102','Sistema','Vida útil: 10 días. Almacenamiento: Refrigeración. Chile guajillo y ancho sin semilla. Ajo pelado.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC102','Sistema','Vida útil: 10 días. Almacenamiento: Refrigeración. Chile guajillo y ancho sin semilla. Ajo pelado.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

('SUBC103','Sistema','Vida útil: 5 días. Almacenamiento: Refrigeración.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC103','Sistema','Vida útil: 5 días. Almacenamiento: Refrigeración.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d'),

('SUBC104','Sistema','Vida útil: 8 días. Almacenamiento: Refrigeración. Empaque: 30 g x 35 und.',
 'c98db3a9-7be7-4bf6-8b77-318e6ca3098b','337c3186-0313-4d88-94cb-9de043757afb'),
('SUBC104','Sistema','Vida útil: 8 días. Almacenamiento: Refrigeración. Empaque: 30 g x 35 und.',
 '5b939dca-4d4d-455b-ad72-f21bedbfcbea','48a91382-4b92-4f71-9a8d-57bd255a5b8d');
