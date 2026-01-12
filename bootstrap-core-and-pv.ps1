Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== MNEE CORE + PRODUCT-4 BOOTSTRAP ==="

# ---------- Paths ----------
$ROOT = Get-Location
$CORE = Join-Path $ROOT "core"
$PFTA = Join-Path $ROOT "PFTA"
$PV   = Join-Path $ROOT "PV"

# ---------- Sanity ----------
if (!(Test-Path $PFTA)) { throw "PFTA not found. Abort." }

# ---------- Core structure ----------
New-Item -Force -ItemType Directory $CORE\solidity | Out-Null
New-Item -Force -ItemType Directory $CORE\js | Out-Null
New-Item -Force -ItemType Directory $CORE\policy | Out-Null
New-Item -Force -ItemType Directory $CORE\schemas | Out-Null

@"
# MNEE Core Kernel

Shared, deterministic, policy-gated primitives.
Used by all products. No product logic here.
"@ | Set-Content $CORE\README.md -Encoding UTF8

# ---------- Extract generic Solidity (COPY, do not remove) ----------
$GENERIC = @(
  "TreasuryVault.sol",
  "PolicyEngine.sol",
  "PaymentScheduler.sol",
  "interfaces"
)

foreach ($item in $GENERIC) {
  Copy-Item `
    -Recurse `
    -Force `
    (Join-Path $PFTA "contracts\$item") `
    (Join-Path $CORE "solidity\$item")
}

# ---------- Product-4 (PortView / PV) ----------
New-Item -Force -ItemType Directory $PV\contracts | Out-Null
New-Item -Force -ItemType Directory $PV\scripts | Out-Null
New-Item -Force -ItemType Directory $PV\test | Out-Null

@"
# PortView (PV)

Portfolio-level orchestration built on MNEE Core.
"@ | Set-Content $PV\README.md -Encoding UTF8

# ---------- PortView contract ----------
@"
pragma solidity ^0.8.20;

import "../core/solidity/TreasuryVault.sol";
import "../core/solidity/PolicyEngine.sol";
import "../core/solidity/PaymentScheduler.sol";

contract PortView {
    TreasuryVault public vault;
    PolicyEngine public policy;
    PaymentScheduler public scheduler;

    constructor(
        address admin,
        uint256 maxPayment
    ) {
        policy = new PolicyEngine(admin, maxPayment);
        vault = new TreasuryVault(admin);
        scheduler = new PaymentScheduler(
            address(vault),
            address(policy)
        );
        vault.authorizeScheduler(address(scheduler), true);
    }
}
"@ | Set-Content $PV\contracts\PortView.sol -Encoding UTF8

# ---------- Hardhat config ----------
@"
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
};
"@ | Set-Content $PV\hardhat.config.js -Encoding UTF8

# ---------- Automation test ----------
@"
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PortView (PV)", function () {
  it("deploys full portfolio kernel", async function () {
    const [admin] = await ethers.getSigners();
    const PV = await ethers.getContractFactory("PortView");
    const pv = await PV.deploy(admin.address, ethers.parseUnits("1000",18));
    await pv.waitForDeployment();
    expect(await pv.policy()).to.not.equal(ethers.ZeroAddress);
  });
});
"@ | Set-Content $PV\test\portview.test.js -Encoding UTF8

# ---------- Build + Test ----------
Push-Location $PFTA
npm test
Pop-Location

Push-Location $PV
npm install --silent
npx hardhat test
Pop-Location

Write-Host "=== DONE: Core extracted + Product-4 PortView ready ==="
