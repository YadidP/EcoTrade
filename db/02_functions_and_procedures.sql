-- db/init/02_functions_and_procedures.sql

CREATE OR REPLACE FUNCTION ensure_wallet(p_user_id INT) RETURNS VOID AS $$
BEGIN
  INSERT INTO wallets (user_id, balance) VALUES (p_user_id, 0.00)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_balance_for_update(p_user_id INT) RETURNS NUMERIC AS $$
DECLARE v_balance NUMERIC;
BEGIN
  PERFORM ensure_wallet(p_user_id);
  SELECT balance INTO v_balance 
  FROM wallets 
  WHERE user_id = p_user_id 
  FOR UPDATE;
  RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_active_campaign_multiplier() RETURNS NUMERIC AS $$
DECLARE
  v_multiplier NUMERIC;
BEGIN
  SELECT multiplier INTO v_multiplier
  FROM campaigns
  WHERE is_active = TRUE AND now() BETWEEN start_date AND end_date
  ORDER BY multiplier DESC
  LIMIT 1;
  RETURN COALESCE(v_multiplier, 1.00);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE sp_comprar_creditos(
  IN p_user_id INT,
  IN p_credits INT,
  IN p_amount_bs NUMERIC,
  IN p_payment_id VARCHAR
) AS $$
DECLARE
  v_new_balance NUMERIC;
BEGIN
  INSERT INTO credit_purchases (user_id, credits_bought, amount_bs, payment_gateway_id, status)
  VALUES (p_user_id, p_credits, p_amount_bs, p_payment_id, 'completado');

  PERFORM ensure_wallet(p_user_id);
  
  UPDATE wallets
  SET balance = balance + p_credits,
      last_updated = now()
  WHERE user_id = p_user_id
  RETURNING balance INTO v_new_balance;

  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (p_user_id, 'compra_creditos', p_credits, v_new_balance, (SELECT id FROM credit_purchases WHERE payment_gateway_id = p_payment_id));
END;
$$ LANGUAGE plpgsql;


-- ¡PROCEDIMIENTO PRINCIPAL ACTUALIZADO!
-- Ahora registra el impacto en la tabla normalizada (exchange_impact_log)
-- Y también actualiza la tabla de resumen (reports_impact_daily)
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
  
  -- Variables para almacenar el impacto calculado
  v_metric_co2 NUMERIC DEFAULT 0;
  v_metric_water NUMERIC DEFAULT 0;
  v_metric_energy NUMERIC DEFAULT 0;
  v_metric_plastic NUMERIC DEFAULT 0;
  v_metric_pesticides NUMERIC DEFAULT 0;
  v_metric_steel NUMERIC DEFAULT 0;
  v_metric_aluminum NUMERIC DEFAULT 0;

  -- Variables de métricas (IDs)
  v_metric_id_co2 INT := (SELECT id FROM metrics WHERE name = 'CO2');
  v_metric_id_water INT := (SELECT id FROM metrics WHERE name = 'Agua');
  v_metric_id_energy INT := (SELECT id FROM metrics WHERE name = 'Energía');
  v_metric_id_plastic INT := (SELECT id FROM metrics WHERE name = 'Residuos Plásticos');
  v_metric_id_pesticides INT := (SELECT id FROM metrics WHERE name = 'Pesticidas');
  v_metric_id_steel INT := (SELECT id FROM metrics WHERE name = 'Metales (Acero)');
  v_metric_id_aluminum INT := (SELECT id FROM metrics WHERE name = 'Metales (Aluminio)');
  
