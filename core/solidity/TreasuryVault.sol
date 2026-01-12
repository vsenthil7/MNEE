// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasuryVault.sol";

contract TreasuryVault is ITreasuryVault {
    address public admin;
    mapping(address => bool) public authorizedSchedulers;

    error NotAdmin();
    error NotAuthorizedScheduler();
    error InvalidAddress();
    error InvalidAmount();
    error TransferFailed();

    constructor(address admin_) {
        if (admin_ == address(0)) revert InvalidAddress();
        admin = admin_;
    }

    function authorizeScheduler(address scheduler, bool allowed) external override {
        if (msg.sender != admin) revert NotAdmin();
        if (scheduler == address(0)) revert InvalidAddress();
        authorizedSchedulers[scheduler] = allowed;
    }

    function deposit(address token, uint256 amount) external override {
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    function release(address token, address to, uint256 amount) external override {
        if (!authorizedSchedulers[msg.sender]) revert NotAuthorizedScheduler();
        if (token == address(0) || to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }

    function getBalance(address token) external view override returns (uint256) {
        if (token == address(0)) revert InvalidAddress();
        return IERC20(token).balanceOf(address(this));
    }
}