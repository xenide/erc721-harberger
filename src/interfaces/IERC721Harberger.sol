// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC721Harberger {
    // Pricing of the NFT
    // reverts if token doesn't exist
    function getPrice(uint256 aTokenId) external view returns (uint256);
    // Restarts the epoch, charges the owner more taxes if the price is higher than the current
    // if price is lower than current, there is no refund of previous taxes
    // Owner does not pay the difference between last price and this new price, only the difference in taxes if any.
    function setPrice(uint256 aTokenId, uint256 aPrice) external;

    // Taxation
    function setTaxRate(uint256 aTaxRate) external;

    function TAX_EPOCH_DURATION() external view returns (uint256);
    // Grace period after end of tax epoch before seizing the NFT
    function GRACE_PERIOD() external view returns (uint256);
    /// @notice Universal rate for all NFTs in this collection.
    function taxRate() external view returns (uint256);
    // providing an array to enhance UX as one wallet might have many NFTs
    function prepayTaxes(uint256[] calldata aTokenIds) external;

    function PAYMENT_TOKEN() external view returns (IERC20);
    // it is assumed that the decimals of the ERC20 never change
    function PAYMENT_TOKEN_PRECISION_MULTIPLIER() external view returns (uint256);

    // can be called by anyone
    function sweepTaxesToDao() external;
    // the DAO multi-sig / timelock
    function feeReceiver() external view returns (address);

    function taxEpochEnd(uint256 aTokenId) external view returns (uint256);

    // Ownership transfer
    // Pulls the ERC20 payment token from the caller's wallet. So caller must have approved the amount
    // Refunds excess payment back to buyer
    // Price of the NFT should remain unchanged after buying it
    // Refunds taxes paid by the previous owner if any to prevent griefing
    function buy(uint256 aTokenId, uint256 aMaxPriceIncludingTaxes) external;

    // Mints the NFT to the caller.
    // Caller has to pay taxes on the declared value of the NFT
    // Pulls payment from the caller so must already have the approval done
    function mint(uint256 aInitialPrice) external;

    // Returns true if the NFT is past the tax epoch and is in the grace period
    function isInGracePeriod(uint256 aTokenId) external view returns (bool);

    // Returns true if the NFT is a delinquent state (i.e. has unpaid taxes) and
    // past the tax epoch and the grace period, and can be seized
    function isDelinquent(uint256 aTokenId) external view returns (bool);

    // Returns true if NFT is seized (i.e. owned by the NFT contract)
    function isSeized(uint256 aTokenId) external view returns (bool);

    // NFT becomes owned by the contract, ready for auction
    function seizeDelinquentNft(uint256 aTokenId) external;
}
