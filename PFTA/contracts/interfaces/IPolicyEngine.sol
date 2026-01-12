// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPolicyEngine {
    function validatePayment(address token, uint256 amount, address recipient) external view returns (bool);
    function maxPaymentAmount() external view returns (uint256);
}