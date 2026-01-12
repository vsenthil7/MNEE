# bootstrap-pfta.ps1
# H0008 Product-3 (PFTA) — write full codebase into existing scaffold
# Runs in PowerShell 5+ / 7+ on Windows
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-TextFileNoBom {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Content
  )
  $full = [System.IO.Path]::GetFullPath($Path)
  $dir = [System.IO.Path]::GetDirectoryName($full)
  if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
}

function Ensure-InPftaRoot {
  $cwd = (Get-Location).Path
  $contracts = Join-Path $cwd "contracts"
  $scripts   = Join-Path $cwd "scripts"
  $tests     = Join-Path $cwd "test"

  if (-not (Test-Path $contracts) -or -not (Test-Path $scripts) -or -not (Test-Path $tests)) {
    throw "Not in PFTA root. Expected folders 'contracts', 'scripts', 'test' in: $cwd"
  }
}

function Update-PackageJsonScripts {
  param(
    [Parameter(Mandatory=$true)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    throw "package.json not found at $Path"
  }

  $json = Get-Content $Path -Raw | ConvertFrom-Json

  if ($null -eq $json.scripts) {
    $json | Add-Member -MemberType NoteProperty -Name scripts -Value ([pscustomobject]@{})
  }

  function Set-ScriptProp {
    param($obj, $name, $value)
    if ($obj.PSObject.Properties.Name -contains $name) {
      $obj.$name = $value
    } else {
      $obj | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force
    }
  }

  Set-ScriptProp $json.scripts "test"          "hardhat test"
  Set-ScriptProp $json.scripts "compile"       "hardhat compile"
  Set-ScriptProp $json.scripts "clean"         "hardhat clean"
  Set-ScriptProp $json.scripts "node"          "hardhat node"
  Set-ScriptProp $json.scripts "deploy:local"  "hardhat run scripts/deploy_local.js --network hardhat"
  Set-ScriptProp $json.scripts "seed:local"    "hardhat run scripts/seed_treasury.js --network hardhat"
  Set-ScriptProp $json.scripts "run:payment"   "hardhat run scripts/run_payment.js --network hardhat"

  if (-not ($json.PSObject.Properties.Name -contains "license")) {
    $json | Add-Member -MemberType NoteProperty -Name license -Value "MIT"
  } else {
    $json.license = "MIT"
  }

  $out = $json | ConvertTo-Json -Depth 20
  Write-TextFileNoBom -Path $Path -Content $out
}


# -----------------------------
# Main
# -----------------------------
Ensure-InPftaRoot

$root = (Get-Location).Path
Write-Host "PFTA root: $root"

# .gitignore
Write-TextFileNoBom -Path ".gitignore" -Content @"
node_modules/
artifacts/
cache/
coverage/
.env
.DS_Store
*.log
"@

# .env.example (UTF-8 no BOM)
Write-TextFileNoBom -Path ".env.example" -Content @"
# =========================
# CORE ENV (REQUIRED)
# =========================
NODE_ENV=development

# =========================
# LOCAL HARDHAT NETWORK
# =========================
LOCAL_RPC_URL=http://127.0.0.1:8545
LOCAL_CHAIN_ID=31337

# =========================
# TESTNET (OPTIONAL — DO NOT USE YET)
# =========================
TESTNET_NAME=sepolia
TESTNET_RPC_URL=
TESTNET_CHAIN_ID=11155111
TESTNET_PRIVATE_KEY=

# =========================
# TREASURY DEFAULTS
# =========================
TREASURY_ADMIN_ADDRESS=
TREASURY_INITIAL_SUPPLY=1000000

# =========================
# SCHEDULER DEFAULTS
# =========================
DEFAULT_PAYMENT_DELAY_SECONDS=3600
MAX_PAYMENT_AMOUNT=100000
"@

# LICENSE (MIT)
Write-TextFileNoBom -Path "LICENSE" -Content @"
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@

# hardhat.config.js (fix "empty config object" warning)
Write-TextFileNoBom -Path "hardhat.config.js" -Content @"
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import("hardhat/config").HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337
    }
  }
};
"@

