import { ethers } from "hardhat";

export async function deployConfidentialPaymentsFixture() {
  const factory = await ethers.getContractFactory("ConfidentialPayments");
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  return contract;
}
