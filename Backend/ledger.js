// Wallet ledger backed by Supabase.
//
// Supabase is the only source of truth. There is no in-memory or local
// fallback: every failure is raised with the original database message.

export class LedgerError extends Error {
  constructor(message, { status = 500, code = 'LEDGER_ERROR' } = {}) {
    super(message);
    this.name = 'LedgerError';
    this.status = status;
    this.code = code;
  }
}

function effectiveSpentToday(row) {
  const today = new Date().toISOString().slice(0, 10);
  const spentOn = row.spent_on ? String(row.spent_on).slice(0, 10) : today;
  return spentOn === today ? Number(row.spent_today_inr) : 0;
}

function mapWallet(row) {
  return {
    id: row.id,
    ownerId: row.owner_id,
    smartAccountAddress: row.smart_wallet_address,
    balanceInr: Number(row.balance_inr),
    perTxLimitInr: Number(row.per_tx_limit_inr),
    dailyLimitInr: Number(row.daily_limit_inr),
    spentTodayInr: effectiveSpentToday(row),
    policyExpiry: row.policy_expiry,
  };
}

function mapTopUp(row) {
  return {
    id: row.id,
    amountInr: Number(row.amount_inr),
    status: row.status,
    checkoutUrl: row.checkout_url,
    providerOrderId: row.provider_order_id,
    transactionId: row.transaction_id,
    createdAt: row.created_at,
  };
}

function positiveAmount(amountInr) {
  const amount = Number(amountInr);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new LedgerError('amountInr must be greater than 0', {
      status: 400,
      code: 'INVALID_AMOUNT',
    });
  }
  if (amount > 1000000) {
    throw new LedgerError('amountInr must be at most 1000000', {
      status: 400,
      code: 'INVALID_AMOUNT',
    });
  }
  return Math.round(amount * 100) / 100;
}