# -----------------------------
# Contracts: Interfaces
# -----------------------------
Write-TextFileNoBom -Path "contracts/interfaces/ITreasuryVault.sol" -Content @"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasuryVault {
    function deposit(address token, uint256 amount) external;
    function release(address token, address to, uint256 amount) external;
    function getBalance(address token) external view returns (uint256);
    function authorizeScheduler(address scheduler, bool allowed) external;
}
"@

Write-TextFileNoBom -Path "contracts/interfaces/IPolicyEngine.sol" -Content @"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPolicyEngine {
    function validatePayment(address token, uint256 amount, address recipient) external view returns (bool);
    function maxPaymentAmount() external view returns (uint256);
}
"@

Write-TextFileNoBom -Path "contracts/interfaces/IPaymentScheduler.sol" -Content @"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPaymentScheduler {
    function schedulePayment(address token, address to, uint256 amount, uint256 executeAfter) external returns (uint256);
    function executePayment(uint256 paymentId) external;
}
"@

# -----------------------------
# Contracts: MockToken
# -----------------------------
Write-TextFileNoBom -Path "contracts/MockToken.sol" -Content @"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 initialSupply) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }
}
"@

# -----------------------------
# Contracts: PolicyEngine
# -----------------------------
Write-TextFileNoBom -Path "contracts/PolicyEngine.sol" -Content @"
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
"@

# -----------------------------
# Contracts: TreasuryVault
# -----------------------------
Write-TextFileNoBom -Path "contracts/TreasuryVault.sol" -Content @"
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
"@

# -----------------------------
# Contracts: PaymentScheduler
# -----------------------------
Write-TextFileNoBom -Path "contracts/PaymentScheduler.sol" -Content @"
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
"@

