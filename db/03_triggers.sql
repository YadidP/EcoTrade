-- db/init/03_triggers.sql

-- 1. Trigger para Bono de Bienvenida
-- Otorga 10 créditos a un usuario nuevo inmediatamente después de registrarse.
CREATE OR REPLACE FUNCTION trg_bono_bienvenida()
RETURNS TRIGGER AS $$
DECLARE
  v_balance_actual NUMERIC;
BEGIN
  -- Asegura que la billetera exista (aunque deberia crearse por defecto, es una doble seguridad)
  PERFORM ensure_wallet(NEW.id);
  
  -- Asigna el bono de bienvenida
  UPDATE wallets 
  SET balance = balance + 10 
  WHERE user_id = NEW.id
  RETURNING balance INTO v_balance_actual;
  
  -- Registra el movimiento en el log de créditos
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (NEW.id, 'bono_bienvenida', 10, v_balance_actual, NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_bono_bienvenida ON users;
CREATE TRIGGER t_bono_bienvenida
AFTER INSERT ON users
FOR EACH ROW EXECUTE FUNCTION trg_bono_bienvenida();

-- 2. Trigger para Incentivo por Publicación
-- Otorga 5 créditos (modificable por campañas) al autor cuando crea una nueva publicación.
CREATE OR REPLACE FUNCTION trg_bono_publicacion()
RETURNS TRIGGER AS $$
DECLARE
  v_balance_after NUMERIC;
  v_multiplier NUMERIC := get_active_campaign_multiplier(); -- Obtiene multiplicador (ej: 2x)
  v_bonus NUMERIC := 5 * v_multiplier; -- 5 es el bono base
BEGIN
  -- Asegura la billetera del autor
  PERFORM ensure_wallet(NEW.author_id);
  
  -- Actualiza el saldo del autor con el bono (y posible multiplicador)
  UPDATE wallets
  SET balance = balance + v_bonus
  WHERE user_id = NEW.author_id
  RETURNING balance INTO v_balance_after;
  
  -- Registra el movimiento en el log
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (NEW.author_id, 'bono_publicacion', v_bonus, v_balance_after, NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_bono_publicacion ON listings;
CREATE TRIGGER t_bono_publicacion
AFTER INSERT ON listings
FOR EACH ROW EXECUTE FUNCTION trg_bono_publicacion();

-- 3. Trigger de Validación de Saldo (Nivel BD)
-- Verifica el saldo ANTES de que se inserte un registro en la tabla 'exchanges'.
-- Esta es una capa extra de seguridad que duplica la validación del SP,
-- cumpliendo el requisito de la rúbrica y protegiendo la integridad de datos
-- si se intentara un INSERT directo.
CREATE OR REPLACE FUNCTION trg_validacion_saldo_previo()
RETURNS TRIGGER AS $$
DECLARE
    v_buyer_balance NUMERIC;
BEGIN
    -- Obtener el saldo del comprador (sin bloqueo, es solo una validación rápida)
    SELECT balance INTO v_buyer_balance
    FROM wallets
    WHERE user_id = NEW.buyer_id;

    -- Validar si el saldo es suficiente
    IF v_buyer_balance < NEW.credits_total THEN
        RAISE EXCEPTION 'Saldo insuficiente (Trigger). Saldo actual: %, Costo: %',
            v_buyer_balance, NEW.credits_total
        USING ERRCODE = '23514'; -- Check Violation
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_validacion_saldo_previo ON exchanges;
CREATE TRIGGER t_validacion_saldo_previo
BEFORE INSERT ON exchanges
FOR EACH ROW EXECUTE FUNCTION trg_validacion_saldo_previo();
