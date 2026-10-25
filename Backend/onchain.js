// Direct Base Sepolia deposit sync.
//
// The per-user smart account balance is read from the chain. Any increase is
// credited to the INR ledger at DEMO_ETH_INR_RATE. This is testnet ETH valued
// at a demo rate; it is not a real exchange rate and has no cash value.

import { formatEther } from 'viem';

export class OnChainError extends Error {
  constructor(message, { status = 502, code = 'ONCHAIN_ERROR' } = {}) {
    super(message);
    this.name = 'OnChainError';
    this.status = status;
    this.code = code;
  }
}

export function createOnChainSync({ publicClient, getAccount, ledger, rate }) {
  async function sync(ownerId) {
    if (!Number.isFinite(rate) || rate <= 0) {
      throw new OnChainError(
        'DEMO_ETH_INR_RATE is not configured on the backend. Set the testnet ETH to INR demo rate.',
        { status: 503, code: 'ONCHAIN_RATE_NOT_CONFIGURED' },
      );
    }

    const account = await getAccount(ownerId);
    if (!account) {
      throw new OnChainError(
        'ZeroDev or OWNER_PRIVATE_KEY is not configured, so no Base Sepolia address exists.',
        { status: 503, code: 'ONCHAIN_NOT_CONFIGURED' },
      );
    }

    let wei;
    try {
      wei = await publicClient.getBalance({ address: account.address });
    } catch (error) {
      throw new OnChainError(`Base Sepolia RPC failed: ${error.message}`, {
        status: 502,
        code: 'RPC_UNAVAILABLE',
      });
    }

    const credit = await ledger.creditOnChainDeposit(
      ownerId,
      wei.toString(),
      rate,
    );
    await ledger.setSmartWalletAddress(ownerId, account.address);

    return {
      address: account.address,
      balanceWei: wei.toString(),
      balanceEth: Number(formatEther(wei)),
      creditedInr: credit.creditedInr,
      balanceInr: credit.newBalance,
      deltaWei: credit.deltaWei,
    };
  }

  return { sync };
}

export function sendOnChainError(res, error) {
  const status = error instanceof OnChainError ? error.status : 500;
  return res.status(status).json({
    error: error.message,
    code: error instanceof OnChainError ? error.code : 'ONCHAIN_ERROR',
  });
}
