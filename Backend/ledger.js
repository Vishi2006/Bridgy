/// Wallet ledger backed by Supabase.
///
/// This is the only source of truth for the balance. There is no in-memory or
/// local fallback: if Supabase rejects the read or the credit, the error is
/// raised to the caller with its original message.

export class LedgerError extends Error {
  constructor(message, { status = 500, code = 'LEDGER_ERROR' } = {}) {
    super(message);
    this.name = 'LedgerError';
    this.status = status;
    this.code = code;
  }
}

export function createLedger(supabase) {
  async function getBalance() {
    const { data, error } = await supabase
      .from('wallets')
      .select('id, balance_inr')
      .order('created_at', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'WALLET_READ_FAILED',
      });
    }
    if (!data) {
      throw new LedgerError('No wallet row exists. Run server/schema.sql.', {
        status: 503,
        code: 'WALLET_MISSING',
      });
    }

    return { walletId: data.id, balanceInr: Number(data.balance_inr) };
  }

  async function topUp(amountInr) {
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

    const { data, error } = await supabase.rpc('wallet_topup', {
      p_amount: amount,
    });

    if (error) {
      throw new LedgerError(error.message, {
        status: 502,
        code: error.code || 'TOPUP_FAILED',
      });
    }

    const row = Array.isArray(data) ? data[0] : data;
    if (!row) {
      throw new LedgerError('wallet_topup returned no row', {
        status: 502,
        code: 'TOPUP_EMPTY',
      });
    }

    return {
      balanceInr: Number(row.new_balance),
      transactionId: row.transaction_id,
      topupId: row.topup_id,
      amountInr: amount,
    };
  }

  return { getBalance, topUp };
}

export function sendLedgerError(res, error) {
  const status = error instanceof LedgerError ? error.status : 500;
  return res.status(status).json({
    error: error.message,
    code: error instanceof LedgerError ? error.code : 'LEDGER_ERROR',
  });
}
