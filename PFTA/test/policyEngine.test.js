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