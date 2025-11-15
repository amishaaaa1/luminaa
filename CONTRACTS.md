# Smart Contracts Documentation

Comprehensive guide to Lumina's smart contract architecture.

## Contract Overview

### InsurancePool.sol

Manages liquidity pools for insurance coverage.

**Key Features**:
- Share-based liquidity provision
- Dynamic premium collection
- Automated claim payouts
- Utilization-based pricing

**Main Functions**:

```solidity
// Deposit liquidity and receive shares
function deposit(uint256 amount) external returns (uint256 shares)

// Withdraw liquidity by burning shares
function withdraw(uint256 shares) external returns (uint256 amount)

// Collect premium from policy (PolicyManager only)
function collectPremium(uint256 policyId, uint256 amount) external

// Pay claim to beneficiary (PolicyManager only)
function payClaim(uint256 policyId, address beneficiary, uint256 amount) external

// View pool information
function getPoolInfo() external view returns (PoolInfo memory)

// View provider information
function getProviderInfo(address provider) external view returns (ProviderInfo memory)

// Calculate current share value
function calculateShareValue() external view returns (uint256)

// Check if pool can cover new policy
function canCoverPolicy(uint256 coverageAmount) external view returns (bool)
```

**Events**:
```solidity
event LiquidityDeposited(address indexed provider, uint256 amount, uint256 shares)
event LiquidityWithdrawn(address indexed provider, uint256 amount, uint256 shares)
event PremiumCollected(uint256 indexed policyId, uint256 amount)
event ClaimPaid(uint256 indexed policyId, address indexed beneficiary, uint256 amount)
```

### PolicyManager.sol

Issues and manages insurance policies as NFTs.

**Key Features**:
- ERC-721 policy NFTs
- Premium calculation
- Claim verification
- Policy lifecycle management

**Main Functions**:

```solidity
// Create new insurance policy
function createPolicy(
    address holder,
    string calldata marketId,
    uint256 coverageAmount,
    uint256 premium,
    uint256 duration
) external returns (uint256 policyId)

// Claim insurance payout
function claimPolicy(uint256 policyId) external returns (uint256 payout)

// Expire policy after expiry time
function expirePolicy(uint256 policyId) external

// Get policy details
function getPolicy(uint256 policyId) external view returns (Policy memory)

// Get all policies for user
function getUserPolicies(address user) external view returns (uint256[] memory)

// Calculate premium for coverage
function calculatePremium(
    string calldata marketId,
    uint256 coverageAmount
) external view returns (uint256)

// Update market risk score (governance)
function updateMarketRisk(string calldata marketId, uint256 riskScore) external
```

**Events**:
```solidity
event PolicyCreated(
    uint256 indexed policyId,
    address indexed holder,
    string marketId,
    uint256 coverageAmount,
    uint256 premium
)
event PolicyClaimed(uint256 indexed policyId, uint256 payoutAmount)
event PolicyExpired(uint256 indexed policyId)
```

### LuminaOracle.sol

Verifies prediction market outcomes for claim processing.

**Key Features**:
- Centralized oracle (MVP)
- Authorized resolvers
- Market outcome verification
- Dispute handling (basic)

**Main Functions**:

```solidity
// Resolve prediction market outcome
function resolveMarket(string calldata marketId, bytes32 outcomeHash) external

// Get market outcome details
function getMarketOutcome(string calldata marketId) external view returns (MarketOutcome memory)

// Check if market is resolved
function isMarketResolved(string calldata marketId) external view returns (bool)

// Verify outcome matches expected value
function verifyOutcome(string calldata marketId, bytes32 expectedOutcome) external view returns (bool)

// Add authorized resolver (owner only)
function addResolver(address resolver) external

// Remove authorized resolver (owner only)
function removeResolver(address resolver) external
```

**Events**:
```solidity
event MarketResolved(string indexed marketId, bytes32 outcomeHash, uint256 timestamp)
event MarketDisputed(string indexed marketId, address indexed disputer)
```

## Usage Examples

### Example 1: Provide Liquidity

```solidity
// 1. Approve tokens
IERC20(assetToken).approve(address(pool), 1000e18);

// 2. Deposit liquidity
uint256 shares = pool.deposit(1000e18);

// 3. Check your position
ProviderInfo memory info = pool.getProviderInfo(msg.sender);
```

### Example 2: Buy Insurance

