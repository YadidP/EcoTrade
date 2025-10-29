-- db/init/02_functions_and_procedures.sql

-- Función auxiliar: Asegura que un usuario tenga una billetera; la crea con saldo 0 si no existe.
CREATE OR REPLACE FUNCTION ensure_wallet(p_user_id INT) RETURNS VOID AS $$
BEGIN
  INSERT INTO wallets (user_id, balance) VALUES (p_user_id, 0.00)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: Obtiene el saldo de un usuario bloqueando la fila para una transacción segura.
CREATE OR REPLACE FUNCTION get_balance_for_update(p_user_id INT) RETURNS NUMERIC AS $$
DECLARE v_balance NUMERIC;
BEGIN
  -- Asegura que la billetera exista antes de bloquear
  PERFORM ensure_wallet(p_user_id);
  
  SELECT balance INTO v_balance 
  FROM wallets 
  WHERE user_id = p_user_id 
  FOR UPDATE; -- Bloquea la fila para evitar concurrencia
  
  RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar: Obtiene el multiplicador de la campaña activa (si existe)
CREATE OR REPLACE FUNCTION get_active_campaign_multiplier() RETURNS NUMERIC AS $$
DECLARE
  v_multiplier NUMERIC;
BEGIN
  SELECT multiplier INTO v_multiplier
  FROM campaigns
  WHERE is_active = TRUE AND now() BETWEEN start_date AND end_date
  ORDER BY multiplier DESC -- Obtiene la campaña más beneficiosa
  LIMIT 1;

  RETURN COALESCE(v_multiplier, 1.00); -- Retorna 1.00 si no hay campaña activa
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para registrar una "compra" de créditos (simulada o por pasarela)
CREATE OR REPLACE PROCEDURE sp_comprar_creditos(
  IN p_user_id INT,
  IN p_credits INT,
  IN p_amount_bs NUMERIC,
  IN p_payment_id VARCHAR
) AS $$
DECLARE
  v_new_balance NUMERIC;
BEGIN
  -- 1. Registrar el intento de compra
  INSERT INTO credit_purchases (user_id, credits_bought, amount_bs, payment_gateway_id, status)
  VALUES (p_user_id, p_credits, p_amount_bs, p_payment_id, 'completado');

  -- 2. Asegurar y actualizar la billetera (con bloqueo)
  PERFORM ensure_wallet(p_user_id);
  
  UPDATE wallets
  SET balance = balance + p_credits,
      last_updated = now()
  WHERE user_id = p_user_id
  RETURNING balance INTO v_new_balance;

  -- 3. Registrar en el log de créditos
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (p_user_id, 'compra_creditos', p_credits, v_new_balance, (SELECT id FROM credit_purchases WHERE payment_gateway_id = p_payment_id));
  
  -- COMMIT se maneja implícitamente si no se llama en una transacción
END;
$$ LANGUAGE plpgsql;


-- Procedimiento principal para registrar un intercambio (la "compra" de un producto)
-- (ACTUALIZADO CON PESTICIDAS)
CREATE OR REPLACE PROCEDURE sp_registrar_intercambio(
  IN p_buyer_id INT,
  IN p_listing_id BIGINT,
  IN p_quantity_requested INT
) AS $$
DECLARE
  v_listing RECORD;
  v_buyer_balance NUMERIC;
  v_seller_balance NUMERIC;
  v_total_credits NUMERIC;
  v_exchange_id BIGINT;
  v_metric_co2 NUMERIC;
  v_metric_water NUMERIC;
  v_metric_energy NUMERIC;
  v_metric_plastic NUMERIC;
  v_metric_pesticides NUMERIC; -- Nueva métrica
