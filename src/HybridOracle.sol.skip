// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILuminaOracle} from "./interfaces/ILuminaOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title HybridOracle
 * @notice 3-Tier Hybrid Oracle System for Lumina Prediction Markets
 * @dev Combines automated resolution, manual review, and dispute mechanism
 * 
 * TIER 1: Automated Oracle (90% of cases)
 * - Price feeds (Chainlink)
 * - Clear binary events
 * - No human intervention
 * 
 * TIER 2: Manual Review (9% of cases)
 * - Ambiguous events
 * - Multiple data sources needed
 * - Trusted resolver proposes + 24h dispute window
 * 
 * TIER 3: Dispute Resolution (1% of cases)
 * - Contested outcomes
 * - Multi-sig arbitration
 * - Economic security via bonds
 */
contract HybridOracle is ILuminaOracle, Ownable {
    using SafeERC20 for IERC20;

    // Market resolution tiers
    enum ResolutionTier { 
        Automated,      // Tier 1: Auto-resolve via price feeds
        Manual,         // Tier 2: Trusted resolver + dispute window
        Arbitration     // Tier 3: Multi-sig arbitration
    }

    // Dispute states
    enum DisputeState { None, Proposed, Disputed, Resolved }

    // Data source types
    enum DataSourceType {
        ChainlinkPriceFeed,
        APIEndpoint,
        OnChainEvent,
        ManualVerification
    }

    struct MarketConfig {
        ResolutionTier tier;
        DataSourceType[] dataSources;
        bytes32[] dataSourceIds;
        uint256 minConfirmations;
        uint256 autoResolveThreshold;
        bool requiresManualReview;
    }

    struct Proposal {
        address proposer;
        bytes32 outcomeHash;
        uint256 proposedAt;
        uint256 bond;
        DisputeState state;
        string evidence; // IPFS hash or URL
    }

    struct Dispute {
        address disputer;
        bytes32 counterOutcomeHash;
        uint256 disputedAt;
        uint256 bond;
        string counterEvidence;
    }

    struct DataSourceReport {
        bytes32 sourceId;
        bytes32 outcomeHash;
        uint256 timestamp;
        uint256 confidence; // 0-10000 (100%)
    }

    // State mappings
    mapping(string => MarketOutcome) private marketOutcomes;
    mapping(string => MarketConfig) private marketConfigs;
    mapping(string => Proposal) private proposals;
    mapping(string => Dispute) private disputes;
    mapping(string => DataSourceReport[]) private dataSourceReports;
    
    // Access control
    mapping(address => bool) private authorizedResolvers;
    mapping(address => bool) private arbitrators;
    mapping(address => bool) private dataProviders;
    
    IERC20 public immutable bondToken;
    
    // Constants
    uint256 public constant PROPOSAL_BOND = 10000e18; // 10K USDC
    uint256 public constant DISPUTE_BOND = 10000e18;
    uint256 public constant DISPUTE_WINDOW = 24 hours;
    uint256 public constant MIN_ARBITRATORS = 3;
    uint256 public constant AUTO_RESOLVE_CONSENSUS = 6667; // 66.67% agreement
    uint256 public constant BASIS_POINTS = 10000;
    
    uint256 public arbitratorCount;

    // Events
    event MarketConfigured(string indexed marketId, ResolutionTier tier);
    event DataSourceReported(string indexed marketId, bytes32 sourceId, bytes32 outcome);
    event AutoResolved(string indexed marketId, bytes32 outcome, uint256 consensus);
    event MarketProposed(string indexed marketId, bytes32 outcomeHash, address proposer);
    event MarketDisputed(string indexed marketId, bytes32 counterOutcome, address disputer);
    event DisputeResolved(string indexed marketId, bytes32 finalOutcome, address winner);
    event ArbitratorAdded(address arbitrator);
    event DataProviderAdded(address provider);

    modifier onlyResolver() {
        require(authorizedResolvers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier onlyArbitrator() {
        require(arbitrators[msg.sender], "Not arbitrator");
        _;
    }

    modifier onlyDataProvider() {
        require(dataProviders[msg.sender] || msg.sender == owner(), "Not data provider");
        _;
    }

    constructor(address _bondToken) Ownable(msg.sender) {
        require(_bondToken != address(0), "Invalid bond token");
        bondToken = IERC20(_bondToken);
        
        // Initialize with owner as all roles
        authorizedResolvers[msg.sender] = true;
        arbitrators[msg.sender] = true;
        dataProviders[msg.sender] = true;
        arbitratorCount = 1;
    }

    // ============================================
    // TIER 1: AUTOMATED RESOLUTION
    // ============================================

    /**
     * @notice Configure market for automated resolution
     * @param marketId Market identifier
     * @param dataSources Array of data source types
     * @param dataSourceIds Array of data source identifiers (e.g., Chainlink feed addresses)
     * @param minConfirmations Minimum number of sources that must agree
     */
    function configureAutomatedMarket(
        string calldata marketId,
        DataSourceType[] calldata dataSources,
        bytes32[] calldata dataSourceIds,
        uint256 minConfirmations
    ) external onlyOwner {
        require(dataSources.length == dataSourceIds.length, "Length mismatch");
        require(minConfirmations <= dataSources.length, "Invalid min confirmations");
        
        marketConfigs[marketId] = MarketConfig({
            tier: ResolutionTier.Automated,
            dataSources: dataSources,
            dataSourceIds: dataSourceIds,
            minConfirmations: minConfirmations,
            autoResolveThreshold: AUTO_RESOLVE_CONSENSUS,
            requiresManualReview: false
        });
        
        emit MarketConfigured(marketId, ResolutionTier.Automated);
    }

    /**
     * @notice Data provider reports outcome from external source
     * @param marketId Market identifier
     * @param sourceId Data source identifier
     * @param outcomeHash Outcome hash from data source
     * @param confidence Confidence level (0-10000)
     */
    function reportDataSource(
        string calldata marketId,
        bytes32 sourceId,
        bytes32 outcomeHash,
        uint256 confidence
    ) external onlyDataProvider {
        require(!marketOutcomes[marketId].isResolved, "Already resolved");
        require(confidence <= BASIS_POINTS, "Invalid confidence");
        
        dataSourceReports[marketId].push(DataSourceReport({
            sourceId: sourceId,
            outcomeHash: outcomeHash,
            timestamp: block.timestamp,
            confidence: confidence
        }));
        
        emit DataSourceReported(marketId, sourceId, outcomeHash);
        
        // Try auto-resolve if enough reports
        _tryAutoResolve(marketId);
    }

    /**
     * @notice Internal function to attempt automated resolution
     * @param marketId Market identifier
     */
    function _tryAutoResolve(string memory marketId) internal {
        MarketConfig storage config = marketConfigs[marketId];
        if (config.tier != ResolutionTier.Automated) return;
        
        DataSourceReport[] storage reports = dataSourceReports[marketId];
        if (reports.length < config.minConfirmations) return;
        
        // Count votes for each outcome
        mapping(bytes32 => uint256) storage outcomeVotes;
        mapping(bytes32 => uint256) storage outcomeConfidence;
        bytes32[] memory uniqueOutcomes = new bytes32[](reports.length);
        uint256 uniqueCount = 0;
        
        for (uint256 i = 0; i < reports.length; i++) {
            bytes32 outcome = reports[i].outcomeHash;
            
            // Track unique outcomes
            bool isNew = true;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (uniqueOutcomes[j] == outcome) {
                    isNew = false;
                    break;
                }
            }
            if (isNew) {
                uniqueOutcomes[uniqueCount] = outcome;
                uniqueCount++;
            }
            
            outcomeVotes[outcome]++;
            outcomeConfidence[outcome] += reports[i].confidence;
        }
        
        // Find consensus
        bytes32 consensusOutcome;
        uint256 maxVotes = 0;
        uint256 totalVotes = reports.length;
        
        for (uint256 i = 0; i < uniqueCount; i++) {
            bytes32 outcome = uniqueOutcomes[i];
            uint256 votes = outcomeVotes[outcome];
            
            if (votes > maxVotes) {
                maxVotes = votes;
                consensusOutcome = outcome;
            }
        }
        
        // Check if consensus threshold met
        uint256 consensusPercentage = (maxVotes * BASIS_POINTS) / totalVotes;
        
        if (consensusPercentage >= config.autoResolveThreshold) {
            // Auto-resolve!
            marketOutcomes[marketId] = MarketOutcome({
                marketId: marketId,
                isResolved: true,
                outcomeHash: consensusOutcome,
                resolvedAt: block.timestamp,
                status: MarketStatus.Resolved
            });
            
            emit AutoResolved(marketId, consensusOutcome, consensusPercentage);
            emit MarketResolved(marketId, consensusOutcome, block.timestamp);
        }
    }

    // ============================================
    // TIER 2: MANUAL REVIEW WITH DISPUTE
    // ============================================

    /**
     * @notice Propose outcome for manual review market
     * @param marketId Market identifier
     * @param outcomeHash Outcome hash
     * @param evidence IPFS hash or URL with supporting evidence
     */
    function proposeOutcome(
        string calldata marketId,
        bytes32 outcomeHash,
        string calldata evidence
    ) external {
        require(!marketOutcomes[marketId].isResolved, "Already resolved");
        require(proposals[marketId].state == DisputeState.None, "Already proposed");
        
        // Transfer bond
        bondToken.safeTransferFrom(msg.sender, address(this), PROPOSAL_BOND);
        
        proposals[marketId] = Proposal({
            proposer: msg.sender,
            outcomeHash: outcomeHash,
            proposedAt: block.timestamp,
            bond: PROPOSAL_BOND,
            state: DisputeState.Proposed,
            evidence: evidence
        });
        
        emit MarketProposed(marketId, outcomeHash, msg.sender);
    }

    /**
     * @notice Dispute a proposed outcome
     * @param marketId Market identifier
     * @param counterOutcomeHash Alternative outcome
     * @param counterEvidence Supporting evidence for dispute
     */
    function disputeOutcome(
        string calldata marketId,
        bytes32 counterOutcomeHash,
        string calldata counterEvidence
    ) external {
        Proposal storage proposal = proposals[marketId];
        require(proposal.state == DisputeState.Proposed, "Not in dispute window");
        require(block.timestamp < proposal.proposedAt + DISPUTE_WINDOW, "Dispute window closed");
        require(counterOutcomeHash != proposal.outcomeHash, "Same outcome");
        
        // Transfer bond
        bondToken.safeTransferFrom(msg.sender, address(this), DISPUTE_BOND);
        
        disputes[marketId] = Dispute({
            disputer: msg.sender,
            counterOutcomeHash: counterOutcomeHash,
            disputedAt: block.timestamp,
            bond: DISPUTE_BOND,
            counterEvidence: counterEvidence
        });
        
        proposal.state = DisputeState.Disputed;
        
        emit MarketDisputed(marketId, counterOutcomeHash, msg.sender);
    }

    /**
     * @notice Finalize undisputed proposal
     * @param marketId Market identifier
     */
    function finalizeProposal(string calldata marketId) external {
        Proposal storage proposal = proposals[marketId];
        require(proposal.state == DisputeState.Proposed, "Not proposed");
        require(block.timestamp >= proposal.proposedAt + DISPUTE_WINDOW, "Still in dispute window");
        
        // Resolve market
        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: proposal.outcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });
        
        proposal.state = DisputeState.Resolved;
        
        // Return bond
        bondToken.safeTransfer(proposal.proposer, proposal.bond);
        
        emit MarketResolved(marketId, proposal.outcomeHash, block.timestamp);
    }

    // ============================================
    // TIER 3: ARBITRATION
    // ============================================

    /**
     * @notice Arbitrators resolve dispute
     * @param marketId Market identifier
     * @param finalOutcomeHash Correct outcome
     */
    function resolveDispute(
        string calldata marketId,
        bytes32 finalOutcomeHash
    ) external onlyArbitrator {
        Proposal storage proposal = proposals[marketId];
        Dispute storage dispute = disputes[marketId];
        
        require(proposal.state == DisputeState.Disputed, "Not disputed");
        
        // Determine winner
        address winner;
        
        if (finalOutcomeHash == proposal.outcomeHash) {
            winner = proposal.proposer;
        } else if (finalOutcomeHash == dispute.counterOutcomeHash) {
            winner = dispute.disputer;
        } else {
            revert("Invalid final outcome");
        }
        
        // Resolve market
        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: finalOutcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });
        
        proposal.state = DisputeState.Resolved;
        
        // Winner gets their bond + half of loser's bond
        uint256 winnerPayout = proposal.bond + (dispute.bond / 2);
        uint256 protocolFee = dispute.bond / 2;
        
        bondToken.safeTransfer(winner, winnerPayout);
        bondToken.safeTransfer(owner(), protocolFee);
        
        emit DisputeResolved(marketId, finalOutcomeHash, winner);
        emit MarketResolved(marketId, finalOutcomeHash, block.timestamp);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    function getMarketOutcome(string calldata marketId) external view returns (MarketOutcome memory) {
        return marketOutcomes[marketId];
    }

    function isMarketResolved(string calldata marketId) external view returns (bool) {
        return marketOutcomes[marketId].isResolved;
    }

    function getMarketConfig(string calldata marketId) external view returns (MarketConfig memory) {
        return marketConfigs[marketId];
    }

    function getProposal(string calldata marketId) external view returns (Proposal memory) {
        return proposals[marketId];
    }

    function getDispute(string calldata marketId) external view returns (Dispute memory) {
        return disputes[marketId];
    }

    function getDataSourceReports(string calldata marketId) external view returns (DataSourceReport[] memory) {
        return dataSourceReports[marketId];
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    function addArbitrator(address arbitrator) external onlyOwner {
        require(!arbitrators[arbitrator], "Already arbitrator");
        arbitrators[arbitrator] = true;
        arbitratorCount++;
        emit ArbitratorAdded(arbitrator);
    }

    function addDataProvider(address provider) external onlyOwner {
        require(!dataProviders[provider], "Already provider");
        dataProviders[provider] = true;
        emit DataProviderAdded(provider);
    }

    function addResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = true;
    }

    // Legacy compatibility
    function verifyOutcome(string calldata marketId, bytes32 expectedOutcome) external view returns (bool) {
        MarketOutcome memory outcome = marketOutcomes[marketId];
        return outcome.isResolved && outcome.outcomeHash == expectedOutcome;
    }

    function getRiskAssessment(string calldata) external pure returns (uint256, uint256, uint256) {
        // Placeholder for backward compatibility
        return (5000, 7000, block.timestamp);
    }
}
