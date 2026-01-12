// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITreasuryVault.sol";
import "./interfaces/IPolicyEngine.sol";
import "./interfaces/IPaymentScheduler.sol";

contract PaymentScheduler is IPaymentScheduler {
    struct Payment {
        address token;
        address to;
        uint256 amount;
        uint256 executeAfter;
        bool executed;
    }

    ITreasuryVault public vault;
    IPolicyEngine public policy;
    Payment[] public payments;

    error InvalidAddress();
    error InvalidAmount();
    error NotDueYet();
    error AlreadyExecuted();
    error InvalidPaymentId();

    event PaymentScheduled(uint256 indexed paymentId, address indexed token, address indexed to, uint256 amount, uint256 executeAfter);
    event PaymentExecuted(uint256 indexed paymentId);

    constructor(address vault_, address policy_) {
        if (vault_ == address(0) || policy_ == address(0)) revert InvalidAddress();
        vault = ITreasuryVault(vault_);
        policy = IPolicyEngine(policy_);
    }

    function schedulePayment(address token, address to, uint256 amount, uint256 executeAfter) external override returns (uint256) {
        if (token == address(0) || to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        payments.push(Payment({
            token: token,
            to: to,
            amount: amount,
            executeAfter: executeAfter,
            executed: false
        }));

        uint256 paymentId = payments.length - 1;
        emit PaymentScheduled(paymentId, token, to, amount, executeAfter);
        return paymentId;
    }

    function executePayment(uint256 paymentId) external override {
        if (paymentId >= payments.length) revert InvalidPaymentId();

        Payment storage p = payments[paymentId];
        if (p.executed) revert AlreadyExecuted();
        if (block.timestamp < p.executeAfter) revert NotDueYet();

        // policy.validatePayment reverts on failure, returns true on success
        policy.validatePayment(p.token, p.amount, p.to);

        vault.release(p.token, p.to, p.amount);
        p.executed = true;

        emit PaymentExecuted(paymentId);
    }

    function paymentsCount() external view returns (uint256) {
        return payments.length;
    }
}