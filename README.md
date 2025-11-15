# Lumina Smart Contracts

Insurance protocol for prediction markets on BNB Chain.

## Quick Start

```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit

# Build
forge build

# Test
forge test -vvv

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url bnb_testnet --broadcast
```

Or use the setup script:
```bash
# Linux/Mac
chmod +x setup.sh
./setup.sh

# Windows
setup.bat
```

## Contracts

- **InsurancePool.sol** - LP deposits, withdrawals, premium collection
- **PolicyManager.sol** - Policy issuance as NFTs, claims processing
- **LuminaOracle.sol** - Market outcome resolution
- **PremiumCalculator.sol** - Dynamic pricing library

## Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run specific test
forge test --match-test testDeposit -vvv

# Coverage
forge coverage
```

## Deployment

1. Setup environment:
```bash
cp .env.example .env
# Add PRIVATE_KEY and ASSET_TOKEN
```

2. Deploy to BNB Testnet:
```bash
forge script script/Deploy.s.sol \
  --rpc-url bnb_testnet \
  --broadcast \
  --verify
```

3. Save deployed addresses for frontend

## Architecture

```
InsurancePool
├── Manages liquidity (deposits/withdrawals)
├── Collects premiums from policies
└── Pays out claims

PolicyManager
├── Issues policies as ERC-721 NFTs
├── Calculates premiums dynamically
└── Processes claims via oracle

LuminaOracle
├── Resolves prediction market outcomes
└── Authorizes resolvers
```

## Security

- ReentrancyGuard on all state-changing functions
- SafeERC20 for token transfers
- Access control (onlyPolicyManager, onlyOwner)
- 80% utilization cap to ensure liquidity

## Gas Optimization

- Immutable variables for addresses
- Packed structs
- Pure functions in library
- Efficient storage layout

## Documentation

See [CONTRACTS.md](CONTRACTS.md) for detailed documentation.
