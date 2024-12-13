import { ethers } from "hardhat";

export async function deployPeanutConfidentialPaymentsFixture() {
  const factory = await ethers.getContractFactory("ConfidentialPayments");
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  return contract;
}