```solidity
// 1. Calculate premium
uint256 premium = policyManager.calculatePremium("market-123", 100e18);

// 2. Approve tokens
IERC20(assetToken).approve(address(policyManager), premium);

// 3. Create policy
uint256 policyId = policyManager.createPolicy(
    msg.sender,
    "market-123",
    100e18,      // coverage
    premium,
    30 days      // duration
);

// 4. Policy NFT is minted to your address
```

### Example 3: Claim Insurance

```solidity
// 1. Wait for market resolution
require(oracle.isMarketResolved("market-123"), "Not resolved");

// 2. Claim payout
uint256 payout = policyManager.claimPolicy(policyId);

// 3. Receive coverage amount
```

### Example 4: Withdraw Liquidity

```solidity
// 1. Check your shares
ProviderInfo memory info = pool.getProviderInfo(msg.sender);

// 2. Withdraw all shares
uint256 amount = pool.withdraw(info.shares);

// 3. Receive tokens + earned premiums
```

## Integration Guide

### Frontend Integration

```typescript
import { useWriteContract, useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';

// Read pool info
const { data: poolInfo } = useReadContract({
  ...CONTRACTS.InsurancePool,
  functionName: 'getPoolInfo',
});

// Create policy
const { writeContract } = useWriteContract();

writeContract({
  ...CONTRACTS.PolicyManager,
  functionName: 'createPolicy',
  args: [holder, marketId, coverage, premium, duration],
});
```

### Backend Integration

```javascript
const { ethers } = require('ethers');

// Connect to contract
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const oracle = new ethers.Contract(ORACLE_ADDRESS, ORACLE_ABI, wallet);

// Resolve market
await oracle.resolveMarket('market-123', outcomeHash);
```

## Security Considerations

### Access Control

- **InsurancePool**: Only PolicyManager can collect premiums and pay claims
- **PolicyManager**: Only policy owner can claim
- **LuminaOracle**: Only authorized resolvers can resolve markets

### Reentrancy Protection

All state-changing functions use `nonReentrant` modifier:
- `deposit()`
- `withdraw()`
- `createPolicy()`
- `claimPolicy()`
- `payClaim()`

### Input Validation

- Coverage amounts: MIN_COVERAGE to MAX_COVERAGE
- Policy duration: MIN_DURATION to MAX_DURATION
- Utilization: Maximum 80% to ensure liquidity
- Premium: Must meet calculated minimum

### Token Safety

- Uses OpenZeppelin's SafeERC20
- Checks balances before transfers
- Approvals required before operations

## Gas Optimization

### Storage Optimization

```solidity
// Packed struct (single slot)
struct ProviderInfo {
    uint128 shares;          // 16 bytes
    uint128 depositedAmount; // 16 bytes
}

// Immutable addresses (no SLOAD)
IERC20 public immutable asset;
address public immutable policyManager;
```

### Computation Optimization

```solidity
// Library for complex calculations
library PremiumCalculator {
    function calculatePremium(...) internal pure returns (uint256) {
        // Pure function, no storage access
    }
}
```

## Testing

### Unit Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/InsurancePool.t.sol

# Run with gas report
forge test --gas-report
```

### Integration Tests

```bash
# Test full flow
forge test --match-test testFullInsuranceFlow -vvv
```

### Fuzzing

```solidity
function testFuzz_Deposit(uint256 amount) public {
    vm.assume(amount > 0 && amount < 1000000e18);
    // Test with random amounts
}
```

## Deployment

### Local Testing

```bash
# Start local node
anvil

# Deploy to local
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

```bash
# Deploy to BNB Testnet
forge script script/Deploy.s.sol \
  --rpc-url bnb_testnet \
  --broadcast \
  --verify
```

### Verification

```bash
# Verify on BscScan
forge verify-contract \
  --chain-id 97 \
  --compiler-version v0.8.24 \
  CONTRACT_ADDRESS \
  src/InsurancePool.sol:InsurancePool
```

## Upgrade Path

For production, consider:

1. **Upgradeable Contracts**: Use UUPS or Transparent Proxy pattern
2. **Timelock**: Add delay for sensitive operations
3. **Multi-sig**: Require multiple signatures for admin functions
4. **Pause Mechanism**: Emergency stop functionality

## Support

For contract-specific questions:
- Review test files in `test/`
- Check interface definitions in `src/interfaces/`
- Read inline documentation in source files

---

Built with Foundry and OpenZeppelin 🛠️
