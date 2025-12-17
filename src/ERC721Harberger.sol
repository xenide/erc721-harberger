// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Utils } from "./libraries/Utils.sol";
import { Constants } from "./Constants.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Errors } from "./Errors.sol";
import { Events } from "./Events.sol";
import { FixedPointMathLib } from "../lib/solady/src/utils/FixedPointMathLib.sol";
import { IERC20, SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";
import { TaxInfo } from "./structs/TaxInfo.sol";

contract ERC721Harberger is IERC721Harberger, ERC721, Ownable, ReentrancyGuardTransient, Events {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        STORAGE                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 public taxRate = Constants.DEFAULT_TAX_RATE;
    uint256 public immutable TAX_EPOCH_DURATION = Constants.TAX_EPOCH_DURATION;
    uint256 public immutable GRACE_PERIOD = Constants.GRACE_PERIOD;
    IERC20 public immutable PAYMENT_TOKEN;
    uint256 public immutable PAYMENT_TOKEN_PRECISION_MULTIPLIER;
    address public feeReceiver;

    mapping(uint256 tokenId => TaxInfo) private _taxInfo;
    uint256 private _tokenCounter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            CONSTRUCTOR / FALLBACKS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(address aOwner, IERC20 aPaymentToken, address aFeeReceiver) ERC721("Harberger", "HAR") {
        _initializeOwner(aOwner);
        PAYMENT_TOKEN = aPaymentToken;
        feeReceiver = aFeeReceiver;
        PAYMENT_TOKEN_PRECISION_MULTIPLIER = 10 ** (18 - ERC20(address(aPaymentToken)).decimals());
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     MODIFIERS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    modifier ensureTaxCompliance(uint256 aTokenId) {
        _ensureTaxCompliance(aTokenId);
        _;
    }

    modifier validateTokenId(uint256 aTokenId) {
        _requireOwned(aTokenId);
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GOVERNOR FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721Harberger
    function setTaxRate(uint256 aTaxRate) external onlyOwner {
        require(aTaxRate <= Constants.MAX_TAX_RATE, Errors.TaxRateTooHigh());
        taxRate = aTaxRate;
        emit TaxRateSet(aTaxRate);
    }

    function recoverERC20(IERC20 aToken, uint256 aAmount) external onlyOwner {
        aToken.safeTransfer(owner(), aAmount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            TOKEN OWNER FUNCTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721Harberger
    function setPrice(uint256 aTokenId, uint256 aNewPrice) external nonReentrant {
        require(_requireOwned(aTokenId) == msg.sender, Errors.NotTokenOwner());
        require(!isDelinquent(aTokenId), Errors.NFTIsDelinquent());
        require(aNewPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        require(aNewPrice <= Constants.MAX_SUPPORTED_PRICE, Errors.NFTPriceTooHigh());

        uint256 lRemainingTaxCredit = 0;
        uint256 lGracePeriodPenalty = 0;
        // happy case: NFT is in a tax compliant state, and not in a grace period state
        if (!isInGracePeriod(aTokenId)) {
            lRemainingTaxCredit = _taxInfo[aTokenId].lastPaidAmt * (taxEpochEnd(aTokenId) - block.timestamp)
                / Constants.TAX_EPOCH_DURATION;
        } else {
            // During the grace period, the owner necessarily has no remaining tax credits and has has to pay a
            // penalty which is fixed at the fraction `GRACE_PERIOD / TAX_EPOCH_DURATION` of the previous declared price
            // regardless if he pays at the beginning or the end of the grace period. This is not recorded to
            // taxInfo.lastPaidAmt as that will affect the reimbursement calculations.
            // It's important that we use the old price instead of the new declared price, as the owner can
            // set a low price during the grace period, and get away with paying lower taxes for this period,
            // effectively "squatting" during the grace period.
            lGracePeriodPenalty = _calcTaxDue(_taxInfo[aTokenId].price) * GRACE_PERIOD / TAX_EPOCH_DURATION;
        }

        uint256 lNewTaxAmt = _calcTaxDue(aNewPrice);
        if (lNewTaxAmt + lGracePeriodPenalty > lRemainingTaxCredit) {
            _pull(msg.sender, lNewTaxAmt + lGracePeriodPenalty - lRemainingTaxCredit);
        }
        // if there's a surplus remaining tax credit exceeding the new tax amt, the owner forfeits it
        else { }

        _updateTaxInfo(aTokenId, aNewPrice, lNewTaxAmt);
    }

    /// @inheritdoc ERC721
    function transferFrom(address aFrom, address aTo, uint256 aTokenId)
        public
        override
        ensureTaxCompliance(aTokenId)
        nonReentrant
    {
        ERC721.transferFrom(aFrom, aTo, aTokenId);
    }

    /// @inheritdoc ERC721
    function safeTransferFrom(address aFrom, address aTo, uint256 aTokenId, bytes memory aData)
        public
        override
        ensureTaxCompliance(aTokenId)
        nonReentrant
    {
        ERC721.safeTransferFrom(aFrom, aTo, aTokenId, aData);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    PUBLIC FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721Harberger
    function mint(uint256 aInitialPrice) external nonReentrant {
        require(aInitialPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        require(aInitialPrice <= Constants.MAX_SUPPORTED_PRICE, Errors.NFTPriceTooHigh());
        uint256 lTokenId = _tokenCounter++;
        uint256 lTaxDue = _calcTaxDue(aInitialPrice);
        uint256 lTotalDue = aInitialPrice + lTaxDue;
        _updateTaxInfo(lTokenId, aInitialPrice, lTaxDue);

        _safeMint(msg.sender, lTokenId);
        _pull(msg.sender, lTotalDue);
        emit NFTMinted(msg.sender, lTokenId);
    }

    /// @inheritdoc IERC721Harberger
    function buy(uint256 aTokenId, uint256 aMaxPriceIncludingTaxes) external nonReentrant {
        address lPrevOwnerStorage = _requireOwned(aTokenId);
        require(msg.sender != lPrevOwnerStorage, Errors.BuyingOwnNFT());

        TaxInfo storage lInfo = _taxInfo[aTokenId];
        uint256 lPrice;
        uint256 lAuctionPeriodEnd = _gracePeriodEnd(aTokenId) + Constants.TAX_EPOCH_DURATION;

        uint256 lTotalRefundPrevOwner = 0;

        // Case 1: Buy during tax epoch and grace period
        if (block.timestamp <= _gracePeriodEnd(aTokenId)) {
            lPrice = lInfo.price;

            if (block.timestamp <= taxEpochEnd(aTokenId)) {
                uint256 lPrevTaxCredit = _taxInfo[aTokenId].lastPaidAmt * (taxEpochEnd(aTokenId) - block.timestamp)
                    / Constants.TAX_EPOCH_DURATION;
                lTotalRefundPrevOwner = lPrice + lPrevTaxCredit;
            }
            // During the grace period, prev owner is already owing taxes so there will be no tax refund
            else {
                assert(isInGracePeriod(aTokenId));
                lTotalRefundPrevOwner = lPrice;
            }
        }
        // Case 2: Buy during the reverse dutch auction period, price decays to minimum
        else if (block.timestamp < lAuctionPeriodEnd) {
            // reverse dutch auction from end of grace period to end of auction
            // with prices slowing decaying to the minimum price
            lPrice = lInfo.price.fullMulDiv(lAuctionPeriodEnd - block.timestamp, Constants.TAX_EPOCH_DURATION)
                .max(Constants.MIN_NFT_PRICE);
            assert(lPrice <= lInfo.price && lPrice >= Constants.MIN_NFT_PRICE);
        }
        // Case 3: Beyond the auction period, buyer pays minimum price
        else {
            lPrice = Constants.MIN_NFT_PRICE;
        }

        uint256 lTaxes = _calcTaxDue(lPrice);
        uint256 lTotalDue = lPrice + lTaxes;
        require(lTotalDue <= aMaxPriceIncludingTaxes, Errors.MaxPriceIncludingTaxesExceeded());
        _pull(msg.sender, lTotalDue);
        _updateTaxInfo(aTokenId, lPrice, lTaxes);

        if (lTotalRefundPrevOwner > 0) {
            _refund(lPrevOwnerStorage, lTotalRefundPrevOwner);
        }
        address lPrevOwner = _update(msg.sender, aTokenId, address(0));
        assert(lPrevOwner == lPrevOwnerStorage);
        emit NFTBought(lPrevOwnerStorage, msg.sender, aTokenId, lPrice);
    }

    /// @inheritdoc IERC721Harberger
    function getPrice(uint256 aTokenId) external view validateTokenId(aTokenId) returns (uint256 rPrice) {
        rPrice = _taxInfo[aTokenId].price;
    }

    /// @inheritdoc IERC721Harberger
    function taxEpochEnd(uint256 aTokenId) public view validateTokenId(aTokenId) returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return _taxInfo[aTokenId].lastPaidTimestamp + TAX_EPOCH_DURATION;
    }

    /// @inheritdoc IERC721Harberger
    function isInGracePeriod(uint256 aTokenId) public view validateTokenId(aTokenId) returns (bool) {
        return block.timestamp > taxEpochEnd(aTokenId) && block.timestamp <= _gracePeriodEnd(aTokenId);
    }

    /// @inheritdoc IERC721Harberger
    function isDelinquent(uint256 aTokenId) public view validateTokenId(aTokenId) returns (bool) {
        return block.timestamp > _gracePeriodEnd(aTokenId);
    }

    /// @inheritdoc IERC721Harberger
    function sweepTaxesToDao() external nonReentrant {
        if (feeReceiver != address(0)) {
            PAYMENT_TOKEN.safeTransfer(feeReceiver, PAYMENT_TOKEN.balanceOf(address(this)));
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                        INTERNAL / PRIVATE FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _pull(address aFrom, uint256 aAmount) internal {
        PAYMENT_TOKEN.safeTransferFrom(aFrom, address(this), aAmount);
    }

    function _refund(address aTo, uint256 aAmount) internal {
        // Usually the new revenue coming in from the buyer is enough to cover the previous owner's price + tax paid.
        // However there is an edge case where the governor lowers the tax rate in the middle of some token's tax epoch
        // and subsequently the NFT is bought (at a lower tax rate). This can result in the revenue collected from the
        // new buyer being lower than the previous owner's price + tax paid.
        // In this case, if the contract has sufficient tokens, we just refund the previous owner in full anyway.
        // If the contract doesn't have enough, we refund whatever the contract has.
        // The previous owner's loss is capped at taxes paid for the epoch.
        if (aAmount > PAYMENT_TOKEN.balanceOf(address(this))) {
            PAYMENT_TOKEN.safeTransfer(aTo, PAYMENT_TOKEN.balanceOf(address(this)));
        } else {
            PAYMENT_TOKEN.safeTransfer(aTo, aAmount);
        }
    }

    function _gracePeriodEnd(uint256 aTokenId) internal view returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return taxEpochEnd(aTokenId) + GRACE_PERIOD;
    }

    function _updateTaxInfo(uint256 aTokenId, uint256 aPrice, uint256 aTaxPaid) internal {
        _taxInfo[aTokenId].price = aPrice;
        _taxInfo[aTokenId].lastPaidTimestamp = block.timestamp;
        _taxInfo[aTokenId].lastPaidAmt = aTaxPaid;
    }

    /// @param aTaxableAmt in native precision
    /// @return rTaxableAmt The amount to be taxed, in the PAYMENT_TOKEN, denominated in its native precision.
    function _calcTaxDue(uint256 aTaxableAmt) internal view returns (uint256 rTaxableAmt) {
        rTaxableAmt = Utils.calcTaxDue(aTaxableAmt, PAYMENT_TOKEN_PRECISION_MULTIPLIER, taxRate);
    }

    function _ensureTaxCompliance(uint256 aTokenId) internal view {
        require(!isDelinquent(aTokenId), Errors.NFTIsDelinquent());
        require(!isInGracePeriod(aTokenId), Errors.NFTInGracePeriod());
    }

    function _baseURI() internal pure override returns (string memory) {
        return "erc721-harberger";
    }
}
