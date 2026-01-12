const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PortView (PV)", function () {
  it("deploys full portfolio kernel", async function () {
    const [admin] = await ethers.getSigners();
    const maxPayment = ethers.parseUnits("1000", 18);

    const PortView = await ethers.getContractFactory("PortView");
    const pv = await PortView.deploy(admin.address, maxPayment);
    await pv.waitForDeployment();

    const vault = await ethers.getContractAt(
      "TreasuryVault",
      await pv.vault()
    );

    // ✅ ADMIN explicitly authorizes scheduler
    await vault
      .connect(admin)
      .authorizeScheduler(await pv.scheduler(), true);

    expect(await pv.policy()).to.not.equal(ethers.ZeroAddress);
    expect(await pv.vault()).to.not.equal(ethers.ZeroAddress);
    expect(await pv.scheduler()).to.not.equal(ethers.ZeroAddress);
  });
});
