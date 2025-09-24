-- db/init/02_functions_and_procedures.sql

-- Helper: asegurar billetera (si no existe, crearla en 0)
CREATE OR REPLACE FUNCTION ensure_wallet(p_user_id INT) RETURNS VOID AS $$
BEGIN
  INSERT INTO wallets (user_id, balance) VALUES (p_user_id, 0.00)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Helper: obtener saldo (FOR UPDATE opcional)
CREATE OR REPLACE FUNCTION get_balance_for_update(p_user_id INT) RETURNS NUMERIC AS $$
DECLARE v_balance NUMERIC;
BEGIN
  PERFORM ensure_wallet(p_user_id);
  SELECT balance INTO v_balance FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql;

-- Comprar créditos: registra compra, acredita billetera y log
-- Firma: CALL sp_comprar_creditos(user_id, credits, amount_bs, payment_ref)
CREATE OR REPLACE PROCEDURE sp_comprar_creditos(
  IN p_user_id INT,
  IN p_credits INT,
  IN p_amount_bs NUMERIC,
  IN p_payment_ref TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_purchase_id BIGINT;
BEGIN
  IF p_credits <= 0 OR p_amount_bs < 0 THEN
    RAISE EXCEPTION 'Parámetros inválidos en compra de créditos';
  END IF;

  -- Creamos billetera si no existe y bloqueamos fila
  v_balance := get_balance_for_update(p_user_id);

  INSERT INTO credit_purchases (user_id, credits, amount_bs, status, payment_ref)
  VALUES (p_user_id, p_credits, p_amount_bs, 'pagado', p_payment_ref)
  RETURNING id INTO v_purchase_id;

  -- Actualizar saldo
  UPDATE wallets
     SET balance = balance + p_credits,
         last_updated = now()
   WHERE user_id = p_user_id
   RETURNING balance INTO v_new_balance;

  -- Log
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (
    p_user_id,
    'compra_creditos',
    p_credits,
    v_new_balance,
    v_purchase_id
  );

END;
$$;

-- Registrar intercambio (3 parámetros): buyer, listing, quantity
-- Deriva seller desde listings.author_id. Valida estado y auto-compra.
CREATE OR REPLACE PROCEDURE sp_registrar_intercambio(
  IN p_buyer_id INT,
  IN p_listing_id INT,
  IN p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_unit NUMERIC;
  v_total NUMERIC;
  v_seller_id INT;
  v_status TEXT;
  v_balance NUMERIC;
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'Cantidad inválida';
  END IF;

  SELECT author_id, unit_credits, status
    INTO v_seller_id, v_unit, v_status
  FROM listings
  WHERE id = p_listing_id
  FOR UPDATE;

  IF v_seller_id IS NULL THEN
    RAISE EXCEPTION 'Publicación inexistente';
  END IF;

  IF v_status <> 'activa' THEN
    RAISE EXCEPTION 'La publicación no está activa';
  END IF;

  IF v_seller_id = p_buyer_id THEN
    RAISE EXCEPTION 'El comprador no puede comprar su propia publicación';
  END IF;

  v_total := v_unit * p_quantity;

  -- Debitar comprador
  SELECT balance INTO v_balance FROM wallets WHERE user_id = p_buyer_id FOR UPDATE;
  IF v_balance < v_total THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;
  UPDATE wallets SET balance = balance - v_total WHERE user_id = p_buyer_id RETURNING balance INTO v_balance;
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (p_buyer_id, 'intercambio_debito', -v_total, v_balance, p_listing_id);

  -- Acreditar vendedor
  SELECT balance INTO v_balance FROM wallets WHERE user_id = v_seller_id FOR UPDATE;
  UPDATE wallets SET balance = balance + v_total WHERE user_id = v_seller_id RETURNING balance INTO v_balance;
  INSERT INTO credits_log (user_id, operation_type, delta, balance_after, related_id)
  VALUES (v_seller_id, 'intercambio_credito', v_total, v_balance, p_listing_id);

  -- Registrar intercambio
  INSERT INTO exchanges (listing_id, buyer_id, seller_id, quantity, credits_per_unit, credits_total)
  VALUES (p_listing_id, p_buyer_id, v_seller_id, p_quantity, v_unit, v_total);

  -- Cerrar publicación
  UPDATE listings SET status = 'intercambiada' WHERE id = p_listing_id;
END;
$$;

