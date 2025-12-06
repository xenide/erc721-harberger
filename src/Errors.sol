pragma solidity ^0.8.10;

contract Errors {
    error NFTPriceTooLow();
    error TaxRateTooHigh();

    error NotTokenOwner();
    error BuyingOwnNFT();
}
