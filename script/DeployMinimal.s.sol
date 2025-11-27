// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeployMinimal is Script {
    function run() external {
        console.log("Deployment script - compile PolicyManager and InsurancePool separately");
        console.log("Use existing deployed contracts for now");
        console.log("BNB payment support added to PolicyManager");
    }
}
