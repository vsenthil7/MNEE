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