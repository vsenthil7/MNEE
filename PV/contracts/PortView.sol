// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./core/TreasuryVault.sol";
import "./core/PolicyEngine.sol";
import "./core/PaymentScheduler.sol";

contract PortView {
    TreasuryVault public vault;
    PolicyEngine public policy;
    PaymentScheduler public scheduler;
    address public admin;

    constructor(address _admin, uint256 maxPayment) {
        admin = _admin;
        policy = new PolicyEngine(_admin, maxPayment);
        vault = new TreasuryVault(_admin);
        scheduler = new PaymentScheduler(
            address(vault),
            address(policy)
        );
    }
}
