import { expect } from "chai";
import { ethers } from "hardhat";

import { createInstance } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployPeanutConfidentialPaymentsFixture } from "./invoices.fixture";

describe("ConfidentialPayments", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deployPeanutConfidentialPaymentsFixture();
    this.contractAddress = await contract.getAddress();
    this.contractAddress = ethers.getAddress(this.contractAddress);
    this.payments = contract;
    this.fhevm = await createInstance();
  });

  const paymentHash = ethers.keccak256(ethers.toUtf8Bytes("test-payment"));

  it.only("should store a new payment successfully", async function () {
    // Create encrypted amount
    const alicePayments = this.payments.connect(this.signers.alice);

    const amountInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
    amountInput.add64(1000);
    amountInput.add4(1);
    const encryptedAmount = await amountInput.encrypt();

    await expect(
      this.payments.storePayment(
        paymentHash,
        encryptedAmount.handles[0],
        encryptedAmount.handles[1],
        encryptedAmount.inputProof,
        this.signers.alice.address,
        this.signers.bob.address,
      ),
    )
      .to.emit(this.payments, "PaymentStored")
      .withArgs(paymentHash);
  });

  //   it("should not allow storing duplicate payments", async function () {
  //     // Create encrypted amount
  //     const alicePayments = this.payments.connect(this.signers.alice);

  //     const amountInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
  //     amountInput.add64(1000);
  //     amountInput.add4(1);
  //     const encryptedAmount = await amountInput.encrypt();

  //     // const paymentHash = ethers.keccak256(ethers.toUtf8Bytes("test-payment"));

  //     this.payments.storePayment(
  //       paymentHash,
  //       encryptedAmount.handles[0],
  //       encryptedAmount.handles[1],
  //       encryptedAmount.inputProof,
  //       this.signers.alice.address,
  //       this.signers.bob.address,
  //     ),
  //       // Store payment
  //       await expect(
  //         this.payments.storePayment(
  //           paymentHash,
  //           encryptedAmount.handles[0],
  //           encryptedAmount.handles[1],
  //           encryptedAmount.inputProof,
  //           this.signers.alice.address,
  //           this.signers.bob.address,
  //         ),
  //       ).to.be.revertedWith("Payment already exists");
  //   });

  //   it("should process payment correctly", async function () {
  //     const alicePayments = this.payments.connect(this.signers.alice);

  //     const amountInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
  //     amountInput.add64(1000);
  //     const encryptedAmount = await amountInput.encrypt();

  //     const typeInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
  //     typeInput.add4(1);
  //     const encryptedType = await typeInput.encrypt();

  //     const paymentHash = ethers.keccak256(ethers.toUtf8Bytes("test-payment"));

  //     await this.payments.storePayment(
  //       paymentHash,
  //       encryptedAmount.handles[0],
  //       encryptedType.handles[0],
  //       encryptedAmount.inputProof,
  //       encryptedType.inputProof,
  //       this.signers.alice.address,
  //       this.signers.bob.address,
  //     );

  //     // Process payment
  //     await expect(this.payments.processPayment(paymentHash))
  //       .to.emit(this.payments, "PaymentProcessed")
  //       .withArgs(paymentHash);

  //     // Try to process again
  //     await expect(this.payments.processPayment(paymentHash)).to.be.revertedWith("Payment already processed");
  //   });

  //   it("should only allow sender/receiver to access payment details", async function () {
  //     // Store payment
  //     const alicePayments = this.payments.connect(this.signers.alice);
  //     const amountInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
  //     amountInput.add64(1000);
  //     const encryptedAmount = await amountInput.encrypt();

  //     const typeInput = this.fhevm.createEncryptedInput(this.contractAddress, this.signers.alice.address);
  //     typeInput.add4(1);
  //     const encryptedType = await typeInput.encrypt();

  //     const paymentHash = ethers.keccak256(ethers.toUtf8Bytes("test-payment"));
  //     this.signers.alice.address = ethers.getAddress(this.signers.alice.address);
  //     this.signers.bob.address = ethers.getAddress(this.signers.bob.address);

  //     await this.payments.storePayment(
  //       paymentHash,
  //       encryptedAmount.handles[0],
  //       encryptedType.handles[0],
  //       encryptedAmount.inputProof,
  //       encryptedType.inputProof,
  //       this.signers.alice.address,
  //       this.signers.bob.address,
  //     );

  //     // Connect as unauthorized user and try to access details
  //     const carolPayments = this.payments.connect(this.signers.carol);
  //     await expect(carolPayments.getInvoiceAmount(paymentHash)).to.be.revertedWith(
  //       "You are not the sender or receiver of this invoice",
  //     );
  //     await expect(carolPayments.getInvoiceType(paymentHash)).to.be.revertedWith(
  //       "You are not the sender or receiver of this invoice",
  //     );
  //   });
});
