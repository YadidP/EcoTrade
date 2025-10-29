-- db/init/04_seeds.sql

-- 1. Poblar la tabla de roles
INSERT INTO roles (name) VALUES
('comun'),
('emprendedor'),
('admin')
ON CONFLICT (name) DO NOTHING;

-- 2. Poblar la tabla de métricas ambientales (CON PESTICIDAS)
INSERT INTO metrics (name, unit) VALUES
('CO2', 'kg'),
('Agua', 'litros'),
('Energía', 'kWh'),
('Residuos Plásticos', 'g'),
('Consumo de Suelo', 'm2'),
('Pesticidas', 'g') -- Nueva métrica
ON CONFLICT (name) DO NOTHING;

-- 3. Poblar categorías
INSERT INTO categories (name) VALUES 
('Ropa'), 
('Educación'), 
('Tecnología'), 
('Hogar y Jardín'), 
('Juguetes y Ocio') 
ON CONFLICT (name) DO NOTHING;

-- 4. Poblar subcategorías (MÁS ESPECÍFICAS)
INSERT INTO subcategories (category_id, name, unit_of_measure) VALUES
-- Ropa (dividido por material)
((SELECT id FROM categories WHERE name = 'Ropa'), 'Prenda de Algodón', 'kg'),
((SELECT id FROM categories WHERE name = 'Ropa'), 'Prenda de Poliéster', 'kg'),
((SELECT id FROM categories WHERE name = 'Ropa'), 'Calzado de Cuero', 'unidad'),
((SELECT id FROM categories WHERE name = 'Ropa'), 'Calzado Sintético', 'unidad'),
-- Educación
((SELECT id FROM categories WHERE name = 'Educación'), 'Libro de papel', 'página'),
((SELECT id FROM categories WHERE name = 'Educación'), 'Material de oficina', 'unidad'),
-- Tecnología
((SELECT id FROM categories WHERE name = 'Tecnología'), 'Dispositivo electrónico pequeño', 'kg'),
-- Hogar
((SELECT id FROM categories WHERE name = 'Hogar y Jardín'), 'Muebles', 'kg'),
-- Juguetes
((SELECT id FROM categories WHERE name = 'Juguetes y Ocio'), 'Juguetes de Plástico', 'kg')
ON CONFLICT (name, category_id) DO NOTHING;

-- 5. Poblar tabla de equivalencias (¡AMPLIADO Y MÁS PRECISO!)
INSERT INTO equivalences (subcategory_id, metric_id, value_per_unit) VALUES
-- Por 'página' de 'Libro de papel' (mantiene valores)
((SELECT id FROM subcategories WHERE name = 'Libro de papel'), (SELECT id FROM metrics WHERE name = 'CO2'), 0.01),
((SELECT id FROM subcategories WHERE name = 'Libro de papel'), (SELECT id FROM metrics WHERE name = 'Agua'), 0.1),

-- Por 'kg' de 'Prenda de Algodón' (Alto en agua y pesticidas)
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'CO2'), 8.0), -- 8 kg CO2 / kg
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'Agua'), 2700.0), -- 2700 L Agua / kg
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'Pesticidas'), 150.0), -- 150 g Pesticidas / kg

-- Por 'kg' de 'Prenda de Poliéster' (Alto en CO2 y Energía, bajo en agua)
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'CO2'), 25.0), -- 25 kg CO2 / kg
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'Agua'), 10.0), -- 10 L Agua / kg
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'Energía'), 40.0), -- 40 kWh / kg

-- Por 'unidad' de 'Calzado de Cuero' (Alto en todo)
((SELECT id FROM subcategories WHERE name = 'Calzado de Cuero'), (SELECT id FROM metrics WHERE name = 'CO2'), 20.0), -- 20 kg CO2 / par
((SELECT id FROM subcategories WHERE name = 'Calzado de Cuero'), (SELECT id FROM metrics WHERE name = 'Agua'), 8000.0), -- 8000 L Agua / par
((SELECT id FROM subcategories WHERE name = 'Calzado de Cuero'), (SELECT id FROM metrics WHERE name = 'Energía'), 15.0), -- 15 kWh / par