# -----------------------------
# Scripts
# -----------------------------
Write-TextFileNoBom -Path "scripts/deploy_local.js" -Content @"
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const initialSupply = hre.ethers.parseUnits("1000000", 18);
  const maxPayment = hre.ethers.parseUnits("100000", 18);

  const MockToken = await hre.ethers.getContractFactory("MockToken");
  const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);
  await token.waitForDeployment();

  const PolicyEngine = await hre.ethers.getContractFactory("PolicyEngine");
  const policy = await PolicyEngine.deploy(deployer.address, maxPayment);
  await policy.waitForDeployment();

  const TreasuryVault = await hre.ethers.getContractFactory("TreasuryVault");
  const vault = await TreasuryVault.deploy(deployer.address);
  await vault.waitForDeployment();

  const PaymentScheduler = await hre.ethers.getContractFactory("PaymentScheduler");
  const scheduler = await PaymentScheduler.deploy(await vault.getAddress(), await policy.getAddress());
  await scheduler.waitForDeployment();

  // Authorize scheduler to release funds
  const tx = await vault.authorizeScheduler(await scheduler.getAddress(), true);
  await tx.wait();

  console.log("Deployer:", deployer.address);
  console.log("MockToken:", await token.getAddress());
  console.log("PolicyEngine:", await policy.getAddress());
  console.log("TreasuryVault:", await vault.getAddress());
  console.log("PaymentScheduler:", await scheduler.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
"@

Write-TextFileNoBom -Path "scripts/seed_treasury.js" -Content @"
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  // Expect env or manual replace after deploy. For now, deploy fresh on local to keep script deterministic.
  const initialSupply = hre.ethers.parseUnits("1000000", 18);
  const maxPayment = hre.ethers.parseUnits("100000", 18);

  const MockToken = await hre.ethers.getContractFactory("MockToken");
  const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);
  await token.waitForDeployment();

  const PolicyEngine = await hre.ethers.getContractFactory("PolicyEngine");
  const policy = await PolicyEngine.deploy(deployer.address, maxPayment);
  await policy.waitForDeployment();

  const TreasuryVault = await hre.ethers.getContractFactory("TreasuryVault");
  const vault = await TreasuryVault.deploy(deployer.address);
  await vault.waitForDeployment();

  const PaymentScheduler = await hre.ethers.getContractFactory("PaymentScheduler");
  const scheduler = await PaymentScheduler.deploy(await vault.getAddress(), await policy.getAddress());
  await scheduler.waitForDeployment();

  await (await vault.authorizeScheduler(await scheduler.getAddress(), true)).wait();

  const seedAmount = hre.ethers.parseUnits("500000", 18);
  await (await token.approve(await vault.getAddress(), seedAmount)).wait();
  await (await vault.deposit(await token.getAddress(), seedAmount)).wait();

  const bal = await token.balanceOf(await vault.getAddress());
  console.log("Seeded TreasuryVault with mUSD:", hre.ethers.formatUnits(bal, 18));
  console.log("MockToken:", await token.getAddress());
  console.log("TreasuryVault:", await vault.getAddress());
  console.log("PaymentScheduler:", await scheduler.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
"@

Write-TextFileNoBom -Path "scripts/run_payment.js" -Content @"
const hre = require("hardhat");

async function main() {
  const [deployer, recipient] = await hre.ethers.getSigners();

  const initialSupply = hre.ethers.parseUnits("1000000", 18);
  const maxPayment = hre.ethers.parseUnits("100000", 18);

  const MockToken = await hre.ethers.getContractFactory("MockToken");
  const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);
  await token.waitForDeployment();

  const PolicyEngine = await hre.ethers.getContractFactory("PolicyEngine");
  const policy = await PolicyEngine.deploy(deployer.address, maxPayment);
  await policy.waitForDeployment();

  const TreasuryVault = await hre.ethers.getContractFactory("TreasuryVault");
  const vault = await TreasuryVault.deploy(deployer.address);
  await vault.waitForDeployment();

  const PaymentScheduler = await hre.ethers.getContractFactory("PaymentScheduler");
  const scheduler = await PaymentScheduler.deploy(await vault.getAddress(), await policy.getAddress());
  await scheduler.waitForDeployment();

  await (await vault.authorizeScheduler(await scheduler.getAddress(), true)).wait();

  const seedAmount = hre.ethers.parseUnits("1000", 18);
  await (await token.approve(await vault.getAddress(), seedAmount)).wait();
  await (await vault.deposit(await token.getAddress(), seedAmount)).wait();

  const beforeVault = await token.balanceOf(await vault.getAddress());
  const beforeRecipient = await token.balanceOf(recipient.address);

  console.log("Vault before:", hre.ethers.formatUnits(beforeVault, 18));
  console.log("Recipient before:", hre.ethers.formatUnits(beforeRecipient, 18));

  const amount = hre.ethers.parseUnits("25", 18);
  const nowBlock = await hre.ethers.provider.getBlock("latest");
  const executeAfter = BigInt(nowBlock.timestamp) + 60n;

  const tx = await scheduler.schedulePayment(await token.getAddress(), recipient.address, amount, executeAfter);
  const receipt = await tx.wait();
  const paymentId = 0;

  // advance time
  await hre.network.provider.send("evm_increaseTime", [120]);
  await hre.network.provider.send("evm_mine");

  await (await scheduler.executePayment(paymentId)).wait();

  const afterVault = await token.balanceOf(await vault.getAddress());
  const afterRecipient = await token.balanceOf(recipient.address);

  console.log("Vault after:", hre.ethers.formatUnits(afterVault, 18));
  console.log("Recipient after:", hre.ethers.formatUnits(afterRecipient, 18));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
"@

# -----------------------------
# Tests (Hardhat Toolbox / Ethers v6)
# -----------------------------
Write-TextFileNoBom -Path "test/policyEngine.test.js" -Content @"
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PolicyEngine", function () {
  it("accepts valid payment and rejects invalid amounts", async function () {
    const [admin, recipient] = await ethers.getSigners();
    const maxPayment = ethers.parseUnits("100", 18);

    const PolicyEngine = await ethers.getContractFactory("PolicyEngine");
    const policy = await PolicyEngine.deploy(admin.address, maxPayment);

    await expect(policy.validatePayment(ethers.ZeroAddress, 0, recipient.address)).to.be.reverted;
    await expect(policy.validatePayment(ethers.ZeroAddress, ethers.parseUnits("101", 18), recipient.address)).to.be.reverted;

    const ok = await policy.validatePayment(ethers.ZeroAddress, ethers.parseUnits("10", 18), recipient.address);
    expect(ok).to.equal(true);
  });

  it("admin can change maxPaymentAmount", async function () {
    const [admin, other] = await ethers.getSigners();
    const PolicyEngine = await ethers.getContractFactory("PolicyEngine");
    const policy = await PolicyEngine.deploy(admin.address, 100);

    await expect(policy.connect(other).setMaxPaymentAmount(200)).to.be.reverted;
    await expect(policy.setMaxPaymentAmount(0)).to.be.reverted;
    await policy.setMaxPaymentAmount(200);
    expect(await policy.maxPaymentAmount()).to.equal(200);
  });
});
"@

