pragma solidity ^0.8.28;

contract Errors {
    error NFTPriceTooLow();
    error NFTPriceTooHigh();

    error TaxRateTooHigh();

    error NotTokenOwner();
    error BuyingOwnNFT();

    error NFTIsDelinquent();
    error NFTInGracePeriod();

    error NFTNotDelinquent(uint256 taxEpochEnd, uint256 currentTimestamp);

    error MaxPriceIncludingTaxesExceeded();
}
