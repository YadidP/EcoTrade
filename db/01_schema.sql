-- db/init/01_schema.sql
-- Extensión para generar UUIDs si es necesario (aunque no se usa en este esquema principal)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --- ESTRUCTURA DE AUTENTICACIÓN Y USUARIOS ---

-- Define los roles del sistema
CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL -- ('comun', 'emprendedor', 'admin')
);

-- Tabla de usuarios con referencia a roles
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role_id INT NOT NULL REFERENCES roles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);

-- Almacena los créditos ("dinero" virtual) de cada usuario
CREATE TABLE IF NOT EXISTS wallets (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  balance NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- ESTRUCTURA DE PRODUCTOS Y MÉTRICAS ---

-- Categorías principales (ej: Ropa, Educación)
CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);

-- Subcategorías con unidad de medida para el impacto
CREATE TABLE IF NOT EXISTS subcategories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  -- Define la unidad en la que el vendedor debe medir el producto
  -- Ej: 'página', 'kg', 'unidad', 'litro'
  unit_of_measure VARCHAR(50) NOT NULL DEFAULT 'unidad',
  UNIQUE(name, category_id)
);
CREATE INDEX IF NOT EXISTS idx_subcategories_category_id ON subcategories(category_id);

-- Define las métricas ambientales que se medirán
CREATE TABLE IF NOT EXISTS metrics (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL, -- Ej: 'CO2', 'Agua', 'Energía', 'Pesticidas'
  unit VARCHAR(20) NOT NULL -- Ej: 'kg', 'litros', 'kWh', 'g'
);

-- Tabla de equivalencias: El corazón del sistema de impacto
-- Define cuánto impacto se ahorra por CADA unidad de una subcategoría
CREATE TABLE IF NOT EXISTS equivalences (
  id SERIAL PRIMARY KEY,
  subcategory_id INT NOT NULL REFERENCES subcategories(id) ON DELETE CASCADE,
  metric_id INT NOT NULL REFERENCES metrics(id) ON DELETE CASCADE,
  -- Valor del impacto por CADA unit_of_measure de la subcategoría
  -- Ej: 0.1 (kg de CO2) por 'página' de 'Libro de papel'
  value_per_unit NUMERIC(12, 6) NOT NULL DEFAULT 0.00,
  UNIQUE(subcategory_id, metric_id)
);
CREATE INDEX IF NOT EXISTS idx_equivalences_subcategory_id ON equivalences(subcategory_id);
CREATE INDEX IF NOT EXISTS idx_equivalences_metric_id ON equivalences(metric_id);

