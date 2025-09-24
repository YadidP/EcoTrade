-- Categorías base y factores de CO2 (aprox)
INSERT INTO categories (name, co2_factor) VALUES
('Ropa', 2.0),
('Tecnología', 10.0),
('Educación', 0.0),
('Transporte', 0.5),
('Hogar', 5.0),
('Servicios', 0.0)
ON CONFLICT (name) DO NOTHING;
