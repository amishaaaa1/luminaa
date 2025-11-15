@echo off
echo Setting up Lumina Smart Contracts...

echo Installing OpenZeppelin...
forge install OpenZeppelin/openzeppelin-contracts --no-commit

echo Installing Forge Standard Library...
forge install foundry-rs/forge-std --no-commit

echo Building contracts...
forge build

echo Running tests...
forge test

echo Setup complete!
echo.
echo Next steps:
echo 1. Copy .env.example to .env
echo 2. Add your PRIVATE_KEY and ASSET_TOKEN
echo 3. Deploy: forge script script/Deploy.s.sol --rpc-url bnb_testnet --broadcast