-- Por 'unidad' de 'Calzado Sintético' (Menos agua, más CO2 que cuero)
((SELECT id FROM subcategories WHERE name = 'Calzado Sintético'), (SELECT id FROM metrics WHERE name = 'CO2'), 12.0), -- 12 kg CO2 / par
((SELECT id FROM subcategories WHERE name = 'Calzado Sintético'), (SELECT id FROM metrics WHERE name = 'Agua'), 50.0), -- 50 L Agua / par
((SELECT id FROM subcategories WHERE name = 'Calzado Sintético'), (SELECT id FROM metrics WHERE name = 'Energía'), 10.0), -- 10 kWh / par

-- Por 'kg' de 'Juguetes de Plástico'
((SELECT id FROM subcategories WHERE name = 'Juguetes de Plástico'), (SELECT id FROM metrics WHERE name = 'CO2'), 3.0),
((SELECT id FROM subcategories WHERE name = 'Juguetes de Plástico'), (SELECT id FROM metrics WHERE name = 'Residuos Plásticos'), 1000.0)

ON CONFLICT (subcategory_id, metric_id) DO UPDATE SET value_per_unit = EXCLUDED.value_per_unit;

-- 6. Crear usuarios (comun, emprendedor, admin)
-- La contraseña para todos es '1234' (hasheada)
INSERT INTO users (name, email, password_hash, role_id) VALUES
('Usuario Comun', 'comun@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'comun')),
('Emprendedor Eco', 'emprendedor@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'emprendedor')),
('Admin', 'admin@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'admin'))
ON CONFLICT (email) DO NOTHING;

-- 7. Crear billeteras para los usuarios
-- (Los triggers de bono de bienvenida ya les darán 10 créditos, aquí añadimos más)
INSERT INTO wallets (user_id, balance) VALUES
((SELECT id FROM users WHERE email = 'comun@example.com'), 100.00),
((SELECT id FROM users WHERE email = 'emprendedor@example.com'), 50.00),
((SELECT id FROM users WHERE email = 'admin@example.com'), 10000.00)
ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance; -- O simplemente no hacer nada si ya existen

-- 8. Crear publicaciones de ejemplo (ACTUALIZADAS a subcategorías específicas)
INSERT INTO listings (author_id, title, description, subcategory_id, unit_credits, quantity, metric_quantity, image_url, status) VALUES
-- Publicación del emprendedor: Libro
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Libro de Cálculo I Usado',
 'Libro de cálculo en buen estado, ideal para estudiantes.',
 (SELECT id FROM subcategories WHERE name = 'Libro de papel'),
 50, -- créditos que pide el usuario por 1 libro
 5,  -- stock (5 libros)
 300, -- métrica base (300 páginas)
 'https://placehold.co/600x400/5A9/FFF?text=Libro+Cálculo'
),
-- Publicación del emprendedor: Ropa (Algodón)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Jeans de Algodón (Segunda Mano)',
 'Jeans talla 32, 100% algodón. El peso aproximado es 0.8kg.',
 (SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), -- Subcategoría específica
 30, -- créditos por 1 jean
 10, -- stock (10 jeans)
 0.8, -- métrica base (0.8 kg)
 'https://placehold.co/600x400/3A7/FFF?text=Jeans+Algodón'
),
-- Publicación del emprendedor: Calzado (Sintético)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Zapatillas Deportivas Sintéticas',
 'Par de zapatillas talla 41, material sintético, limpias y en buen estado.',
 (SELECT id FROM subcategories WHERE name = 'Calzado Sintético'), -- Subcategoría específica
 80, -- créditos por 1 par
 3,  -- stock (3 pares)
 1,  -- métrica base (1 unidad/par)
 'https."//placehold.co/600x400/9A3/FFF?text=Zapatillas+Sintéticas'
),
-- Nueva Publicación: Ropa (Poliéster)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Camisa Deportiva Poliéster',
 'Camisa de poliéster para correr, secado rápido. Peso 0.3kg',
 (SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), -- Subcategoría específica
 25, -- créditos
 15, -- stock
 0.3, -- métrica base (0.3 kg)
 'https://placehold.co/600x400/A39/FFF?text=Camisa+Poliéster'
)
ON CONFLICT (id) DO NOTHING; -- O define una política de conflicto adecuada

