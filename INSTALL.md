# Installation Instructions

## Install Dependencies

Run these commands in the `contracts` directory:

```bash
# Install OpenZeppelin Contracts
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Install Forge Standard Library (should already be installed)
forge install foundry-rs/forge-std --no-commit

# Build contracts
forge build

# Run tests
forge test
```

## If you get "already exists" error:

```bash
# Remove and reinstall
rm -rf lib/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

## Verify Installation

After installation, you should have:
- `lib/openzeppelin-contracts/` directory
- `lib/forge-std/` directory

Then run:
```bash
forge build
```

Should compile without errors.
