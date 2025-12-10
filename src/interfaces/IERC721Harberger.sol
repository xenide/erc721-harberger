// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title IERC721Harberger
/// @notice ERC721 with Harberger tax mechanism for self-assessed NFT valuation
/// @dev Implements a harberger tax system where owners declare prices and pay periodic taxes, with forced sales for
/// delinquent NFTs
interface IERC721Harberger {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   PRICING FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Returns the current declared price of an NFT
    /// @param aTokenId The token ID to query
    /// @return The declared price in PAYMENT_TOKEN precision
    /// @dev Reverts if the token does not exist
    function getPrice(uint256 aTokenId) external view returns (uint256);

    /// @notice Updates the declared price of an NFT and restarts its tax epoch
    /// @param aTokenId The token ID to update
    /// @param aPrice The new declared price
    /// @dev
    /// - Only callable by the current token owner
    /// - NFT must not be in a delinquent state
    /// - If new price > current price: owner pays the tax difference
    /// - If new price < current price: no refund of previously paid taxes (owner forfeits excess)
    /// - During grace period: owner pays a fixed penalty of (oldPrice * taxRate * GRACE_PERIOD / TAX_EPOCH_DURATION)
    ///   regardless of when during the grace period setPrice is called, using the OLD price not the new one
    ///   (prevents squatting by setting artificially low prices during grace period)
    function setPrice(uint256 aTokenId, uint256 aPrice) external;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   TAXATION FUNCTIONS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sets the universal tax rate for all NFTs in the collection
    /// @param aTaxRate The new tax rate (basis points)
    /// @dev
    /// - Only callable by the contract owner
    /// - Reverts if aTaxRate exceeds MAX_TAX_RATE
    /// - Changes are applied immediately to all NFTs
    function setTaxRate(uint256 aTaxRate) external;

    /// @notice Returns the duration of each tax epoch in seconds
    /// @return The tax epoch duration
    function TAX_EPOCH_DURATION() external view returns (uint256);

    /// @notice Returns the grace period duration after tax epoch expires in seconds
    /// @return The grace period duration
    /// @dev Grace period allows delinquent owners to pay taxes before forced sale begins
    function GRACE_PERIOD() external view returns (uint256);

    /// @notice Returns the current universal tax rate applied to all NFTs
    /// @return The tax rate (basis points)
    function taxRate() external view returns (uint256);

    /// @notice Returns the ERC20 token used for all payments
    /// @return The IERC20 payment token address
    function PAYMENT_TOKEN() external view returns (IERC20);

    /// @notice Returns the precision multiplier for converting between price and tax calculations
    /// @return The multiplier (10^(18 - PAYMENT_TOKEN.decimals()))
    /// @dev Assumed immutable; PAYMENT_TOKEN decimals must never change after deployment
    function PAYMENT_TOKEN_PRECISION_MULTIPLIER() external view returns (uint256);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   DAO FUNCTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Sweeps all accumulated tax revenue to the fee receiver
    /// @dev
    /// - Callable by anyone (permissionless)
    /// - Transfers entire contract token balance to feeReceiver if set
    function sweepTaxesToDao() external;

    /// @notice Returns the address that receives swept tax revenue
    /// @return The fee receiver address (DAO multi-sig or timelock)
    function feeReceiver() external view returns (address);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   STATE QUERY FUNCTIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Computes when the current tax epoch ends for an NFT
    /// @param aTokenId The token ID to query
    /// @return The block timestamp when this NFT's tax epoch expires
    /// @dev Reverts if the token does not exist
    function taxEpochEnd(uint256 aTokenId) external view returns (uint256);

    /// @notice Checks if an NFT is currently in the grace period
    /// @param aTokenId The token ID to check
    /// @return True if block.timestamp > taxEpochEnd && block.timestamp <= gracePeriodEnd
    /// @dev During grace period, owner can pay overdue taxes but no longer has tax credits
    /// @dev Reverts if the token does not exist
    function isInGracePeriod(uint256 aTokenId) external view returns (bool);

    /// @notice Checks if an NFT is in a delinquent state (past both tax epoch and grace period)
    /// @param aTokenId The token ID to check
    /// @return True if block.timestamp > gracePeriodEnd
    /// @dev Delinquent NFTs are subject to forced sale via reverse Dutch auction
    /// @dev Reverts if the token does not exist
    function isDelinquent(uint256 aTokenId) external view returns (bool);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   TRANSFER FUNCTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Transfers NFT ownership with automatic tax settlement and pricing mechanics
    /// @param aTokenId The token ID to transfer
    /// @param aMaxPriceIncludingTaxes Maximum amount (price + taxes) buyer will pay
    /// @dev
    /// PAYMENT MECHANISM:
    /// - Caller (buyer) must approve PAYMENT_TOKEN for at least lTotalDue amount
    /// - Excess payment above lTotalDue is refunded to buyer
    ///
    /// PRICING BY STATE:
    /// - [0, taxEpochEnd]: buyer pays current owner's declared price
    /// - [taxEpochEnd, gracePeriodEnd]: buyer pays current owner's declared price (grace period)
    /// - [gracePeriodEnd, gracePeriodEnd + TAX_EPOCH_DURATION]: reverse Dutch auction
    ///   price = max(prevPrice * (auctionEnd - now) / TAX_EPOCH_DURATION, MIN_NFT_PRICE)
    /// - [gracePeriodEnd + TAX_EPOCH_DURATION, ∞]: buyer pays MIN_NFT_PRICE
    ///
    /// PREVIOUS OWNER REFUNDS:
    /// - During tax epoch: refunds declared price + remaining tax credit
    ///   (tax credit = lastPaidAmt * (taxEpochEnd - now) / TAX_EPOCH_DURATION)
    /// - During grace period: refunds only declared price (no tax credit available)
    /// - After grace period: no refund (owner had time to pay)
    /// NOTE: Refund can be less if contract balance is insufficient (edge case when
    /// tax rate was lowered mid-epoch); loss is capped at taxes paid for the epoch
    ///
    /// NEW OWNER STATE:
    /// - Fresh tax epoch begins with this transaction's block.timestamp
    function buy(uint256 aTokenId, uint256 aMaxPriceIncludingTaxes) external;

    /// @notice Mints a new NFT with an initial declared price
    /// @param aInitialPrice The initial declared price
    /// @dev
    /// - Mints to msg.sender with the next token ID
    /// - Caller must approve PAYMENT_TOKEN for (aInitialPrice + tax on aInitialPrice)
    /// - Initial tax paid is calcTaxDue(aInitialPrice)
    /// - A fresh tax epoch begins at block.timestamp
    /// - reverts if aInitialPrice < MIN_NFT_PRICE or > MAX_SUPPORTED_PRICE
    function mint(uint256 aInitialPrice) external;
}
