# Lumina Protocol - Deployment Guide

## Prerequisites

- Foundry installed
- BNB for gas fees
- Private key with funds
- RPC URL for BNB Chain

## Environment Setup

Create `.env` file in `contracts/` directory:

```bash
# Network
BNB_RPC_URL=https://bsc-dataseed.binance.org
BNB_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545

# Deployer
PRIVATE_KEY=your_private_key_here

# Verification (optional)
BSCSCAN_API_KEY=your_bscscan_api_key

# Initial Parameters
INITIAL_LIQUIDITY=1000000000000000000000000  # 1M USDT (18 decimals)
```

## Deployment Steps

### 1. Compile Contracts

```bash
cd contracts
forge build
```

### 2. Run Tests

```bash
forge test -vvv
```

### 3. Deploy to Testnet

```bash
forge script script/DeployWithBNB.s.sol \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### 4. Deploy to Mainnet

```bash
forge script script/DeployWithBNB.s.sol \
  --rpc-url $BNB_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## Deployment Script

The deployment script (`script/DeployWithBNB.s.sol`) deploys in this order:

1. **MockUSDT** (testnet only) or use real USDT (mainnet)
2. **LuminaOracle** - AI-powered risk oracle
3. **InsurancePool** - Liquidity pool for payouts
4. **PolicyManager** - Policy NFTs and claims
5. **PredictionMarket** - Native prediction markets

## Post-Deployment Configuration

### 1. Set Oracle Permissions

```bash
cast send $INSURANCE_POOL_ADDRESS \
  "setOracle(address)" $ORACLE_ADDRESS \
  --rpc-url $BNB_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Add Initial Liquidity

```bash
# Approve USDT
cast send $USDT_ADDRESS \
  "approve(address,uint256)" $INSURANCE_POOL_ADDRESS 1000000000000000000000000 \
  --rpc-url $BNB_RPC_URL \
  --private-key $PRIVATE_KEY

# Deposit to pool
cast send $INSURANCE_POOL_ADDRESS \
  "deposit(uint256)" 1000000000000000000000000 \
  --rpc-url $BNB_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Create Initial Markets

```bash
cast send $PREDICTION_MARKET_ADDRESS \
  "createMarket(string,string,string,uint256,uint256,bool)" \
  "BTC hits $120K by Q2 2025?" \
  "Bitcoin" \
  "Price" \
  7776000 \
  1000000000000000000000 \
  true \
  --rpc-url $BNB_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Frontend Configuration

Update `lumina/lib/contracts.ts` with deployed addresses:

```typescript
export const CONTRACTS = {
  PolicyManager: {
    address: '0x...', // From deployment
    abi: PolicyManagerABI,
  },
  InsurancePool: {
    address: '0x...',
    abi: InsurancePoolABI,
  },
  LuminaOracle: {
    address: '0x...',
    abi: LuminaOracleABI,
  },
  PredictionMarket: {
    address: '0x...',
    abi: PredictionMarketABI,
  },
};

export const ASSET_TOKEN = {
  address: '0x55d398326f99059fF775485246999027B3197955', // USDT on BNB mainnet
  abi: ERC20ABI,
};
```

## Verification

### Verify on BscScan

```bash
forge verify-contract \
  --chain-id 56 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $USDT $POOL $ORACLE) \
  --etherscan-api-key $BSCSCAN_API_KEY \
  --compiler-version v0.8.24 \
  $POLICY_MANAGER_ADDRESS \
  src/PolicyManager.sol:PolicyManager
```

## Gas Estimates

| Contract | Deployment Gas | Typical Operation |
|----------|----------------|-------------------|
| MockUSDT | ~1.2M | - |
| LuminaOracle | ~2.5M | 50k (update) |
| InsurancePool | ~3.8M | 150k (deposit/withdraw) |
| PolicyManager | ~4.2M | 250k (create policy) |
| PredictionMarket | ~3.5M | 180k (place bet) |

**Total Deployment:** ~15M gas (~$15-30 on BNB Chain)

## Security Checklist

- [ ] All contracts compiled without warnings
- [ ] All tests passing
- [ ] Deployer has sufficient BNB for gas
- [ ] Private key is secure (use hardware wallet for mainnet)
- [ ] Contract addresses verified on BscScan
- [ ] Initial liquidity deposited
- [ ] Oracle permissions set correctly
- [ ] Emergency pause tested
- [ ] Concentration limits verified
- [ ] Gas limits tested

## Monitoring

### Check Pool Health

```bash
cast call $INSURANCE_POOL_ADDRESS "getPoolInfo()" --rpc-url $BNB_RPC_URL
```

### Check Active Policies

```bash
cast call $POLICY_MANAGER_ADDRESS "policyCounter()" --rpc-url $BNB_RPC_URL
```

### Check Market Stats

```bash
cast call $PREDICTION_MARKET_ADDRESS "marketCounter()" --rpc-url $BNB_RPC_URL
```

## Troubleshooting

### Deployment Fails

1. Check gas price: `cast gas-price --rpc-url $BNB_RPC_URL`
2. Check balance: `cast balance $DEPLOYER_ADDRESS --rpc-url $BNB_RPC_URL`
3. Increase gas limit in script

### Verification Fails

1. Wait 1-2 minutes after deployment
2. Check compiler version matches
3. Verify constructor args are correct
4. Try manual verification on BscScan

### Transaction Reverts

1. Check error message: `cast call ... --trace`
2. Verify contract state
3. Check gas limits
4. Ensure approvals are set

## Mainnet Addresses (BNB Chain)

```
USDT: 0x55d398326f99059fF775485246999027B3197955
WBNB: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
```

## Testnet Addresses (BNB Testnet)

```
Faucet: https://testnet.bnbchain.org/faucet-smart
Explorer: https://testnet.bscscan.com
```

## Support

- Documentation: https://docs.lumina-protocol.com
- Discord: https://discord.gg/lumina
- GitHub Issues: https://github.com/lumina-protocol/contracts/issues
