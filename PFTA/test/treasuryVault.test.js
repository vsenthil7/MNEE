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