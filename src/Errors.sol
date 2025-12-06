pragma solidity ^0.8.10;

contract Errors {
    error NFTPriceTooLow();
    error TaxRateTooHigh();

    error NotTokenOwner();
    error BuyingOwnNFT();

    error NFTNotDelinquent(uint256 taxEpochEnd, uint256 currentTimestamp);
    error NFTAlreadySeized();
    error BuyingNonSeizedNFT();
}