export function createLedger(supabase) {
  async function getWallet(ownerId) {
    const { data, error } = await supabase
      .from('wallets')
      .select('*')
      .eq('owner_id', ownerId)
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'WALLET_READ_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('No wallet exists for this account', {
        status: 404,
        code: 'WALLET_MISSING',
      });
    }
    return data;
  }

  async function getBalance(ownerId) {
    const wallet = await getWallet(ownerId);
    return {
      balanceInr: Number(wallet.balance_inr),
      perTxLimitInr: Number(wallet.per_tx_limit_inr),
      dailyLimitInr: Number(wallet.daily_limit_inr),
      spentTodayInr: effectiveSpentToday(wallet),
      policyExpiry: wallet.policy_expiry,
    };
  }

  async function getStatus(ownerId) {
    const wallet = await getWallet(ownerId);
    return mapWallet(wallet);
  }

  async function updatePolicy(ownerId, { perTxLimitInr, dailyLimitInr }) {
    const patch = {};
    if (perTxLimitInr != null) {
      patch.per_tx_limit_inr = positiveAmount(perTxLimitInr);
    }
    if (dailyLimitInr != null) {
      patch.daily_limit_inr = positiveAmount(dailyLimitInr);
    }
    if (Object.keys(patch).length === 0) {
      throw new LedgerError('No policy limits supplied', {
        status: 400,
        code: 'INVALID_POLICY',
      });
    }

    const perTx = patch.per_tx_limit_inr;
    const daily = patch.daily_limit_inr;
    if (perTx != null && daily != null && perTx > daily) {
      throw new LedgerError(
        'perTxLimitInr cannot be greater than dailyLimitInr',
        { status: 400, code: 'INVALID_POLICY' },
      );
    }

    const { data, error } = await supabase
      .from('wallets')
      .update(patch)
      .eq('owner_id', ownerId)
      .select('*')
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'POLICY_WRITE_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('No wallet exists for this account', {
        status: 404,
        code: 'WALLET_MISSING',
      });
    }
    return mapWallet(data);
  }

  async function renewPolicy(ownerId, hours = 24) {
    const expiresAt = new Date(Date.now() + hours * 3600 * 1000).toISOString();
    const { data, error } = await supabase
      .from('wallets')
      .update({ policy_expiry: expiresAt })
      .eq('owner_id', ownerId)
      .select('*')
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'POLICY_WRITE_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('No wallet exists for this account', {
        status: 404,
        code: 'WALLET_MISSING',
      });
    }
    return mapWallet(data);
  }

  async function listTransactions(ownerId, limit = 20) {
    const { data, error } = await supabase
      .from('transactions')
      .select('id, merchant_name, merchant_vpa, amount_inr, status, tx_hash, created_at')
      .eq('owner_id', ownerId)
      .order('created_at', { ascending: false })
      .limit(Math.min(Number(limit) || 20, 100));

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TRANSACTIONS_READ_FAILED',
      });
    }
    return (data ?? []).map((row) => ({
      id: row.id,
      merchantName: row.merchant_name,
      merchantVpa: row.merchant_vpa,
      amountInr: Number(row.amount_inr),
      status: row.status,
      txHash: row.tx_hash,
      createdAt: row.created_at,
    }));
  }

  async function createTopUp(ownerId, amountInr) {
    const amount = positiveAmount(amountInr);
    const wallet = await getWallet(ownerId);

    const { data, error } = await supabase
      .from('topups')
      .insert({
        owner_id: ownerId,
        wallet_id: wallet.id,
        amount_inr: amount,
        status: 'PENDING',
        provider: 'razorpay',
      })
      .select('*')
      .single();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_CREATE_FAILED',
      });
    }
    return mapTopUp(data);
  }

  async function attachCheckout(topUpId, { providerOrderId, checkoutUrl }) {
    const { data, error } = await supabase
      .from('topups')
      .update({
        provider_order_id: providerOrderId,
        checkout_url: checkoutUrl,
      })
      .eq('id', topUpId)
      .eq('status', 'PENDING')
      .select('*')
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_UPDATE_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('Top-up is no longer pending', {
        status: 409,
        code: 'TOPUP_NOT_PENDING',
      });
    }
    return mapTopUp(data);
  }

  async function getTopUp(ownerId, topUpId) {
    const { data, error } = await supabase
      .from('topups')
      .select('*')
      .eq('id', topUpId)
      .eq('owner_id', ownerId)
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_READ_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('Top-up not found', {
        status: 404,
        code: 'TOPUP_NOT_FOUND',
      });
    }
    return mapTopUp(data);
  }

  async function findTopUpByOrderId(providerOrderId) {
    const { data, error } = await supabase
      .from('topups')
      .select('*')
      .eq('provider_order_id', providerOrderId)
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_READ_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('No top-up matches this provider order', {
        status: 404,
        code: 'TOPUP_NOT_FOUND',
      });
    }
    return mapTopUp(data);
  }

  async function creditTopUp(topUpId, paymentId) {
    const { data, error } = await supabase.rpc('credit_topup', {
      p_topup_id: topUpId,
      p_payment_id: paymentId,
    });

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_CREDIT_FAILED',
      });
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      throw new LedgerError('credit_topup returned no row', {
        status: 502,
        code: 'TOPUP_CREDIT_EMPTY',
      });
    }
    return {
      balanceInr: Number(row.new_balance),
      transactionId: row.transaction_id,
      status: row.topup_status,
    };
  }

  async function markTopUp(topUpId, status) {
    const { data, error } = await supabase
      .from('topups')
      .update({ status })
      .eq('id', topUpId)
      .eq('status', 'PENDING')
      .select('*')
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_UPDATE_FAILED',
      });
    }
    return data ? mapTopUp(data) : null;
  }

  async function setSmartWalletAddress(ownerId, address) {
    const { error } = await supabase
      .from('wallets')
      .update({ smart_wallet_address: address })
      .eq('owner_id', ownerId);

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'WALLET_WRITE_FAILED',
      });
    }
  }

  async function creditOnChainDeposit(ownerId, observedWei, rate) {
    const { data, error } = await supabase.rpc('credit_onchain_deposit', {
      p_owner_id: ownerId,
      p_observed_wei: observedWei,
      p_eth_inr_rate: rate,
    });

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'ONCHAIN_CREDIT_FAILED',
      });
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      throw new LedgerError('credit_onchain_deposit returned no row', {
        status: 502,
        code: 'ONCHAIN_CREDIT_EMPTY',
      });
    }
    return {
      creditedInr: Number(row.credited_inr),
      newBalance: Number(row.new_balance),
      deltaWei: Number(row.delta_wei),
    };
  }

  async function debit(
    ownerId,
    {
      amountInr,
      merchantName,
      merchantVpa,
      status,
      perTxLimitInr = null,
      dailyLimitInr = null,
    },
  ) {
    const amount = positiveAmount(amountInr);
    const { data, error } = await supabase.rpc('debit_wallet', {
      p_owner_id: ownerId,
      p_amount: amount,
      p_merchant: merchantName,
      p_vpa: merchantVpa,
      p_status: status,
      p_per_tx_limit: perTxLimitInr,
      p_daily_limit: dailyLimitInr,
    });

    if (error) {
      if (error.code === 'P0001') {
        const daily = /daily/i.test(error.message);
        throw new LedgerError(error.message, {
          status: 402,
          code: daily ? 'DAILY_LIMIT_EXCEEDED' : 'OWNER_APPROVAL_REQUIRED',
        });
      }
      throw new LedgerError(error.message, {
        status: error.code === '22003' ? 409 : 502,
        code: error.code || 'PAYMENT_FAILED',
      });
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      throw new LedgerError('debit_wallet returned no row', {
        status: 502,
        code: 'PAYMENT_EMPTY',
      });
    }
    return {
      balanceInr: Number(row.new_balance),
      transactionId: row.transaction_id,
      spentTodayInr: Number(row.spent_today),
    };
  }

  return {
    getWallet,
    getBalance,
    getStatus,
    updatePolicy,
    renewPolicy,
    listTransactions,
    createTopUp,
    attachCheckout,
    getTopUp,
    findTopUpByOrderId,
    creditTopUp,
    markTopUp,
    debit,
    setSmartWalletAddress,
    creditOnChainDeposit,
  };
}

export function sendLedgerError(res, error) {
  const status = error instanceof LedgerError ? error.status : 500;
  return res.status(status).json({
    error: error.message,
    code: error instanceof LedgerError ? error.code : 'LEDGER_ERROR',
  });
}