BEGIN
  -- 1. Obtener datos de la publicación y bloquearla
  SELECT * INTO v_listing
  FROM listings
  WHERE id = p_listing_id AND status = 'disponible'
  FOR UPDATE; -- Bloquea la publicación para evitar ventas concurrentes

  -- 2. Validar que la publicación exista y tenga stock
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Publicación no encontrada o no disponible (ID: %)', p_listing_id;
  END IF;

  IF v_listing.quantity < p_quantity_requested THEN
    RAISE EXCEPTION 'Stock insuficiente. Solicitado: %, Disponible: %', p_quantity_requested, v_listing.quantity;
  END IF;

  IF v_listing.author_id = p_buyer_id THEN
    RAISE EXCEPTION 'No puedes comprar tu propia publicación.';
  END IF;

  -- 3. Calcular costo y validar saldo del comprador (con bloqueo)
  v_total_credits := v_listing.unit_credits * p_quantity_requested;
  v_buyer_balance := get_balance_for_update(p_buyer_id);

  IF v_buyer_balance < v_total_credits THEN
    RAISE EXCEPTION 'Saldo insuficiente. Requerido: %, Disponible: %', v_total_credits, v_buyer_balance;
  END IF;
  
  -- 4. Obtener saldo del vendedor (con bloqueo)
  v_seller_balance := get_balance_for_update(v_listing.author_id);

  -- 5. Realizar las transferencias de créditos
  UPDATE wallets SET balance = balance - v_total_credits, last_updated = now() WHERE user_id = p_buyer_id;
  UPDATE wallets SET balance = balance + v_total_credits, last_updated = now() WHERE user_id = v_listing.author_id;

  -- 6. Actualizar el stock de la publicación
  UPDATE listings
  SET quantity = quantity - p_quantity_requested,
      status = CASE WHEN (quantity - p_quantity_requested) = 0 THEN 'agotado' ELSE 'disponible' END,
      updated_at = now()
  WHERE id = p_listing_id;

  -- 7. Registrar el intercambio
  INSERT INTO exchanges (listing_id, buyer_id, seller_id, quantity_exchanged, credits_total)
  VALUES (p_listing_id, p_buyer_id, v_listing.author_id, p_quantity_requested, v_total_credits)
  RETURNING id INTO v_exchange_id;

  -- 8. Registrar los movimientos en el log de créditos
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES
    (p_buyer_id, 'intercambio_debito', -v_total_credits, (v_buyer_balance - v_total_credits), v_exchange_id),
    (v_listing.author_id, 'intercambio_credito', v_total_credits, (v_seller_balance + v_total_credits), v_exchange_id);

  -- 9. Calcular y registrar el impacto ambiental (LÓGICA ACTUALIZADA)
  -- (items_comprados * metric_quantity_base * valor_de_equivalencia)
  
  -- Obtener valor de equivalencia de CO2
  SELECT COALESCE(e.value_per_unit, 0) * p_quantity_requested * v_listing.metric_quantity
  INTO v_metric_co2
  FROM metrics m
  LEFT JOIN equivalences e ON e.metric_id = m.id AND e.subcategory_id = v_listing.subcategory_id
  WHERE m.name = 'CO2';

  -- Obtener valor de equivalencia de Agua
  SELECT COALESCE(e.value_per_unit, 0) * p_quantity_requested * v_listing.metric_quantity
  INTO v_metric_water
  FROM metrics m
  LEFT JOIN equivalences e ON e.metric_id = m.id AND e.subcategory_id = v_listing.subcategory_id
  WHERE m.name = 'Agua';

  -- Obtener valor de equivalencia de Energía
  SELECT COALESCE(e.value_per_unit, 0) * p_quantity_requested * v_listing.metric_quantity
  INTO v_metric_energy
  FROM metrics m
  LEFT JOIN equivalences e ON e.metric_id = m.id AND e.subcategory_id = v_listing.subcategory_id
  WHERE m.name = 'Energía';

  -- Obtener valor de equivalencia de Plástico
  SELECT COALESCE(e.value_per_unit, 0) * p_quantity_requested * v_listing.metric_quantity
  INTO v_metric_plastic
  FROM metrics m
  LEFT JOIN equivalences e ON e.metric_id = m.id AND e.subcategory_id = v_listing.subcategory_id
  WHERE m.name = 'Residuos Plásticos';

  -- Obtener valor de equivalencia de Pesticidas (NUEVO)
  SELECT COALESCE(e.value_per_unit, 0) * p_quantity_requested * v_listing.metric_quantity
  INTO v_metric_pesticides
  FROM metrics m
  LEFT JOIN equivalences e ON e.metric_id = m.id AND e.subcategory_id = v_listing.subcategory_id
  WHERE m.name = 'Pesticidas';

  -- Insertar o actualizar el impacto diario
  INSERT INTO impact_daily (impact_date, reused_items, co2_saved_kg, water_saved_liters, energy_saved_kwh, plastic_saved_g, pesticides_saved_g)
  VALUES (
    CURRENT_DATE, 
    p_quantity_requested, 
    COALESCE(v_metric_co2, 0),
    COALESCE(v_metric_water, 0),
    COALESCE(v_metric_energy, 0),
    COALESCE(v_metric_plastic, 0),
    COALESCE(v_metric_pesticides, 0) -- Nueva métrica
  )
  ON CONFLICT (impact_date) DO UPDATE SET
    reused_items = impact_daily.reused_items + EXCLUDED.reused_items,
    co2_saved_kg = impact_daily.co2_saved_kg + EXCLUDED.co2_saved_kg,
    water_saved_liters = impact_daily.water_saved_liters + EXCLUDED.water_saved_liters,
    energy_saved_kwh = impact_daily.energy_saved_kwh + EXCLUDED.energy_saved_kwh,
    plastic_saved_g = impact_daily.plastic_saved_g + EXCLUDED.plastic_saved_g,
    pesticides_saved_g = impact_daily.pesticides_saved_g + EXCLUDED.pesticides_saved_g; -- Nueva métrica

  -- COMMIT es implícito al finalizar el SP
END;
$$ LANGUAGE plpgsql;

