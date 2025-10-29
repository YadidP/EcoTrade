-- db/init/04_seeds.sql

-- 1. Poblar la tabla de roles
INSERT INTO roles (name) VALUES
('comun'),
('emprendedor'),
('admin')
ON CONFLICT (name) DO NOTHING;

-- 2. Poblar la tabla de métricas ambientales (EXPANDIDO)
INSERT INTO metrics (name, unit) VALUES
('CO2', 'kg'),
('Agua', 'litros'),
('Energía', 'kWh'),
('Residuos Plásticos', 'g'),
('Consumo de Suelo', 'm2'),
('Pesticidas', 'g'),
('Metales (Acero)', 'kg'),
('Metales (Aluminio)', 'g')
ON CONFLICT (name) DO NOTHING;

-- 3. Poblar categorías (EXPANDIDO)
INSERT INTO categories (name) VALUES 
('Ropa y Calzado'), 
('Educación'), 
('Tecnología'), 
('Hogar y Jardín'), 
('Juguetes y Ocio'),
('Herramientas'),
('Deportes y Fitness')
ON CONFLICT (name) DO NOTHING;

-- 4. Poblar subcategorías (EXPANDIDO Y MÁS ESPECÍFICO)
INSERT INTO subcategories (category_id, name, unit_of_measure) VALUES
-- Ropa y Calzado
((SELECT id FROM categories WHERE name = 'Ropa y Calzado'), 'Prenda de Algodón', 'kg'),
((SELECT id FROM categories WHERE name = 'Ropa y Calzado'), 'Prenda de Poliéster', 'kg'),
((SELECT id FROM categories WHERE name = 'Ropa y Calzado'), 'Calzado de Cuero', 'unidad'),
((SELECT id FROM categories WHERE name = 'Ropa y Calzado'), 'Calzado Sintético', 'unidad'),
-- Educación
((SELECT id FROM categories WHERE name = 'Educación'), 'Libro de papel', 'página'),
((SELECT id FROM categories WHERE name = 'Educación'), 'Cuaderno', 'kg'),
-- Tecnología
((SELECT id FROM categories WHERE name = 'Tecnología'), 'Celular', 'unidad'),
((SELECT id FROM categories WHERE name = 'Tecnología'), 'Cables y Cargadores', 'kg'),
((SELECT id FROM categories WHERE name = 'Tecnología'), 'Dispositivo electrónico (Genérico)', 'kg'),
-- Hogar y Jardín
((SELECT id FROM categories WHERE name = 'Hogar y Jardín'), 'Muebles de Madera', 'kg'),
((SELECT id FROM categories WHERE name = 'Hogar y Jardín'), 'Envases de Vidrio', 'kg'),
((SELECT id FROM categories WHERE name = 'Hogar y Jardín'), 'Envases de Plástico (PET)', 'kg'),
-- Juguetes y Ocio
((SELECT id FROM categories WHERE name = 'Juguetes y Ocio'), 'Juguetes de Plástico', 'kg'),
-- Herramientas
((SELECT id FROM categories WHERE name = 'Herramientas'), 'Herramienta (Acero)', 'kg'),
-- Deportes
((SELECT id FROM categories WHERE name = 'Deportes y Fitness'), 'Bicicleta', 'unidad')
ON CONFLICT (name, category_id) DO NOTHING;

-- 5. Poblar tabla de equivalencias (¡AMPLIADO MASIVAMENTE!)
INSERT INTO equivalences (subcategory_id, metric_id, value_per_unit) VALUES
-- Por 'página' de 'Libro de papel'
((SELECT id FROM subcategories WHERE name = 'Libro de papel'), (SELECT id FROM metrics WHERE name = 'CO2'), 0.01),
((SELECT id FROM subcategories WHERE name = 'Libro de papel'), (SELECT id FROM metrics WHERE name = 'Agua'), 0.1),
-- Por 'kg' de 'Prenda de Algodón'
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'CO2'), 8.0),
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'Agua'), 2700.0),
((SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'), (SELECT id FROM metrics WHERE name = 'Pesticidas'), 150.0),
-- Por 'kg' de 'Prenda de Poliéster'
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'CO2'), 25.0),
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'Agua'), 10.0),
((SELECT id FROM subcategories WHERE name = 'Prenda de Poliéster'), (SELECT id FROM metrics WHERE name = 'Energía'), 40.0),
-- Por 'unidad' de 'Calzado de Cuero'
((SELECT id FROM subcategories WHERE name = 'Calzado de Cuero'), (SELECT id FROM metrics WHERE name = 'CO2'), 20.0),
((SELECT id FROM subcategories WHERE name = 'Calzado de Cuero'), (SELECT id FROM metrics WHERE name = 'Agua'), 8000.0),
-- Por 'kg' de 'Juguetes de Plástico'
((SELECT id FROM subcategories WHERE name = 'Juguetes de Plástico'), (SELECT id FROM metrics WHERE name = 'CO2'), 3.0),
((SELECT id FROM subcategories WHERE name = 'Juguetes de Plástico'), (SELECT id FROM metrics WHERE name = 'Residuos Plásticos'), 1000.0),