-- Publicaciones (listings) creadas por emprendedores/admin
CREATE TABLE IF NOT EXISTS listings (
  id BIGSERIAL PRIMARY KEY,
  author_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  subcategory_id INT NOT NULL REFERENCES subcategories(id) ON DELETE RESTRICT,
  -- Precio en créditos verdes por 1 unidad de stock
  unit_credits NUMERIC(10,2) NOT NULL CHECK (unit_credits >= 0),
  -- Stock disponible
  quantity INT NOT NULL CHECK (quantity >= 0),
  -- Cantidad base para el cálculo de métricas (ej: 300 páginas, 0.8 kg)
  metric_quantity NUMERIC(10,2) NOT NULL DEFAULT 1,
  image_url VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'disponible', -- ('disponible', 'agotado', 'archivado')
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_listings_author_id ON listings(author_id);
CREATE INDEX IF NOT EXISTS idx_listings_subcategory_id ON listings(subcategory_id);

-- --- ESTRUCTURA DE TRANSACCIONES Y LOGS ---

-- Registra cada intercambio exitoso
CREATE TABLE IF NOT EXISTS exchanges (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listings(id) ON DELETE RESTRICT,
  buyer_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  -- Vendedor (denormalizado para reportes)
  seller_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  -- Cantidad de stock comprado
  quantity_exchanged INT NOT NULL,
  -- Costo total (quantity_exchanged * unit_credits)
  credits_total NUMERIC(10,2) NOT NULL,
  exchange_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_exchanges_listing_id ON exchanges(listing_id);
CREATE INDEX IF NOT EXISTS idx_exchanges_buyer_id ON exchanges(buyer_id);
CREATE INDEX IF NOT EXISTS idx_exchanges_seller_id ON exchanges(seller_id);

-- Log de todos los movimientos de créditos (bonos, compras, ventas)
CREATE TABLE IF NOT EXISTS credits_log (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  operation_type VARCHAR(50) NOT NULL, -- ('bono_bienvenida', 'bono_publicacion', 'intercambio_debito', 'intercambio_credito', 'compra_creditos')
  -- Cambio en el balance (positivo o negativo)
  delta NUMERIC(10,2) NOT NULL,
  -- Saldo resultante tras la operación
  balance_after NUMERIC(10,2) NOT NULL,
  -- ID relacionado (user_id en bono, listing_id en publicacion, exchange_id en intercambio)
  related_id BIGINT,
  log_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_credits_log_user_id ON credits_log(user_id);
CREATE INDEX IF NOT EXISTS idx_credits_log_operation_type ON credits_log(operation_type);

-- Log de compras de créditos (si se implementa con dinero real)
CREATE TABLE IF NOT EXISTS credit_purchases (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  credits_bought INT NOT NULL,
  amount_bs NUMERIC(10,2) NOT NULL, -- Monto en Bolivianos
  payment_gateway_id VARCHAR(255),
  status VARCHAR(30) NOT NULL, -- ('pendiente', 'completado', 'fallido')
  purchase_date TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- ESTRUCTURA DE REPORTES Y SEGURIDAD ---

-- Acumula el impacto ambiental total por día para reportes
CREATE TABLE IF NOT EXISTS impact_daily (
  id BIGSERIAL PRIMARY KEY,
  impact_date DATE NOT NULL UNIQUE,
  reused_items INT NOT NULL DEFAULT 0,
  co2_saved_kg NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  water_saved_liters NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  energy_saved_kwh NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  plastic_saved_g NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  -- Nueva métrica añadida
  pesticides_saved_g NUMERIC(12,4) NOT NULL DEFAULT 0.00
);

-- Tabla para campañas de bonificación (ej: "Doble de créditos por publicar esta semana")
CREATE TABLE IF NOT EXISTS campaigns (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  -- Multiplicador para bonos (ej: 2.0 para doble)
  multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Registra intentos de inicio de sesión (para seguridad)
CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL, -- Puede ser NULL si el email no existe
    email_attempt VARCHAR(100) NOT NULL,
    successful BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    attempt_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- VISTAS (Requerimiento de Rúbrica) ---

-- VISTA 1: Detalles de Usuario
-- Útil para perfiles y reportes de admin.
CREATE OR REPLACE VIEW v_user_details AS
SELECT
    u.id AS user_id,
    u.name AS user_name,
    u.email,
    r.name AS role_name,
    COALESCE(w.balance, 0.00) AS current_balance,
    u.created_at
FROM
    users u
JOIN
    roles r ON u.role_id = r.id
LEFT JOIN
    wallets w ON u.id = w.user_id;

-- VISTA 2: Publicaciones con Impacto Calculado
-- Útil para mostrar en el frontend el impacto que genera CADA item.
-- (VISTA ACTUALIZADA CON PESTICIDAS)
CREATE OR REPLACE VIEW v_listings_with_impact AS
SELECT
    l.id AS listing_id,
    l.title,
    l.author_id,
    u.name AS author_name,
    l.subcategory_id,
    sc.name AS subcategory_name,
    l.unit_credits,
    l.quantity AS stock_quantity,
    l.metric_quantity,
    sc.unit_of_measure,
    l.status,
    l.image_url,
    -- Calcula el impacto total por CADA item (metric_quantity * equivalencia)
    (
        l.metric_quantity * COALESCE(eq_co2.value_per_unit, 0)
    ) AS co2_saved_per_item,
    (
        l.metric_quantity * COALESCE(eq_water.value_per_unit, 0)
    ) AS water_saved_per_item,
    (
        l.metric_quantity * COALESCE(eq_energy.value_per_unit, 0)
    ) AS energy_saved_per_item,
    (
        l.metric_quantity * COALESCE(eq_plastic.value_per_unit, 0)
    ) AS plastic_saved_per_item,
    -- Nueva métrica añadida
    (
        l.metric_quantity * COALESCE(eq_pesticide.value_per_unit, 0)
    ) AS pesticides_saved_per_item
FROM
    listings l
JOIN
    users u ON l.author_id = u.id
JOIN
    subcategories sc ON l.subcategory_id = sc.id
-- Joins para cada métrica principal
LEFT JOIN
    equivalences eq_co2 ON eq_co2.subcategory_id = l.subcategory_id
    AND eq_co2.metric_id = (SELECT id FROM metrics WHERE name = 'CO2')
LEFT JOIN
    equivalences eq_water ON eq_water.subcategory_id = l.subcategory_id
    AND eq_water.metric_id = (SELECT id FROM metrics WHERE name = 'Agua')
LEFT JOIN
    equivalences eq_energy ON eq_energy.subcategory_id = l.subcategory_id
    AND eq_energy.metric_id = (SELECT id FROM metrics WHERE name = 'Energía')
LEFT JOIN
    equivalences eq_plastic ON eq_plastic.subcategory_id = l.subcategory_id
    AND eq_plastic.metric_id = (SELECT id FROM metrics WHERE name = 'Residuos Plásticos')
-- Join para la nueva métrica
LEFT JOIN
    equivalences eq_pesticide ON eq_pesticide.subcategory_id = l.subcategory_id
    AND eq_pesticide.metric_id = (SELECT id FROM metrics WHERE name = 'Pesticidas');

