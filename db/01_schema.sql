-- db/init/01_schema.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --- ESTRUCTURA DE AUTENTICACIÓN Y USUARIOS ---

CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL -- ('comun', 'emprendedor', 'admin')
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role_id INT NOT NULL REFERENCES roles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);

CREATE TABLE IF NOT EXISTS wallets (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  balance NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- ESTRUCTURA DE PRODUCTOS Y MÉTRICAS ---

CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS subcategories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  -- Define la unidad en la que el vendedor debe medir el producto
  unit_of_measure VARCHAR(50) NOT NULL DEFAULT 'unidad',
  UNIQUE(name, category_id)
);
CREATE INDEX IF NOT EXISTS idx_subcategories_category_id ON subcategories(category_id);

CREATE TABLE IF NOT EXISTS metrics (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL, -- Ej: 'CO2', 'Agua', 'Pesticidas', 'Metales (Acero)'
  unit VARCHAR(20) NOT NULL -- Ej: 'kg', 'litros', 'g', 'kg'
);

CREATE TABLE IF NOT EXISTS equivalences (
  id SERIAL PRIMARY KEY,
  subcategory_id INT NOT NULL REFERENCES subcategories(id) ON DELETE CASCADE,
  metric_id INT NOT NULL REFERENCES metrics(id) ON DELETE CASCADE,
  value_per_unit NUMERIC(12, 6) NOT NULL DEFAULT 0.00,
  UNIQUE(subcategory_id, metric_id)
);
CREATE INDEX IF NOT EXISTS idx_equivalences_subcategory_id ON equivalences(subcategory_id);
CREATE INDEX IF NOT EXISTS idx_equivalences_metric_id ON equivalences(metric_id);

