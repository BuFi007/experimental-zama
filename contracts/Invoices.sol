// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
// import "./mock/ConfidentialERC20.sol";
import "fhevm-contracts/contracts/token/ERC20/extensions/ConfidentialERC20Mintable.sol";

//import "fhevm-contracts/contracts/token/ERC20/extensions/ConfidentialERC20Mintable.sol";

// import "fhevm-contracts/contracts/token/ERC20/extensions/ConfidentialERC20Mintable.sol";

/// @notice This contract implements an encrypted payment system for Peanut Protocol with confidential data
/// @dev Uses FHE to encrypt payment details and balances
contract ConfidentialPayments is SepoliaZamaFHEVMConfig, Ownable {
    // Encrypted payment structure

    struct EncryptedPayment {
        address token;
        euint64 amount;
        bool isProcessed;
        address sender;
        address receiver;
    }

    struct EncryptedPaymentRequest {
        euint64 amount;
        bool isProcessed;
        address token;
        address sender;
        address receiver;
        bytes inputProofAmount;
    }

    // Mapping from payment hash to encrypted payment details
    mapping(string => EncryptedPayment) public payments;
    mapping(string => EncryptedPaymentRequest) public paymentRequests;

    constructor() Ownable(msg.sender) {}

    // Events
    event PaymentStored(string indexed paymentHash);
    event PaymentProcessed(string indexed paymentHash);
    event PaymentRequestStored(string indexed paymentHash);

    /// @notice Store a new encrypted payment
    /// @param paymentHash The unique hash of the payment
    /// @param encryptedAmount The encrypted amount of the payment
    /// @param inputProofAmount The proof of the encrypted amount
    /// @param receiver The receiver of the payment
    function storePayment(
        address token,
        string memory paymentHash,
        einput encryptedAmount,
        bytes calldata inputProofAmount,
        address receiver
    ) external {
        require(!payments[paymentHash].isProcessed, "Payment already exists");
        euint64 value = TFHE.asEuint64(encryptedAmount, inputProofAmount);

        ConfidentialERC20 erc20 = ConfidentialERC20(token);
        TFHE.allowThis(value);
        TFHE.allowTransient(value, receiver);
        TFHE.allow(value, address(erc20));

        erc20.transferFrom(msg.sender, address(this), value);

        bool success = erc20.transferFrom(msg.sender, address(this), value);
        require(success, "Transfer failed");

        payments[paymentHash] = EncryptedPayment({
            token: token,
            amount: value,
            isProcessed: false,
            sender: msg.sender,
            receiver: receiver
        });

        emit PaymentStored(paymentHash);
    }

    /// @notice Claim a payment
    /// @param paymentHash The unique hash of the payment
    function claimPayment(string memory paymentHash) external {
        require(payments[paymentHash].receiver == msg.sender, "You are not the receiver of this invoice");
        // TFHE.allowThis(payments[paymentHash].amount);
        // TFHE.allow(payments[paymentHash].amount, msg.sender);
        euint64 value = payments[paymentHash].amount;

        ConfidentialERC20 erc20 = ConfidentialERC20(payments[paymentHash].token);
        bool success = erc20.transferFrom(address(this), msg.sender, value);
        require(success, "Transfer failed");
        payments[paymentHash].isProcessed = true;

        emit PaymentProcessed(paymentHash);
    }

    function requestPayment(
        string memory paymentHash,
        address token,
        address to,
        einput encryptedAmount,
        bytes calldata inputProofAmount
    ) external {
        require(!payments[paymentHash].isProcessed, "Payment already exists");
        euint64 value = TFHE.asEuint64(encryptedAmount, inputProofAmount);
        paymentRequests[paymentHash] = EncryptedPaymentRequest({
            amount: value,
            isProcessed: false,
            token: token,
            sender: to,
            receiver: msg.sender,
            inputProofAmount: inputProofAmount
        });

        emit PaymentRequestStored(paymentHash);
    }

    /// @notice Pay a payment request
    /// @param paymentHash The unique hash of the payment request

    function payPaymentRequest(string memory paymentHash) external {
        require(paymentRequests[paymentHash].sender == msg.sender, "You are not the receiver of this invoice");
        require(paymentRequests[paymentHash].isProcessed, "Payment already processed");
        euint64 value = paymentRequests[paymentHash].amount;
        ConfidentialERC20 erc20 = ConfidentialERC20(paymentRequests[paymentHash].token);
        TFHE.allowTransient(value, address(erc20));
        bool success = erc20.transferFrom(address(this), msg.sender, value);
        require(success, "Transfer failed");
        paymentRequests[paymentHash].isProcessed = true;
    }

    /// @notice Get the encrypted amount of a payment
    /// @param paymentHash The unique hash of the payment
    /// @return The encrypted amount
    function getInvoiceAmount(string memory paymentHash) external view returns (euint64) {
        _checkSenderOrReceiver(paymentHash);
        return payments[paymentHash].amount;
    }

    /// @notice Check if the sender or receiver of the invoice is the caller
    /// @param paymentHash The unique hash of the payment
    function _checkSenderOrReceiver(string memory paymentHash) internal view {
        if (
            msg.sender != payments[paymentHash].sender &&
            msg.sender != payments[paymentHash].receiver &&
            msg.sender != owner()
        ) {
            revert("You are not the sender or receiver of this invoice");
        }
    }

    /// @notice Get the encrypted payment details
    /// @param paymentHash The unique hash of the payment
    /// @return The encrypted payment details
    function getPayment(string memory paymentHash) external view returns (EncryptedPayment memory) {
        return payments[paymentHash];
    }
}
