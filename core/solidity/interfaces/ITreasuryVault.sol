// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasuryVault {
    function deposit(address token, uint256 amount) external;
    function release(address token, address to, uint256 amount) external;
    function getBalance(address token) external view returns (uint256);
    function authorizeScheduler(address scheduler, bool allowed) external;
}