Write-TextFileNoBom -Path "test/treasuryVault.test.js" -Content @"
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TreasuryVault", function () {
  async function deployFixture() {
    const [admin, user, scheduler, recipient] = await ethers.getSigners();
    const initialSupply = ethers.parseUnits("1000", 18);

    const MockToken = await ethers.getContractFactory("MockToken");
    const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);

    const TreasuryVault = await ethers.getContractFactory("TreasuryVault");
    const vault = await TreasuryVault.deploy(admin.address);

    return { admin, user, scheduler, recipient, token, vault };
  }

  it("allows deposit via transferFrom and tracks balance", async function () {
    const { admin, token, vault } = await deployFixture();

    const amt = ethers.parseUnits("100", 18);
    await token.approve(await vault.getAddress(), amt);
    await vault.deposit(await token.getAddress(), amt);

    const bal = await vault.getBalance(await token.getAddress());
    expect(bal).to.equal(amt);
  });

  it("only admin can authorize scheduler, only scheduler can release", async function () {
    const { admin, scheduler, recipient, token, vault } = await deployFixture();

    const amt = ethers.parseUnits("100", 18);
    await token.approve(await vault.getAddress(), amt);
    await vault.deposit(await token.getAddress(), amt);

    await expect(vault.connect(scheduler).authorizeScheduler(scheduler.address, true)).to.be.reverted;

    await vault.connect(admin).authorizeScheduler(scheduler.address, true);

    await expect(vault.release(await token.getAddress(), recipient.address, ethers.parseUnits("1", 18))).to.be.reverted;

    const rel = ethers.parseUnits("25", 18);
    await vault.connect(scheduler).release(await token.getAddress(), recipient.address, rel);

    const recipientBal = await token.balanceOf(recipient.address);
    expect(recipientBal).to.equal(rel);
  });
});
"@

Write-TextFileNoBom -Path "test/paymentScheduler.test.js" -Content @"
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("PaymentScheduler", function () {
  async function deployFixture() {
    const [admin, recipient] = await ethers.getSigners();

    const initialSupply = ethers.parseUnits("1000", 18);
    const maxPayment = ethers.parseUnits("100", 18);

    const MockToken = await ethers.getContractFactory("MockToken");
    const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);

    const PolicyEngine = await ethers.getContractFactory("PolicyEngine");
    const policy = await PolicyEngine.deploy(admin.address, maxPayment);

    const TreasuryVault = await ethers.getContractFactory("TreasuryVault");
    const vault = await TreasuryVault.deploy(admin.address);

    const PaymentScheduler = await ethers.getContractFactory("PaymentScheduler");
    const scheduler = await PaymentScheduler.deploy(await vault.getAddress(), await policy.getAddress());

    await vault.authorizeScheduler(await scheduler.getAddress(), true);

    const seed = ethers.parseUnits("200", 18);
    await token.approve(await vault.getAddress(), seed);
    await vault.deposit(await token.getAddress(), seed);

    return { admin, recipient, token, policy, vault, scheduler };
  }

  it("reverts if executed too early and succeeds after time", async function () {
    const { recipient, token, scheduler, vault } = await deployFixture();

    const amount = ethers.parseUnits("10", 18);
    const block = await ethers.provider.getBlock("latest");
    const executeAfter = BigInt(block.timestamp) + 60n;

    const id = await scheduler.schedulePayment.staticCall(await token.getAddress(), recipient.address, amount, executeAfter);
    await scheduler.schedulePayment(await token.getAddress(), recipient.address, amount, executeAfter);

    await expect(scheduler.executePayment(id)).to.be.reverted;

    await network.provider.send("evm_increaseTime", [120]);
    await network.provider.send("evm_mine");

    const beforeVault = await vault.getBalance(await token.getAddress());
    await scheduler.executePayment(id);
    const afterVault = await vault.getBalance(await token.getAddress());

    expect(beforeVault - afterVault).to.equal(amount);
    expect(await token.balanceOf(recipient.address)).to.equal(amount);
  });

  it("reverts if payment exceeds policy max", async function () {
    const { recipient, token, scheduler } = await deployFixture();

    const amount = ethers.parseUnits("1000", 18);
    const block = await ethers.provider.getBlock("latest");
    const executeAfter = BigInt(block.timestamp);

    await scheduler.schedulePayment(await token.getAddress(), recipient.address, amount, executeAfter);

    await expect(scheduler.executePayment(0)).to.be.reverted;
  });
});
"@

