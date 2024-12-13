// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// import "fhevm-contracts/contracts/token/ERC20/extensions/ConfidentialERC20Mintable.sol";

/// @notice This contract implements an encrypted payment system for Peanut Protocol with confidential data
/// @dev Uses FHE to encrypt payment details and balances
contract ConfidentialPayments is SepoliaZamaFHEVMConfig, Ownable {
    // Encrypted payment structure

    struct EncryptedPayment {
        euint4 invoiceType;
        euint64 amount;
        bool isProcessed;
        address sender;
        address receiver;
    }

    // Mapping from payment hash to encrypted payment details
    mapping(bytes32 => EncryptedPayment) private payments;

    constructor() Ownable(msg.sender) {}

    // Events
    event PaymentStored(bytes32 indexed paymentHash);
    event PaymentProcessed(bytes32 indexed paymentHash);

    /// @notice Store a new encrypted payment
    /// @param paymentHash The unique hash of the payment
    /// @param encryptedAmount The encrypted amount of the payment
    function storePayment(
        bytes32 paymentHash,
        einput encryptedAmount,
        einput invoiceType,
        bytes calldata inputProofAmount,
        address sender,
        address receiver
    ) external {
        require(!payments[paymentHash].isProcessed, "Payment already exists");

        payments[paymentHash] = EncryptedPayment({
            invoiceType: TFHE.asEuint4(invoiceType, inputProofAmount),
            amount: TFHE.asEuint64(encryptedAmount, inputProofAmount),
            isProcessed: false,
            sender: sender,
            receiver: receiver
        });

        emit PaymentStored(paymentHash);
    }

    /// @notice Process a payment and mark it as processed
    /// @param paymentHash The unique hash of the payment to process
    /// @dev This function is only callable by the sender or receiver of the payment
    function processPayment(bytes32 paymentHash) external onlyOwner {
        require(!payments[paymentHash].isProcessed, "Payment already processed");
        require(
            msg.sender == payments[paymentHash].sender || msg.sender == payments[paymentHash].receiver,
            "You are not the sender or receiver of this payment"
        );
        payments[paymentHash].isProcessed = true;
        emit PaymentProcessed(paymentHash);
    }

    /// @notice Get the encrypted invoice type of a payment
    /// @param paymentHash The unique hash of the payment
    /// @return The encrypted invoice type
    function getInvoiceType(bytes32 paymentHash) external view returns (euint4) {
        _checkSenderOrReceiver(paymentHash);
        return payments[paymentHash].invoiceType;
    }

    /// @notice Get the encrypted amount of a payment
    /// @param paymentHash The unique hash of the payment
    /// @return The encrypted amount
    function getInvoiceAmount(bytes32 paymentHash) external view returns (euint64) {
        _checkSenderOrReceiver(paymentHash);
        return payments[paymentHash].amount;
    }

    /// @notice Check if the sender or receiver of the invoice is the caller
    /// @param paymentHash The unique hash of the payment
    function _checkSenderOrReceiver(bytes32 paymentHash) internal view {
        if (
            msg.sender != payments[paymentHash].sender &&
            msg.sender != payments[paymentHash].receiver &&
            msg.sender != owner()
        ) {
            revert("You are not the sender or receiver of this invoice");
        }
    }
}
