-- Bono de bienvenida al registrar usuario
CREATE OR REPLACE FUNCTION trg_bono_bienvenida()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wallets (user_id, balance) VALUES (NEW.id, 10);
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (NEW.id, 'bono_bienvenida', 10, 10, NULL);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_bono_bienvenida
AFTER INSERT ON users
FOR EACH ROW EXECUTE FUNCTION trg_bono_bienvenida();

-- Incentivo por publicación (+5 créditos)
CREATE OR REPLACE FUNCTION trg_incentivo_publicacion()
RETURNS TRIGGER AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT balance INTO v_balance FROM wallets WHERE user_id = NEW.author_id FOR UPDATE;
  UPDATE wallets SET balance = balance + 5 WHERE user_id = NEW.author_id RETURNING balance INTO v_balance;
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (NEW.author_id, 'incentivo_publicacion', 5, v_balance, NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_incentivo_publicacion
AFTER INSERT ON listings
FOR EACH ROW EXECUTE FUNCTION trg_incentivo_publicacion();

-- Impacto ambiental/día tras intercambio (bienes: sumamos unidades y CO2)
CREATE OR REPLACE FUNCTION trg_impacto_intercambio()
RETURNS TRIGGER AS $$
DECLARE
  v_cat_id INT;
  v_is_service BOOLEAN;
  v_factor NUMERIC;
  v_date DATE := (NEW.exchange_date AT TIME ZONE 'UTC')::date;
BEGIN
  -- Categoría y factor
  SELECT p.category_id, (LOWER(c.name) = 'servicios'), c.co2_factor
    INTO v_cat_id, v_is_service, v_factor
  FROM listings p
  JOIN categories c ON c.id = p.category_id
  WHERE p.id = NEW.listing_id;

  IF v_is_service THEN
    -- opcional: sumar horas de servicio
    INSERT INTO impact_daily (impact_date, service_hours)
    VALUES (v_date, NEW.quantity)
    ON CONFLICT (impact_date) DO UPDATE
      SET service_hours = impact_daily.service_hours + EXCLUDED.service_hours;
  ELSE
    INSERT INTO impact_daily (impact_date, reused_items, co2_saved_kg)
    VALUES (v_date, NEW.quantity, NEW.quantity * COALESCE(v_factor,0))
    ON CONFLICT (impact_date) DO UPDATE
      SET reused_items = impact_daily.reused_items + EXCLUDED.reused_items,
          co2_saved_kg = impact_daily.co2_saved_kg + EXCLUDED.co2_saved_kg;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_impacto_intercambio ON exchanges;
CREATE TRIGGER t_impacto_intercambio
AFTER INSERT ON exchanges
FOR EACH ROW EXECUTE FUNCTION trg_impacto_intercambio();
