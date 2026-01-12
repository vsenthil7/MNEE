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