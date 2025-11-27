// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @notice Mock USDT token for testing with public faucet function
 * @dev Anyone can mint tokens for testing purposes
 */
contract MockUSDT is ERC20 {
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**18; // 1000 USDT per request
    uint256 public constant COOLDOWN_TIME = 1 hours; // Cooldown between faucet requests
    
    mapping(address => uint256) public lastFaucetTime;
    
    event FaucetUsed(address indexed user, uint256 amount);
    
    constructor() ERC20("Mock USDT", "mUSDT") {
        // Mint initial supply to deployer for transfers
        _mint(msg.sender, 1000000 * 10**18); // 1M USDT
    }
    
    /**
     * @notice Public faucet function - anyone can call to get test USDT
     * @dev Has cooldown to prevent spam
     */
    function faucet() external {
        require(
            block.timestamp >= lastFaucetTime[msg.sender] + COOLDOWN_TIME,
            "Faucet cooldown active. Please wait."
        );
        
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
        
        emit FaucetUsed(msg.sender, FAUCET_AMOUNT);
    }
    
    /**
     * @notice Check if address can use faucet
     * @param user Address to check
     * @return canUse True if user can use faucet now
     * @return timeLeft Seconds until faucet is available (0 if available now)
     */
    function canUseFaucet(address user) external view returns (bool canUse, uint256 timeLeft) {
        uint256 nextAvailable = lastFaucetTime[user] + COOLDOWN_TIME;
        
        if (block.timestamp >= nextAvailable) {
            return (true, 0);
        } else {
            return (false, nextAvailable - block.timestamp);
        }
    }
    
    /**
     * @notice Mint tokens to specific address (only for testing/setup)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