CREATE TABLE IF NOT EXISTS listings (
  id BIGSERIAL PRIMARY KEY,
  author_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(150) NOT NULL,
  description TEXT,
  subcategory_id INT NOT NULL REFERENCES subcategories(id) ON DELETE RESTRICT,
  unit_credits NUMERIC(10,2) NOT NULL CHECK (unit_credits >= 0),
  quantity INT NOT NULL CHECK (quantity >= 0),
  metric_quantity NUMERIC(10,2) NOT NULL DEFAULT 1,
  image_url VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'disponible',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_listings_author_id ON listings(author_id);
CREATE INDEX IF NOT EXISTS idx_listings_subcategory_id ON listings(subcategory_id);

-- --- ESTRUCTURA DE TRANSACCIONES Y LOGS ---

CREATE TABLE IF NOT EXISTS exchanges (
  id BIGSERIAL PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listings(id) ON DELETE RESTRICT,
  buyer_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  seller_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  quantity_exchanged INT NOT NULL,
  credits_total NUMERIC(10,2) NOT NULL,
  exchange_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_exchanges_listing_id ON exchanges(listing_id);
CREATE INDEX IF NOT EXISTS idx_exchanges_buyer_id ON exchanges(buyer_id);
CREATE INDEX IF NOT EXISTS idx_exchanges_seller_id ON exchanges(seller_id);

-- ¡NUEVA TABLA NORMALIZADA (3FN) PARA ERD!
-- Registra el impacto granular de CADA intercambio.
CREATE TABLE IF NOT EXISTS exchange_impact_log (
  id BIGSERIAL PRIMARY KEY,
  exchange_id BIGINT NOT NULL REFERENCES exchanges(id) ON DELETE CASCADE,
  metric_id INT NOT NULL REFERENCES metrics(id) ON DELETE RESTRICT,
  -- Valor total ahorrado para esta métrica en este intercambio
  saved_value NUMERIC(12, 6) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_exchange_impact_log_exchange_id ON exchange_impact_log(exchange_id);
CREATE INDEX IF NOT EXISTS idx_exchange_impact_log_metric_id ON exchange_impact_log(metric_id);


CREATE TABLE IF NOT EXISTS credits_log (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  operation_type VARCHAR(50) NOT NULL,
  delta NUMERIC(10,2) NOT NULL,
  balance_after NUMERIC(10,2) NOT NULL,
  related_id BIGINT,
  log_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_credits_log_user_id ON credits_log(user_id);
CREATE INDEX IF NOT EXISTS idx_credits_log_operation_type ON credits_log(operation_type);

CREATE TABLE IF NOT EXISTS credit_purchases (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  credits_bought INT NOT NULL,
  amount_bs NUMERIC(10,2) NOT NULL,
  payment_gateway_id VARCHAR(255),
  status VARCHAR(30) NOT NULL,
  purchase_date TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- ESTRUCTURA DE REPORTES Y SEGURIDAD ---

-- ¡TABLA RENOMBRADA! Tabla desnormalizada ("caché") solo para reportes rápidos.
CREATE TABLE IF NOT EXISTS reports_impact_daily (
  id BIGSERIAL PRIMARY KEY,
  impact_date DATE NOT NULL UNIQUE,
  reused_items INT NOT NULL DEFAULT 0,
  co2_saved_kg NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  water_saved_liters NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  energy_saved_kwh NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  plastic_saved_g NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  pesticides_saved_g NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  metal_steel_saved_kg NUMERIC(12,4) NOT NULL DEFAULT 0.00,
  metal_aluminum_saved_g NUMERIC(12,4) NOT NULL DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS campaigns (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  multiplier NUMERIC(5,2) NOT NULL DEFAULT 1.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    email_attempt VARCHAR(100) NOT NULL,
    successful BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    attempt_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --- VISTAS (Requerimiento de Rúbrica) ---

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

-- (VISTA ACTUALIZADA CON TODAS LAS MÉTRICAS NUEVAS)
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
    (l.metric_quantity * COALESCE(eq_co2.value_per_unit, 0)) AS co2_saved_per_item,
    (l.metric_quantity * COALESCE(eq_water.value_per_unit, 0)) AS water_saved_per_item,
    (l.metric_quantity * COALESCE(eq_energy.value_per_unit, 0)) AS energy_saved_per_item,
    (l.metric_quantity * COALESCE(eq_plastic.value_per_unit, 0)) AS plastic_saved_per_item,
    (l.metric_quantity * COALESCE(eq_pesticide.value_per_unit, 0)) AS pesticides_saved_per_item,
    (l.metric_quantity * COALESCE(eq_steel.value_per_unit, 0)) AS steel_saved_per_item,
    (l.metric_quantity * COALESCE(eq_aluminum.value_per_unit, 0)) AS aluminum_saved_per_item
FROM
    listings l
JOIN
    users u ON l.author_id = u.id
JOIN
    subcategories sc ON l.subcategory_id = sc.id
-- Joins para cada métrica principal
LEFT JOIN equivalences eq_co2 ON eq_co2.subcategory_id = l.subcategory_id AND eq_co2.metric_id = (SELECT id FROM metrics WHERE name = 'CO2')
LEFT JOIN equivalences eq_water ON eq_water.subcategory_id = l.subcategory_id AND eq_water.metric_id = (SELECT id FROM metrics WHERE name = 'Agua')
LEFT JOIN equivalences eq_energy ON eq_energy.subcategory_id = l.subcategory_id AND eq_energy.metric_id = (SELECT id FROM metrics WHERE name = 'Energía')
LEFT JOIN equivalences eq_plastic ON eq_plastic.subcategory_id = l.subcategory_id AND eq_plastic.metric_id = (SELECT id FROM metrics WHERE name = 'Residuos Plásticos')
LEFT JOIN equivalences eq_pesticide ON eq_pesticide.subcategory_id = l.subcategory_id AND eq_pesticide.metric_id = (SELECT id FROM metrics WHERE name = 'Pesticidas')
LEFT JOIN equivalences eq_steel ON eq_steel.subcategory_id = l.subcategory_id AND eq_steel.metric_id = (SELECT id FROM metrics WHERE name = 'Metales (Acero)')
LEFT JOIN equivalences eq_aluminum ON eq_aluminum.subcategory_id = l.subcategory_id AND eq_aluminum.metric_id = (SELECT id FROM metrics WHERE name = 'Metales (Aluminio)');
