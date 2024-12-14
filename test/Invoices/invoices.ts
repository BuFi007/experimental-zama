import { expect } from "chai";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";

import { deployConfidentialERC20Fixture } from "../confidentialERC20/ConfidentialERC20.fixture";
import { createInstance } from "../instance";
import { reencryptEuint64 } from "../reencrypt";
import { getSigners, initSigners } from "../signers";
import { debug } from "../utils";
import { deployConfidentialPaymentsFixture } from "./invoices.fixture";

describe("ConfidentialPayments", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    ///
    const contract = await deployConfidentialPaymentsFixture();
    this.payments = contract;
    this.paymentsContractAddress = await contract.getAddress();

    const erc20Contract = await deployConfidentialERC20Fixture();
    this.erc20ContractAddress = await erc20Contract.getAddress();
    this.erc20 = erc20Contract;

    this.fhevm = await createInstance();
  });

  it.only("should store a new payment successfully", async function () {
    // Create encrypted amount
    const transaction = await this.erc20.mint(this.signers.alice, 1000);
    await transaction.wait();

    // Reencrypt Alice's balance
    const balanceHandleAlice = await this.erc20.balanceOf(this.signers.alice);
    const balanceAlice = await reencryptEuint64(
      this.signers.alice,
      this.fhevm,
      balanceHandleAlice,
      this.erc20ContractAddress,
    );
    console.log("balanceAlice", balanceAlice);

    const input = this.fhevm.createEncryptedInput(this.erc20ContractAddress, this.signers.alice.address);
    input.add64(1337);
    const encryptedTransferAmount = await input.encrypt();
    const tx = await this.erc20["transfer(address,bytes32,bytes)"](
      this.signers.bob,
      encryptedTransferAmount.handles[0],
      encryptedTransferAmount.inputProof,
    );
    const t2 = await tx.wait();

    expect(t2?.status).to.eq(1);
  });

  it.only("should store a new payment successfully", async function () {
    const transaction = await this.erc20.mint(this.signers.alice, 10000);
    await transaction.wait();
    const inputAlice = this.fhevm.createEncryptedInput(this.erc20ContractAddress, this.signers.alice.address);
    inputAlice.add64(1337);
    const encryptedAllowanceAmount = await inputAlice.encrypt();
    const tx = await this.erc20["approve(address,bytes32,bytes)"](
      this.paymentsContractAddress,
      encryptedAllowanceAmount.handles[0],
      encryptedAllowanceAmount.inputProof,
    );
    await tx.wait();

    const inputPayment = this.fhevm.createEncryptedInput(this.paymentsContractAddress, this.signers.alice.address);
    inputPayment.add64(1337);
    const encryptedPaymentAmount = await inputPayment.encrypt();

    await expect(
      this.payments
        .connect(this.signers.alice)
        .storePayment(
          this.erc20ContractAddress,
          "paymentHash",
          encryptedPaymentAmount.handles[0],
          encryptedPaymentAmount.inputProof,
          this.signers.bob.address,
        ),
    )
      .to.emit(this.payments, "PaymentStored")
      .withArgs("paymentHash");
  });

  it.only("should store claim a payment successfully", async function () {
    const transaction = await this.erc20.mint(this.signers.alice, 10000);
    await transaction.wait();
    const inputAlice = this.fhevm.createEncryptedInput(this.erc20ContractAddress, this.signers.alice.address);
    inputAlice.add64(1337);
    const encryptedAllowanceAmount = await inputAlice.encrypt();
    const tx = await this.erc20["approve(address,bytes32,bytes)"](
      this.paymentsContractAddress,
      encryptedAllowanceAmount.handles[0],
      encryptedAllowanceAmount.inputProof,
    );
    await tx.wait();

    const inputPayment = this.fhevm.createEncryptedInput(this.paymentsContractAddress, this.signers.alice.address);
    inputPayment.add64(1337);
    const encryptedPaymentAmount = await inputPayment.encrypt();

    await expect(
      this.payments
        .connect(this.signers.alice)
        .storePayment(
          this.erc20ContractAddress,
          "paymentHash",
          encryptedPaymentAmount.handles[0],
          encryptedPaymentAmount.inputProof,
          this.signers.bob.address,
        ),
    )
      .to.emit(this.payments, "PaymentStored")
      .withArgs("paymentHash");

    await expect(this.payments.connect(this.signers.bob).claimPayment("paymentHash")).to.emit(
      this.payments,
      "PaymentProcessed",
    );
  });

  it.only("should store claim a payment successfully", async function () {
    const transaction = await this.erc20.mint(this.signers.alice, 10000);
    await transaction.wait();
    const inputAlice = this.fhevm.createEncryptedInput(this.erc20ContractAddress, this.signers.alice.address);
    inputAlice.add64(1337);
    const encryptedAllowanceAmount = await inputAlice.encrypt();
    const tx = await this.erc20["approve(address,bytes32,bytes)"](
      this.paymentsContractAddress,
      encryptedAllowanceAmount.handles[0],
      encryptedAllowanceAmount.inputProof,
    );
    await tx.wait();

    const inputPayment = this.fhevm.createEncryptedInput(this.paymentsContractAddress, this.signers.bob.address);
    inputPayment.add64(1337);
    const encryptedPaymentAmount = await inputPayment.encrypt();

    await expect(
      this.payments
        .connect(this.signers.bob)
        .requestPayment(
          this.erc20ContractAddress,
          "paymentHash",
          encryptedPaymentAmount.handles[0],
          encryptedPaymentAmount.inputProof,
          this.signers.alice.address,
        ),
    )
      .to.emit(this.payments, "PaymentRequestStored")
      .withArgs("paymentHash");

    await expect(this.payments.connect(this.signers.alice).payRequest("paymentHash")).to.emit(
      this.payments,
      "PaymentProcessed",
    );
  });
});