-- NUEVAS EQUIVALENCIAS
-- Por 'unidad' de 'Celular'
((SELECT id FROM subcategories WHERE name = 'Celular'), (SELECT id FROM metrics WHERE name = 'CO2'), 60.0), -- 60 kg CO2 / unidad
((SELECT id FROM subcategories WHERE name = 'Celular'), (SELECT id FROM metrics WHERE name = 'Agua'), 12000.0), -- 12,000 L Agua / unidad
((SELECT id FROM subcategories WHERE name = 'Celular'), (SELECT id FROM metrics WHERE name = 'Metales (Aluminio)'), 30.0), -- 30g Aluminio / unidad
-- Por 'kg' de 'Envases de Vidrio'
((SELECT id FROM subcategories WHERE name = 'Envases de Vidrio'), (SELECT id FROM metrics WHERE name = 'CO2'), 0.8), -- 0.8 kg CO2 / kg vidrio
((SELECT id FROM subcategories WHERE name = 'Envases de Vidrio'), (SELECT id FROM metrics WHERE name = 'Energía'), 1.1), -- 1.1 kWh / kg vidrio
-- Por 'kg' de 'Envases de Plástico (PET)'
((SELECT id FROM subcategories WHERE name = 'Envases de Plástico (PET)'), (SELECT id FROM metrics WHERE name = 'CO2'), 2.3), -- 2.3 kg CO2 / kg PET
((SELECT id FROM subcategories WHERE name = 'Envases de Plástico (PET)'), (SELECT id FROM metrics WHERE name = 'Residuos Plásticos'), 1000.0), -- 1000 g / kg
-- Por 'unidad' de 'Bicicleta'
((SELECT id FROM subcategories WHERE name = 'Bicicleta'), (SELECT id FROM metrics WHERE name = 'CO2'), 90.0), -- 90 kg CO2 / unidad
((SELECT id FROM subcategories WHERE name = 'Bicicleta'), (SELECT id FROM metrics WHERE name = 'Metales (Acero)'), 12.0), -- 12 kg Acero / unidad
((SELECT id FROM subcategories WHERE name = 'Bicicleta'), (SELECT id FROM metrics WHERE name = 'Metales (Aluminio)'), 2000.0), -- 2000g Aluminio / unidad
-- Por 'kg' de 'Herramienta (Acero)'
((SELECT id FROM subcategories WHERE name = 'Herramienta (Acero)'), (SELECT id FROM metrics WHERE name = 'CO2'), 1.8), -- 1.8 kg CO2 / kg acero
((SELECT id FROM subcategories WHERE name = 'Herramienta (Acero)'), (SELECT id FROM metrics WHERE name = 'Energía'), 5.5), -- 5.5 kWh / kg acero
((SELECT id FROM subcategories WHERE name = 'Herramienta (Acero)'), (SELECT id FROM metrics WHERE name = 'Metales (Acero)'), 1.0) -- 1 kg Acero / kg

ON CONFLICT (subcategory_id, metric_id) DO UPDATE SET value_per_unit = EXCLUDED.value_per_unit;

-- 6. Crear usuarios (comun, emprendedor, admin)
INSERT INTO users (name, email, password_hash, role_id) VALUES
('Usuario Comun', 'comun@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'comun')),
('Emprendedor Eco', 'emprendedor@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'emprendedor')),
('Admin', 'admin@example.com', '$2b$10$E.ExP6p33v4O9Z/z4v0Zye.iX0/awE7G/f3rXDIxYy.p3JjlsLp8W', (SELECT id FROM roles WHERE name = 'admin'))
ON CONFLICT (email) DO NOTHING;

-- 7. Crear billeteras
INSERT INTO wallets (user_id, balance) VALUES
((SELECT id FROM users WHERE email = 'comun@example.com'), 100.00),
((SELECT id FROM users WHERE email = 'emprendedor@example.com'), 50.00),
((SELECT id FROM users WHERE email = 'admin@example.com'), 10000.00)
ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance;

-- 8. Crear publicaciones de ejemplo (ACTUALIZADAS Y EXPANDIDAS)
INSERT INTO listings (author_id, title, description, subcategory_id, unit_credits, quantity, metric_quantity, image_url, status) VALUES
-- Publicación: Libro
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Libro de Cálculo I Usado', 'Libro de cálculo en buen estado, 300 páginas.',
 (SELECT id FROM subcategories WHERE name = 'Libro de papel'),
 50, 5, 300, 'https://placehold.co/600x400/5A9/FFF?text=Libro+Cálculo'
),
-- Publicación: Ropa (Algodón)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Jeans de Algodón (Segunda Mano)', 'Jeans talla 32, 100% algodón. Peso 0.8kg.',
 (SELECT id FROM subcategories WHERE name = 'Prenda de Algodón'),
 30, 10, 0.8, 'https://placehold.co/600x400/3A7/FFF?text=Jeans+Algodón'
),
-- Publicación: Calzado (Sintético)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Zapatillas Deportivas Sintéticas', 'Par de zapatillas talla 41, material sintético.',
 (SELECT id FROM subcategories WHERE name = 'Calzado Sintético'),
 80, 3, 1, 'https://placehold.co/600x400/9A3/FFF?text=Zapatillas'
),
-- Publicación: Celular (NUEVO)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Celular Reacondicionado', 'Smartphone 128GB, funciona perfectamente.',
 (SELECT id FROM subcategories WHERE name = 'Celular'),
 250, 2, 1, 'https://placehold.co/600x400/333/FFF?text=Celular'
),
-- Publicación: Bicicleta (NUEVO)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Bicicleta de Montaña Usada', 'Bicicleta aro 26, en buen estado.',
 (SELECT id FROM subcategories WHERE name = 'Bicicleta'),
 400, 1, 1, 'https://placehold.co/600x400/795/FFF?text=Bicicleta'
),
-- Publicación: Botellas (NUEVO)
((SELECT id FROM users WHERE email = 'emprendedor@example.com'),
 'Lote de 5kg de Botellas de Vidrio', 'Aprox 5kg de botellas limpias para reutilizar.',
 (SELECT id FROM subcategories WHERE name = 'Envases de Vidrio'),
 15, 10, 5, 'https://placehold.co/600x400/ACE/FFF?text=Vidrio'
)
ON CONFLICT (id) DO NOTHING;
