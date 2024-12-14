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
        TFHE.allowThis(payments[paymentHash].amount);
        // TFHE.allow(payments[paymentHash].amount, address(payments[paymentHash].token));
        // TFHE.allow(payments[paymentHash].amount, address(payments[paymentHash].receiver));
        // TFHE.debug.decrypt(payments[paymentHash].amount);
        euint64 value = payments[paymentHash].amount;
        // TFHE.allow(value, msg.sender);
        // TFHE.allowTransient(value, msg.sender);
        // TFHE.allow(value, address(payments[paymentHash].token));
        ConfidentialERC20 erc20 = ConfidentialERC20(payments[paymentHash].token);
        bool success = erc20.transfer(msg.sender, value);
        require(success, "Transfer failed");
        payments[paymentHash].isProcessed = true;

        emit PaymentProcessed(paymentHash);
    }
}
