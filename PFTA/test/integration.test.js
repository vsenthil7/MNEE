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