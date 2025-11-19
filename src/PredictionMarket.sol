// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILuminaOracle} from "./interfaces/ILuminaOracle.sol";

/**
 * @title PredictionMarket - Native prediction market for Lumina
 * @notice Binary outcome markets (Yes/No) with automated market maker
 * @dev Uses constant product formula for pricing (similar to Uniswap)
 */
contract PredictionMarket is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Market {
        string marketId;
        string question;
        string protocol;
        string riskType;
        uint256 deadline;
        uint256 yesPool;
        uint256 noPool;
        uint256 totalVolume;
        uint256 participantCount;
        bool resolved;
        bool outcome; // true = Yes, false = No
        bool insuranceEnabled;
    }

    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }

    IERC20 public immutable asset;
    ILuminaOracle public oracle;
    
    uint256 public marketCounter;
    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Position)) public positions;
    
    uint256 private constant FEE_RATE = 200; // 2% fee
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MIN_BET = 1e18; // 1 USDC
    uint256 private constant MAX_BET = 10000e18; // 10,000 USDC

    event MarketCreated(
        uint256 indexed marketId,
        string question,
        string protocol,
        uint256 deadline
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        bool outcome,
        uint256 amount,
        uint256 shares
    );
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);

    constructor(address _asset, address _oracle) Ownable(msg.sender) {
        require(_asset != address(0), "Invalid asset");
        require(_oracle != address(0), "Invalid oracle");
        asset = IERC20(_asset);
        oracle = ILuminaOracle(_oracle);
    }

    /**
     * @notice Create new prediction market
     * @param question Market question
     * @param protocol Protocol name
     * @param riskType Type of risk (Hack, Exploit, Depeg)
     * @param duration Duration in seconds
     * @param initialLiquidity Initial liquidity for both sides
     * @param insuranceEnabled Whether insurance is available
     */
    function createMarket(
        string calldata question,
        string calldata protocol,
        string calldata riskType,
        uint256 duration,
        uint256 initialLiquidity,
        bool insuranceEnabled
    ) external onlyOwner returns (uint256 marketId) {
        require(bytes(question).length > 0, "Empty question");
        require(duration >= 1 days && duration <= 365 days, "Invalid duration");
        require(initialLiquidity >= 1000e18, "Min 1000 USDC liquidity");

        marketId = ++marketCounter;
        string memory marketIdStr = string(abi.encodePacked("market-", _toString(marketId)));

        markets[marketId] = Market({
            marketId: marketIdStr,
            question: question,
            protocol: protocol,
            riskType: riskType,
            deadline: block.timestamp + duration,
            yesPool: initialLiquidity,
            noPool: initialLiquidity,
            totalVolume: 0,
            participantCount: 0,
            resolved: false,
            outcome: false,
            insuranceEnabled: insuranceEnabled
        });

        // Transfer initial liquidity from owner
        asset.safeTransferFrom(msg.sender, address(this), initialLiquidity * 2);

        emit MarketCreated(marketId, question, protocol, block.timestamp + duration);
    }

    /**
     * @notice Place bet on market outcome
     * @param marketId Market ID
     * @param outcome true = Yes, false = No
     * @param amount Bet amount
     */
    function placeBet(
        uint256 marketId,
        bool outcome,
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        Market storage market = markets[marketId];
        require(bytes(market.marketId).length > 0, "Market not found");
        require(block.timestamp < market.deadline, "Market closed");
        require(!market.resolved, "Market resolved");
        require(amount >= MIN_BET && amount <= MAX_BET, "Invalid amount");

        // Calculate shares using constant product formula
        uint256 poolBefore = outcome ? market.yesPool : market.noPool;
        uint256 oppositePool = outcome ? market.noPool : market.yesPool;
        
        // shares = amount * oppositePool / (poolBefore + amount)
        shares = (amount * oppositePool) / (poolBefore + amount);
        require(shares > 0, "Shares too small");

        // Take 2% fee
        uint256 fee = (amount * FEE_RATE) / BASIS_POINTS;
        uint256 netAmount = amount - fee;

        // Update pools
        if (outcome) {
            market.yesPool += netAmount;
        } else {
            market.noPool += netAmount;
        }
        market.totalVolume += amount;

        // Update position
        Position storage position = positions[marketId][msg.sender];
        if (position.yesAmount == 0 && position.noAmount == 0) {
            market.participantCount++;
        }
        
        if (outcome) {
            position.yesAmount += shares;
        } else {
            position.noAmount += shares;
        }

        // Transfer tokens
        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit BetPlaced(marketId, msg.sender, outcome, amount, shares);
    }

    /**
     * @notice Resolve market using oracle
     * @param marketId Market ID
     */
    function resolveMarket(uint256 marketId) external {
        Market storage market = markets[marketId];
        require(bytes(market.marketId).length > 0, "Market not found");
        require(block.timestamp >= market.deadline, "Market not closed");
        require(!market.resolved, "Already resolved");

        // Check oracle for resolution
        require(oracle.isMarketResolved(market.marketId), "Oracle not resolved");
        
        ILuminaOracle.MarketOutcome memory oracleOutcome = oracle.getMarketOutcome(market.marketId);
        require(oracleOutcome.isResolved, "Oracle not resolved");

        // Decode outcome from hash (for simplicity, we use first byte)
        market.outcome = uint8(oracleOutcome.outcomeHash[0]) > 127;
        market.resolved = true;

        emit MarketResolved(marketId, market.outcome);
    }

    /**
     * @notice Claim winnings after market resolves
     * @param marketId Market ID
     */
    function claimWinnings(uint256 marketId) external nonReentrant returns (uint256 payout) {
        Market storage market = markets[marketId];
        require(market.resolved, "Market not resolved");

        Position storage position = positions[marketId][msg.sender];
        require(!position.claimed, "Already claimed");
        
        uint256 winningShares = market.outcome ? position.yesAmount : position.noAmount;
        require(winningShares > 0, "No winning position");

        // Calculate payout: shares * (losingPool / winningPool)
        uint256 winningPool = market.outcome ? market.yesPool : market.noPool;
        uint256 losingPool = market.outcome ? market.noPool : market.yesPool;
        
        payout = (winningShares * (winningPool + losingPool)) / winningPool;

        position.claimed = true;

        asset.safeTransfer(msg.sender, payout);

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    /**
     * @notice Get market details
     * @param marketId Market ID
     */
    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    /**
     * @notice Get user position
     * @param marketId Market ID
     * @param user User address
     */
    function getPosition(uint256 marketId, address user) external view returns (Position memory) {
        return positions[marketId][user];
    }

    /**
     * @notice Calculate current odds
     * @param marketId Market ID
     * @return yesOdds Yes odds (0-10000)
     * @return noOdds No odds (0-10000)
     */
    function getOdds(uint256 marketId) external view returns (uint256 yesOdds, uint256 noOdds) {
        Market storage market = markets[marketId];
        uint256 total = market.yesPool + market.noPool;
        if (total == 0) return (5000, 5000);
        
        yesOdds = (market.yesPool * BASIS_POINTS) / total;
        noOdds = (market.noPool * BASIS_POINTS) / total;
    }

    /**
     * @notice Calculate potential payout for bet
     * @param marketId Market ID
     * @param outcome Bet outcome
     * @param amount Bet amount
     */
    function calculatePayout(
        uint256 marketId,
        bool outcome,
        uint256 amount
    ) external view returns (uint256 shares, uint256 potentialPayout) {
        Market storage market = markets[marketId];
        
        uint256 poolBefore = outcome ? market.yesPool : market.noPool;
        uint256 oppositePool = outcome ? market.noPool : market.yesPool;
        
        uint256 fee = (amount * FEE_RATE) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        
        shares = (netAmount * oppositePool) / (poolBefore + netAmount);
        
        uint256 newPool = poolBefore + netAmount;
        potentialPayout = (shares * (newPool + oppositePool)) / newPool;
    }

    /**
     * @notice Emergency withdraw (owner only, before resolution)
     * @param marketId Market ID
     */
    function emergencyWithdraw(uint256 marketId) external onlyOwner {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market resolved");
        require(block.timestamp > market.deadline + 30 days, "Wait 30 days after deadline");

        uint256 totalLiquidity = market.yesPool + market.noPool;
        market.resolved = true;
        
        asset.safeTransfer(owner(), totalLiquidity);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}
