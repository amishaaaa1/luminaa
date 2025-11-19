// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GaslessRelay
 * @notice Meta-transaction relay for gasless insurance claims
 * @dev Users sign messages off-chain, relayer submits on-chain
 * 
 * SOLVES YZi Labs Theme: "Prediction markets feel like DeFi dApps: complex wallets, 
 * bridging, and gas. Make them feel like normal apps."
 * 
 * HOW IT WORKS:
 * 1. User signs claim intent off-chain (no gas needed)
 * 2. Relayer submits transaction on-chain (pays gas)
 * 3. User gets payout directly to wallet
 * 4. Relayer gets reimbursed from protocol fees
 * 
 * BENEFITS:
 * - No BNB needed for gas
 * - Better UX for mainstream users
 * - Claims feel instant
 */
contract GaslessRelay is Ownable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    struct ClaimRequest {
        address user;
        uint256 policyId;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => uint256) public nonces;
    mapping(address => bool) public authorizedRelayers;
    
    address public policyManager;
    IERC20 public reimbursementToken;
    uint256 public relayerReward = 1e18; // 1 USDT per relay

    event ClaimRelayed(
        address indexed user,
        uint256 indexed policyId,
        address relayer,
        uint256 gasUsed
    );
    event RelayerAuthorized(address relayer);
    event RelayerRevoked(address relayer);

    modifier onlyRelayer() {
        require(authorizedRelayers[msg.sender] || msg.sender == owner(), "Not relayer");
        _;
    }

    constructor(
        address _policyManager,
        address _reimbursementToken
    ) Ownable(msg.sender) {
        require(_policyManager != address(0), "Invalid policy manager");
        require(_reimbursementToken != address(0), "Invalid token");
        
        policyManager = _policyManager;
        reimbursementToken = IERC20(_reimbursementToken);
        authorizedRelayers[msg.sender] = true;
    }

    /**
     * @notice Relay gasless claim
     * @param request Claim request struct
     * @param signature User's signature
     */
    function relayClaim(
        ClaimRequest calldata request,
        bytes calldata signature
    ) external onlyRelayer returns (uint256 payout) {
        uint256 gasStart = gasleft();

        // Verify signature
        bytes32 digest = _getClaimDigest(request);
        address signer = digest.recover(signature);
        require(signer == request.user, "Invalid signature");

        // Check nonce and deadline
        require(nonces[request.user] == request.nonce, "Invalid nonce");
        require(block.timestamp <= request.deadline, "Signature expired");

        // Increment nonce
        nonces[request.user]++;

        // Execute claim on PolicyManager
        // Note: PolicyManager needs to trust this contract
        (bool success, bytes memory data) = policyManager.call(
            abi.encodeWithSignature(
                "claimPolicy(uint256)",
                request.policyId
            )
        );
        require(success, "Claim failed");
        payout = abi.decode(data, (uint256));

        // Reimburse relayer
        uint256 gasUsed = gasStart - gasleft();
        uint256 reimbursement = relayerReward;
        
        if (reimbursement > 0) {
            reimbursementToken.safeTransfer(msg.sender, reimbursement);
        }

        emit ClaimRelayed(request.user, request.policyId, msg.sender, gasUsed);
    }

    /**
     * @notice Get claim digest for signing
     * @param request Claim request
     * @return bytes32 Digest to sign
     */
    function _getClaimDigest(ClaimRequest calldata request) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                _getDomainSeparator(),
                keccak256(
                    abi.encode(
                        keccak256("ClaimRequest(address user,uint256 policyId,uint256 nonce,uint256 deadline)"),
                        request.user,
                        request.policyId,
                        request.nonce,
                        request.deadline
                    )
                )
            )
        );
    }

    /**
     * @notice Get EIP-712 domain separator
     */
    function _getDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LuminaGaslessRelay"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Authorize relayer
     * @param relayer Address to authorize
     */
    function authorizeRelayer(address relayer) external onlyOwner {
        require(relayer != address(0), "Invalid relayer");
        authorizedRelayers[relayer] = true;
        emit RelayerAuthorized(relayer);
    }

    /**
     * @notice Revoke relayer
     * @param relayer Address to revoke
     */
    function revokeRelayer(address relayer) external onlyOwner {
        authorizedRelayers[relayer] = false;
        emit RelayerRevoked(relayer);
    }

    /**
     * @notice Update relayer reward
     * @param newReward New reward amount
     */
    function updateRelayerReward(uint256 newReward) external onlyOwner {
        relayerReward = newReward;
    }

    /**
     * @notice Fund relay contract
     * @param amount Amount to fund
     */
    function fundRelay(uint256 amount) external {
        reimbursementToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Withdraw funds
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        reimbursementToken.safeTransfer(owner(), amount);
    }
}
