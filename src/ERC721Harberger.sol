// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20, SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";
import { FixedPointMathLib } from "../lib/solady/src/utils/FixedPointMathLib.sol";
import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { TaxInfo } from "./structs/TaxInfo.sol";
import { Constants } from "./Constants.sol";
import { Errors } from "./Errors.sol";
import { Events } from "./Events.sol";

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

    modifier onlyTokenOwner(uint256 aTokenId) {
        require(_ownerOf(aTokenId) == msg.sender, Errors.NotTokenOwner());
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GOVERNOR FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setTaxRate(uint256 aTaxRate) external onlyOwner {
        require(aTaxRate <= Constants.MAX_TAX_RATE, Errors.TaxRateTooHigh());
        taxRate = aTaxRate;
        emit Events.TaxRateSet(aTaxRate);
    }

    function recoverERC20(IERC20 aToken, uint256 aAmount) external onlyOwner {
        aToken.safeTransfer(owner(), aAmount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            TOKEN OWNER FUNCTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setPrice(uint256 aTokenId, uint256 aNewPrice) external onlyTokenOwner(aTokenId) {
        require(aNewPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        uint256 lPrevPrice = _taxInfo[aTokenId].price;

        // If price is higher than the current, owner has to pay additional taxes till the end of the epoch
        if (aNewPrice > lPrevPrice) {
            uint256 lPriceDiff = aNewPrice - lPrevPrice;
            // TODO: fill in impl
            uint256 lTimeTillEpochEnd;
            uint256 lTaxableAmt;
            _pullPayment(msg.sender, _calcTaxDue(lTaxableAmt));

            // TODO: update lastPaidTime + lastPaidAmt
        }
        // If price is equal or lower, there is no refund to prevent griefing
        else { }

        _taxInfo[aTokenId].price = aNewPrice;
    }

    function transfer(uint256 aTokenId, address aTo) external { }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    PUBLIC FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // _safeMint is reused from OZ's impl
    // TODO: do I need to return the tokenId?
    function mint(uint256 aInitialPrice) external {
        require(aInitialPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        uint256 lTokenId = _tokenCounter++;
        _taxInfo[lTokenId].price = aInitialPrice;
        _taxInfo[lTokenId].lastPaidTimestamp = block.timestamp;
        uint256 lTaxDue = _calcTaxDue(aInitialPrice);
        _taxInfo[lTokenId].lastPaidAmt = lTaxDue;

        _pullPayment(msg.sender, lTaxDue);
        _safeMint(msg.sender, lTokenId);
    }

    /// @inheritdoc IERC721Harberger
    function buy(uint256 aTokenId, uint256 aMaxPriceIncludingTaxes) external {
        address lPrevOwnerStorage = _ownerOf(aTokenId);
        require(msg.sender != lPrevOwnerStorage, Errors.BuyingOwnNFT());

        TaxInfo storage lInfo = _taxInfo[aTokenId];
        uint256 lPrice;
        uint256 lAuctionPeriodEnd = _gracePeriodEnd(aTokenId) + Constants.TAX_EPOCH_DURATION;

        uint256 lTotalDue;
        uint256 lTaxesToRefundPrevOwner;

        // Case 1: Buy during tax epoch and grace period
        if (block.timestamp <= _gracePeriodEnd(aTokenId)) {
            lPrice = lInfo.price;

            if (block.timestamp <= taxEpochEnd(aTokenId)) {
                // TODO: ensure correctness of this operation
                lTaxesToRefundPrevOwner =
                    (taxEpochEnd(aTokenId) - block.timestamp) * lInfo.lastPaidAmt / TAX_EPOCH_DURATION;
            }
            // if it happens during grace period, prev owner is already owing taxes so there will be no refund
            else {
                assert(block.timestamp > taxEpochEnd(aTokenId));
            }
        }
        // Case 2: Buy during the reverse dutch auction period, price decays to minimum
        else if (block.timestamp < lAuctionPeriodEnd) {
            require(isSeized(aTokenId), Errors.BuyingNonSeizedNFT());

            // reverse dutch auction from end of grace period to end of auction
            // with prices slowing decaying to the minimum price
            lPrice = lInfo.price.fullMulDiv(lAuctionPeriodEnd - block.timestamp, Constants.TAX_EPOCH_DURATION)
                .max(Constants.MIN_NFT_PRICE);
        }
        // Case 3: Beyond the auction period, buyer pays minimum price
        else {
            require(isSeized(aTokenId), Errors.BuyingNonSeizedNFT());
            lPrice = Constants.MIN_NFT_PRICE;

            _pullPayment(msg.sender, lTotalDue);
        }

        uint256 lTaxes = _calcTaxDue(lPrice);
        lTotalDue = lPrice + lTaxes;
        require(lTotalDue <= aMaxPriceIncludingTaxes, Errors.MaxPriceIncludingTaxesExceeded());
        _pullPayment(msg.sender, lTotalDue);

        if (lTaxesToRefundPrevOwner > 0) {
            // there will always be enough tokens to refund the prevOwner if bought before epoch end
            _refundPayment(lPrevOwnerStorage, lTaxesToRefundPrevOwner);
        }

        _updateTaxInfo(aTokenId, lTaxes);
        address lPrevOwner = _update(msg.sender, aTokenId, address(0));
        assert(lPrevOwner == lPrevOwnerStorage);
        emit NFTBought(lPrevOwnerStorage, msg.sender, aTokenId, lPrice);
    }

    function getPrice(uint256 aTokenId) external view returns (uint256 rPrice) {
        rPrice = _taxInfo[aTokenId].price;
    }

    function prepayTaxes(uint256[] calldata aTokenIds) external { }

    function taxEpochEnd(uint256 aTokenId) public view returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return _taxInfo[aTokenId].lastPaidTimestamp + TAX_EPOCH_DURATION;
    }

    function _gracePeriodEnd(uint256 aTokenId) internal view returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return taxEpochEnd(aTokenId) + GRACE_PERIOD;
    }

    function isDelinquent(uint256 aTokenId) public view returns (bool) {
        // SAFETY: Addition does not overflow for human scale times
        return block.timestamp > _gracePeriodEnd(aTokenId);
    }

    function isSeized(uint256 aTokenId) public view returns (bool) {
        return _ownerOf(aTokenId) == address(this);
    }

    function seizeDelinquentNft(uint256 aTokenId) external nonReentrant {
        require(isDelinquent(aTokenId), Errors.NFTNotDelinquent(_gracePeriodEnd(aTokenId), block.timestamp));
        require(!isSeized(aTokenId), Errors.NFTAlreadySeized());

        address lPrevOwner = _update(address(this), aTokenId, address(0));

        emit NFTSeized(lPrevOwner, address(this), aTokenId);
    }

    function sweepTaxesToDao() external {
        if (feeReceiver != address(0)) {
            PAYMENT_TOKEN.safeTransfer(feeReceiver, PAYMENT_TOKEN.balanceOf(address(this)));
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                        INTERNAL / PRIVATE FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _pullPayment(address aFrom, uint256 aAmount) internal {
        PAYMENT_TOKEN.safeTransferFrom(aFrom, address(this), aAmount);
    }

    function _refundPayment(address aTo, uint256 aAmount) internal {
        PAYMENT_TOKEN.safeTransfer(aTo, aAmount);
    }

    function _updateTaxInfo(uint256 aTokenId, uint256 aTaxPaid) internal {
        _taxInfo[aTokenId].lastPaidTimestamp = block.timestamp;
        _taxInfo[aTokenId].lastPaidAmt = aTaxPaid;
    }

    /// @param aTaxableAmt in WAD
    /// @return rTaxableAmt The amount to be taxed, in the PAYMENT_TOKEN, denominated in its native precision.
    function _calcTaxDue(uint256 aTaxableAmt) internal view returns (uint256 rTaxableAmt) {
        // we round up to avoid losing fractional value
        // TODO: need to +1 in the native precision, as this is insufficient
        rTaxableAmt = aTaxableAmt.mulWadUp(taxRate);
    }
}