BEGIN
  -- 1-4. Validaciones (Stock, Saldo, etc.)
  SELECT * INTO v_listing
  FROM listings
  WHERE id = p_listing_id AND status = 'disponible'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Publicación no encontrada o no disponible (ID: %)', p_listing_id;
  END IF;
  IF v_listing.quantity < p_quantity_requested THEN
    RAISE EXCEPTION 'Stock insuficiente. Solicitado: %, Disponible: %', p_quantity_requested, v_listing.quantity;
  END IF;
  IF v_listing.author_id = p_buyer_id THEN
    RAISE EXCEPTION 'No puedes comprar tu propia publicación.';
  END IF;

  v_total_credits := v_listing.unit_credits * p_quantity_requested;
  v_buyer_balance := get_balance_for_update(p_buyer_id);

  IF v_buyer_balance < v_total_credits THEN
    RAISE EXCEPTION 'Saldo insuficiente. Requerido: %, Disponible: %', v_total_credits, v_buyer_balance;
  END IF;
  
  v_seller_balance := get_balance_for_update(v_listing.author_id);

  -- 5-7. Transacciones y Logs
  UPDATE wallets SET balance = balance - v_total_credits, last_updated = now() WHERE user_id = p_buyer_id;
  UPDATE wallets SET balance = balance + v_total_credits, last_updated = now() WHERE user_id = v_listing.author_id;

  UPDATE listings
  SET quantity = quantity - p_quantity_requested,
      status = CASE WHEN (quantity - p_quantity_requested) = 0 THEN 'agotado' ELSE 'disponible' END,
      updated_at = now()
  WHERE id = p_listing_id;

  INSERT INTO exchanges (listing_id, buyer_id, seller_id, quantity_exchanged, credits_total)
  VALUES (p_listing_id, p_buyer_id, v_listing.author_id, p_quantity_requested, v_total_credits)
  RETURNING id INTO v_exchange_id;

  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES
    (p_buyer_id, 'intercambio_debito', -v_total_credits, (v_buyer_balance - v_total_credits), v_exchange_id),
    (v_listing.author_id, 'intercambio_credito', v_total_credits, (v_seller_balance + v_total_credits), v_exchange_id);

  -- 8. Cálculo de Impacto (Total)
  -- Fórmula: (items_comprados * metric_quantity_base * valor_de_equivalencia)
  SELECT 
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_co2 THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_water THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_energy THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_plastic THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_pesticides THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_steel THEN e.value_per_unit ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN e.metric_id = v_metric_id_aluminum THEN e.value_per_unit ELSE 0 END), 0)
  INTO
    v_metric_co2, v_metric_water, v_metric_energy, v_metric_plastic, v_metric_pesticides, v_metric_steel, v_metric_aluminum
  FROM equivalences e
  WHERE e.subcategory_id = v_listing.subcategory_id;

  -- Aplicar la fórmula (multiplicar por cantidad y métrica base)
  v_metric_co2 := v_metric_co2 * p_quantity_requested * v_listing.metric_quantity;
  v_metric_water := v_metric_water * p_quantity_requested * v_listing.metric_quantity;
  v_metric_energy := v_metric_energy * p_quantity_requested * v_listing.metric_quantity;
  v_metric_plastic := v_metric_plastic * p_quantity_requested * v_listing.metric_quantity;
  v_metric_pesticides := v_metric_pesticides * p_quantity_requested * v_listing.metric_quantity;
  v_metric_steel := v_metric_steel * p_quantity_requested * v_listing.metric_quantity;
  v_metric_aluminum := v_metric_aluminum * p_quantity_requested * v_listing.metric_quantity;

  -- 9. REGISTRAR EN TABLA NORMALIZADA (para el ERD)
  INSERT INTO exchange_impact_log (exchange_id, metric_id, saved_value)
  VALUES
    (v_exchange_id, v_metric_id_co2, v_metric_co2),
    (v_exchange_id, v_metric_id_water, v_metric_water),
    (v_exchange_id, v_metric_id_energy, v_metric_energy),
    (v_exchange_id, v_metric_id_plastic, v_metric_plastic),
    (v_exchange_id, v_metric_id_pesticides, v_metric_pesticides),
    (v_exchange_id, v_metric_id_steel, v_metric_steel),
    (v_exchange_id, v_metric_id_aluminum, v_metric_aluminum);

  -- 10. ACTUALIZAR TABLA DE REPORTE (para rendimiento)
  INSERT INTO reports_impact_daily (
    impact_date, reused_items, 
    co2_saved_kg, water_saved_liters, energy_saved_kwh, 
    plastic_saved_g, pesticides_saved_g, 
    metal_steel_saved_kg, metal_aluminum_saved_g
  )
  VALUES (
    CURRENT_DATE, p_quantity_requested,
    v_metric_co2, v_metric_water, v_metric_energy,
    v_metric_plastic, v_metric_pesticides,
    v_metric_steel, v_metric_aluminum
  )
  ON CONFLICT (impact_date) DO UPDATE SET
    reused_items = reports_impact_daily.reused_items + EXCLUDED.reused_items,
    co2_saved_kg = reports_impact_daily.co2_saved_kg + EXCLUDED.co2_saved_kg,
    water_saved_liters = reports_impact_daily.water_saved_liters + EXCLUDED.water_saved_liters,
    energy_saved_kwh = reports_impact_daily.energy_saved_kwh + EXCLUDED.energy_saved_kwh,
    plastic_saved_g = reports_impact_daily.plastic_saved_g + EXCLUDED.plastic_saved_g,
    pesticides_saved_g = reports_impact_daily.pesticides_saved_g + EXCLUDED.pesticides_saved_g,
    metal_steel_saved_kg = reports_impact_daily.metal_steel_saved_kg + EXCLUDED.metal_steel_saved_kg,
    metal_aluminum_saved_g = reports_impact_daily.metal_aluminum_saved_g + EXCLUDED.metal_aluminum_saved_g;

END;
$$ LANGUAGE plpgsql;
