// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPaymentScheduler {
    function schedulePayment(address token, address to, uint256 amount, uint256 executeAfter) external returns (uint256);
    function executePayment(uint256 paymentId) external;
}