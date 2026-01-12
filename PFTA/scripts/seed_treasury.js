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