// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPolicyEngine.sol";

contract PolicyEngine is IPolicyEngine {
    address public admin;
    uint256 public override maxPaymentAmount;

    error NotAdmin();
    error InvalidAmount();
    error AmountExceedsMax();

    constructor(address admin_, uint256 maxPaymentAmount_) {
        admin = admin_;
        maxPaymentAmount = maxPaymentAmount_;
    }

    function setMaxPaymentAmount(uint256 newMax) external {
        if (msg.sender != admin) revert NotAdmin();
        if (newMax == 0) revert InvalidAmount();
        maxPaymentAmount = newMax;
    }

    function validatePayment(address /*token*/, uint256 amount, address recipient) external view override returns (bool) {
        if (recipient == address(0)) revert();
        if (amount == 0) revert InvalidAmount();
        if (amount > maxPaymentAmount) revert AmountExceedsMax();
        return true;
    }
}