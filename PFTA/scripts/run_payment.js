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