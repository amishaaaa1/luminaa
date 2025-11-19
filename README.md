# Contracts

## Setup

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
forge build
forge test -vvv
```

Or run `setup.sh` / `setup.bat`

## Contracts

- InsurancePool - LP stuff
- PolicyManager - NFT policies, claims
- LuminaOracle - Market resolution
- PremiumCalculator - Pricing

## Test

```bash
forge test
forge test --gas-report
forge test --match-test testDeposit -vvv
forge coverage
```

## Deploy

```bash
cp .env.example .env
# add PRIVATE_KEY and ASSET_TOKEN

forge script script/Deploy.s.sol --rpc-url bnb_testnet --broadcast --verify
```

Save addresses for frontend

## Security

ReentrancyGuard, SafeERC20, access control, 80% cap