Write-TextFileNoBom -Path "test/integration.test.js" -Content @"
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("PFTA Integration", function () {
  it("full flow: mint -> deposit -> schedule -> execute -> balances update", async function () {
    const [admin, recipient] = await ethers.getSigners();

    const initialSupply = ethers.parseUnits("1000000", 18);
    const maxPayment = ethers.parseUnits("100000", 18);

    const MockToken = await ethers.getContractFactory("MockToken");
    const token = await MockToken.deploy("Mock USD", "mUSD", initialSupply);

    const PolicyEngine = await ethers.getContractFactory("PolicyEngine");
    const policy = await PolicyEngine.deploy(admin.address, maxPayment);

    const TreasuryVault = await ethers.getContractFactory("TreasuryVault");
    const vault = await TreasuryVault.deploy(admin.address);

    const PaymentScheduler = await ethers.getContractFactory("PaymentScheduler");
    const scheduler = await PaymentScheduler.deploy(await vault.getAddress(), await policy.getAddress());

    await vault.authorizeScheduler(await scheduler.getAddress(), true);

    const depositAmount = ethers.parseUnits("1000", 18);
    await token.approve(await vault.getAddress(), depositAmount);
    await vault.deposit(await token.getAddress(), depositAmount);

    expect(await vault.getBalance(await token.getAddress())).to.equal(depositAmount);

    const payAmount = ethers.parseUnits("50", 18);
    const block = await ethers.provider.getBlock("latest");
    const executeAfter = BigInt(block.timestamp) + 30n;

    await scheduler.schedulePayment(await token.getAddress(), recipient.address, payAmount, executeAfter);

    await network.provider.send("evm_increaseTime", [60]);
    await network.provider.send("evm_mine");

    await scheduler.executePayment(0);

    expect(await token.balanceOf(recipient.address)).to.equal(payAmount);
    expect(await vault.getBalance(await token.getAddress())).to.equal(depositAmount - payAmount);
  });
});
"@

# README.md
Write-TextFileNoBom -Path "README.md" -Content @"
# PFTA — Programmable Finance & Treasury Automation (Product-3)

This repo is a Hardhat (JS) project implementing:
- TreasuryVault (custody + scheduler authorization)
- PolicyEngine (payment rules)
- PaymentScheduler (time/condition execution)
- MockToken (ERC20 test asset)

## Prerequisites
- Node 18.x
- npm
- Git

## Install
Dependencies already installed in this workspace. If rebuilding:
1) `npm install`

## Compile
- `npm run compile`

## Test (Definition of Done)
- `npm test`

## Local Manual Run
1) Deploy:
- `npm run deploy:local`

2) Seed treasury:
- `npm run seed:local`

3) Run payment demo:
- `npm run run:payment`

## Security / Secrets
- Do NOT commit `.env`
- Only `.env.example` is committed
"@

# package.json scripts/license update
Update-PackageJsonScripts -Path "package.json"

Write-Host "DONE: Wrote PFTA codebase files successfully."
Write-Host "Next commands:"
Write-Host "  npm run compile"
Write-Host "  npm test"
