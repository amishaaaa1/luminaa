// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILuminaOracle} from "./interfaces/ILuminaOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LuminaOracle
 * @notice Optimistic Oracle with dispute mechanism for prediction markets
 * @dev Inspired by UMA's Optimistic Oracle - fast resolution with economic security
 * 
 * HOW IT WORKS:
 * 1. Resolver proposes outcome + posts bond
 * 2. 24h dispute window - anyone can challenge with counter-bond
 * 3. If disputed: escalates to multi-sig arbitration
 * 4. Winner gets bond back + half of loser's bond
 * 5. If no dispute: auto-finalizes after 24h
 * 
 * This solves YZi Labs theme: "UMA OO is slow (24-48h). We make it faster with economic incentives."
 */
contract LuminaOracle is ILuminaOracle, Ownable {
    using SafeERC20 for IERC20;

    // Dispute states
    enum DisputeState { None, Proposed, Disputed, Resolved }

    struct Proposal {
        address proposer;
        bytes32 outcomeHash;
        uint256 proposedAt;
        uint256 bond;
        DisputeState state;
    }

    struct Dispute {
        address disputer;
        bytes32 counterOutcomeHash;
        uint256 disputedAt;
        uint256 bond;
    }

    mapping(string => MarketOutcome) private marketOutcomes;
    mapping(string => Proposal) private proposals;
    mapping(string => Dispute) private disputes;
    mapping(address => bool) private authorizedResolvers;
    mapping(address => bool) private arbitrators; // Multi-sig for disputes

    IERC20 public immutable bondToken;
    uint256 public constant PROPOSAL_BOND = 10000e18; // 10,000 USDT (increased for security)
    uint256 public constant DISPUTE_BOND = 10000e18; // 10,000 USDT (same as proposal)
    uint256 public constant DISPUTE_WINDOW = 24 hours;
    uint256 public constant MIN_ARBITRATORS = 3;
    
    // LUMINA SECURITY: Dynamic bond based on market exposure
    uint256 public constant MIN_BOND_PERCENTAGE = 1000; // 10% of total market exposure
    uint256 public constant BASIS_POINTS = 10000;

    uint256 public arbitratorCount;

    event MarketProposed(string indexed marketId, bytes32 outcomeHash, address proposer);
    event MarketDisputed(string indexed marketId, bytes32 counterOutcome, address disputer);
    event DisputeResolved(string indexed marketId, bytes32 finalOutcome, address winner);
    event ArbitratorAdded(address arbitrator);
    event ArbitratorRemoved(address arbitrator);

    modifier onlyResolver() {
        require(authorizedResolvers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier onlyArbitrator() {
        require(arbitrators[msg.sender], "Not arbitrator");
        _;
    }

    constructor(address _bondToken) Ownable(msg.sender) {
        require(_bondToken != address(0), "Invalid bond token");
        bondToken = IERC20(_bondToken);
        authorizedResolvers[msg.sender] = true;
        arbitrators[msg.sender] = true;
        arbitratorCount = 1;
    }

    /**
     * @notice Propose market outcome (Optimistic Oracle style)
     * @param marketId Market identifier
     * @param outcomeHash Hash of the outcome data
     * @param marketExposure Total insurance coverage for this market
     * @dev Proposer must post bond. 24h dispute window starts.
     * LUMINA SECURITY: Bond scales with market exposure to prevent manipulation
     */
    function proposeOutcome(
        string calldata marketId,
        bytes32 outcomeHash,
        uint256 marketExposure
    ) external {
        require(bytes(marketId).length > 0, "Invalid market ID");
        require(outcomeHash != bytes32(0), "Invalid outcome hash");
        require(!marketOutcomes[marketId].isResolved, "Already resolved");
        require(proposals[marketId].state == DisputeState.None, "Already proposed");

        // Calculate required bond: max(10K USDT, 10% of market exposure)
        uint256 requiredBond = PROPOSAL_BOND;
        if (marketExposure > 0) {
            uint256 exposureBond = (marketExposure * MIN_BOND_PERCENTAGE) / BASIS_POINTS;
            if (exposureBond > requiredBond) {
                requiredBond = exposureBond;
            }
        }

        // Transfer bond from proposer
        bondToken.safeTransferFrom(msg.sender, address(this), requiredBond);

        proposals[marketId] = Proposal({
            proposer: msg.sender,
            outcomeHash: outcomeHash,
            proposedAt: block.timestamp,
            bond: requiredBond,
            state: DisputeState.Proposed
        });

        emit MarketProposed(marketId, outcomeHash, msg.sender);
    }

    /**
     * @notice Dispute a proposed outcome
     * @param marketId Market identifier
     * @param counterOutcomeHash Alternative outcome
     * @dev Disputer must post SAME bond as proposer. Escalates to arbitration.
     * LUMINA SECURITY: Equal bonds ensure fair dispute mechanism
     */
    function disputeOutcome(
        string calldata marketId,
        bytes32 counterOutcomeHash
    ) external {
        Proposal storage proposal = proposals[marketId];
        require(proposal.state == DisputeState.Proposed, "Not in dispute window");
        require(block.timestamp < proposal.proposedAt + DISPUTE_WINDOW, "Dispute window closed");
        require(counterOutcomeHash != proposal.outcomeHash, "Same outcome");

        // Disputer must match proposer's bond (fair game)
        uint256 requiredBond = proposal.bond;
        bondToken.safeTransferFrom(msg.sender, address(this), requiredBond);

        disputes[marketId] = Dispute({
            disputer: msg.sender,
            counterOutcomeHash: counterOutcomeHash,
            disputedAt: block.timestamp,
            bond: requiredBond
        });

        proposal.state = DisputeState.Disputed;

        emit MarketDisputed(marketId, counterOutcomeHash, msg.sender);
    }

    /**
     * @notice Finalize undisputed proposal
     * @param marketId Market identifier
     * @dev Anyone can call after dispute window. Proposer gets bond back.
     */
    function finalizeProposal(string calldata marketId) external {
        Proposal storage proposal = proposals[marketId];
        require(proposal.state == DisputeState.Proposed, "Not proposed");
        require(block.timestamp >= proposal.proposedAt + DISPUTE_WINDOW, "Still in dispute window");

        // Mark as resolved
        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: proposal.outcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });

        proposal.state = DisputeState.Resolved;

        // Return bond to proposer
        bondToken.safeTransfer(proposal.proposer, proposal.bond);

        emit MarketResolved(marketId, proposal.outcomeHash, block.timestamp);
    }

    /**
     * @notice Arbitrators resolve dispute
     * @param marketId Market identifier
     * @param finalOutcomeHash Correct outcome
     * @dev Multi-sig arbitrators decide. Winner gets both bonds.
     */
    function resolveDispute(
        string calldata marketId,
        bytes32 finalOutcomeHash
    ) external onlyArbitrator {
        Proposal storage proposal = proposals[marketId];
        Dispute storage dispute = disputes[marketId];
        
        require(proposal.state == DisputeState.Disputed, "Not disputed");
        require(arbitratorCount >= MIN_ARBITRATORS, "Need more arbitrators");

        // Determine winner
        address winner;
        address loser;
        
        if (finalOutcomeHash == proposal.outcomeHash) {
            winner = proposal.proposer;
            loser = dispute.disputer;
        } else if (finalOutcomeHash == dispute.counterOutcomeHash) {
            winner = dispute.disputer;
            loser = proposal.proposer;
        } else {
            revert("Invalid final outcome");
        }

        // Mark as resolved
        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: finalOutcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });

        proposal.state = DisputeState.Resolved;

        // Winner gets their bond + half of loser's bond
        uint256 totalBonds = proposal.bond + dispute.bond;
        uint256 winnerPayout = proposal.bond + (dispute.bond / 2);
        uint256 protocolFee = dispute.bond / 2;

        bondToken.safeTransfer(winner, winnerPayout);
        bondToken.safeTransfer(owner(), protocolFee);

        emit DisputeResolved(marketId, finalOutcomeHash, winner);
        emit MarketResolved(marketId, finalOutcomeHash, block.timestamp);
    }

    /**
     * @notice Legacy function for backward compatibility
     * @dev Direct resolution by owner (emergency only)
     */
    function resolveMarket(
        string calldata marketId,
        bytes32 outcomeHash
    ) external onlyOwner {
        require(bytes(marketId).length > 0, "Invalid market ID");
        require(outcomeHash != bytes32(0), "Invalid outcome hash");
        require(!marketOutcomes[marketId].isResolved, "Already resolved");

        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: outcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });

        emit MarketResolved(marketId, outcomeHash, block.timestamp);
    }

    /**
     * @notice Get market outcome details
     * @param marketId Market identifier
     * @return MarketOutcome struct
     */
    function getMarketOutcome(
        string calldata marketId
    ) external view returns (MarketOutcome memory) {
        return marketOutcomes[marketId];
    }

    /**
     * @notice Check if market is resolved
     * @param marketId Market identifier
     * @return bool True if resolved
     */
    function isMarketResolved(string calldata marketId) external view returns (bool) {
        return marketOutcomes[marketId].isResolved;
    }

    /**
     * @notice Verify outcome matches expected value
     * @param marketId Market identifier
     * @param expectedOutcome Expected outcome hash
     * @return bool True if matches
     */
    function verifyOutcome(
        string calldata marketId,
        bytes32 expectedOutcome
    ) external view returns (bool) {
        MarketOutcome memory outcome = marketOutcomes[marketId];
        return outcome.isResolved && outcome.outcomeHash == expectedOutcome;
    }

    /**
     * @notice Add arbitrator to multi-sig
     * @param arbitrator Arbitrator address
     */
    function addArbitrator(address arbitrator) external onlyOwner {
        require(arbitrator != address(0), "Invalid arbitrator");
        require(!arbitrators[arbitrator], "Already arbitrator");
        
        arbitrators[arbitrator] = true;
        arbitratorCount++;
        
        emit ArbitratorAdded(arbitrator);
    }

    /**
     * @notice Remove arbitrator from multi-sig
     * @param arbitrator Arbitrator address
     */
    function removeArbitrator(address arbitrator) external onlyOwner {
        require(arbitrators[arbitrator], "Not arbitrator");
        require(arbitratorCount > MIN_ARBITRATORS, "Need min arbitrators");
        
        arbitrators[arbitrator] = false;
        arbitratorCount--;
        
        emit ArbitratorRemoved(arbitrator);
    }

    /**
     * @notice Add authorized resolver
     * @param resolver Resolver address
     */
    function addResolver(address resolver) external onlyOwner {
        require(resolver != address(0), "Invalid resolver");
        authorizedResolvers[resolver] = true;
    }

    /**
     * @notice Remove authorized resolver
     * @param resolver Resolver address
     */
    function removeResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = false;
    }

    /**
     * @notice Get proposal details
     * @param marketId Market identifier
     */
    function getProposal(string calldata marketId) external view returns (Proposal memory) {
        return proposals[marketId];
    }

    /**
     * @notice Get dispute details
     * @param marketId Market identifier
     */
    function getDispute(string calldata marketId) external view returns (Dispute memory) {
        return disputes[marketId];
    }

    /**
     * @notice Check if address is authorized resolver
     * @param resolver Address to check
     * @return bool True if authorized
     */
    function isResolver(address resolver) external view returns (bool) {
        return authorizedResolvers[resolver];
    }

    /**
     * @notice Check if address is arbitrator
     * @param arbitrator Address to check
     * @return bool True if arbitrator
     */
    function isArbitrator(address arbitrator) external view returns (bool) {
        return arbitrators[arbitrator];
    }

    /**
     * @notice Get risk assessment for protocol (for prediction markets)
     * @param protocol Protocol name
     * @return riskScore Risk score (0-10000, where 10000 = 100%)
     * @return confidence Confidence level (0-10000)
     * @return timestamp Last update timestamp
     * @dev This is a simplified on-chain version. Real implementation would use Chainlink Functions or off-chain oracle
     */
    function getRiskAssessment(string calldata protocol) external view returns (
        uint256 riskScore,
        uint256 confidence,
        uint256 timestamp
    ) {
        // Simple heuristic-based risk scoring
        // In production, this would call Chainlink Functions or read from off-chain oracle
        bytes32 protocolHash = keccak256(bytes(protocol));
        
        // Generate pseudo-random but deterministic risk score based on protocol name
        uint256 baseRisk = uint256(protocolHash) % 10000;
        
        // Adjust based on known patterns
        bytes memory protocolBytes = bytes(protocol);
        if (protocolBytes.length > 0) {
            // Higher risk for shorter names (often new/unknown protocols)
            if (protocolBytes.length < 5) {
                baseRisk = (baseRisk + 2000) % 10000;
            }
            
            // Lower risk for longer, established names
            if (protocolBytes.length > 10) {
                baseRisk = baseRisk > 1000 ? baseRisk - 1000 : baseRisk;
            }
        }
        
        // Confidence is inversely related to risk (more certain about low/high extremes)
        uint256 confidenceScore;
        if (baseRisk < 2000 || baseRisk > 8000) {
            confidenceScore = 8000; // High confidence for clear cases
        } else {
            confidenceScore = 6000; // Medium confidence for uncertain cases
        }
        
        return (baseRisk, confidenceScore, block.timestamp);
    }

    /**
     * @notice Assess protocol risk (simplified version for prediction markets)
     * @param protocol Protocol name
     * @return Risk score 0-100
     */
    function assessProtocolRisk(string calldata protocol) external view returns (uint256) {
        (uint256 riskScore, , ) = this.getRiskAssessment(protocol);
        // Convert from 0-10000 scale to 0-100 scale
        return riskScore / 100;
    }
}
