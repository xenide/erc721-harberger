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

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GOVERNOR FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

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

    function setPrice(uint256 aTokenId, uint256 aNewPrice) external nonReentrant {
        require(_requireOwned(aTokenId) == msg.sender, Errors.NotTokenOwner());
        require(!isDelinquent(aTokenId), Errors.NFTIsDelinquent());
        require(aNewPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        uint256 lNewTaxAmt = _calcTaxDue(aNewPrice);
        // subtraction will underflow if it's in the grace period, which is fine
        uint256 lRemainingTaxCredit =
            _taxInfo[aTokenId].lastPaidAmt * (taxEpochEnd(aTokenId) - block.timestamp) / Constants.TAX_EPOCH_DURATION;

        if (lNewTaxAmt > lRemainingTaxCredit) {
            _pullPayment(msg.sender, lNewTaxAmt - lRemainingTaxCredit);
        }
        // if there's a surplus remaining tax credit, the owner forfeits it
        else { }

        _updateTaxInfo(aTokenId, aNewPrice, lNewTaxAmt);
    }

    function transferFrom(address aFrom, address aTo, uint256 aTokenId) public override nonReentrant {
        require(!isDelinquent(aTokenId), Errors.NFTIsDelinquent());
        require(!isInGracePeriod(aTokenId), Errors.NFTInGracePeriod());

        ERC721.transferFrom(aFrom, aTo, aTokenId);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    PUBLIC FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // _safeMint is reused from OZ's impl
    // TODO: do I need to return the tokenId? milady doesn't return it
    function mint(uint256 aInitialPrice) external nonReentrant {
        require(aInitialPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        uint256 lTokenId = _tokenCounter++;
        uint256 lTaxDue = _calcTaxDue(aInitialPrice);
        _updateTaxInfo(lTokenId, aInitialPrice, lTaxDue);

        _safeMint(msg.sender, lTokenId);
        _pullPayment(msg.sender, lTaxDue);
    }

    /// @inheritdoc IERC721Harberger
    function buy(uint256 aTokenId, uint256 aMaxPriceIncludingTaxes) external nonReentrant {
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

            // TODO: refund owner at that listed price
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

        _updateTaxInfo(aTokenId, lPrice, lTaxes);
        address lPrevOwner = _update(msg.sender, aTokenId, address(0));
        assert(lPrevOwner == lPrevOwnerStorage);
        emit NFTBought(lPrevOwnerStorage, msg.sender, aTokenId, lPrice);
    }

    function getPrice(uint256 aTokenId) external view returns (uint256 rPrice) {
        _requireOwned(aTokenId);
        rPrice = _taxInfo[aTokenId].price;
    }

    function taxEpochEnd(uint256 aTokenId) public view returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return _taxInfo[aTokenId].lastPaidTimestamp + TAX_EPOCH_DURATION;
    }

    function _gracePeriodEnd(uint256 aTokenId) internal view returns (uint256) {
        // SAFETY: Addition does not overflow for human scale times
        return taxEpochEnd(aTokenId) + GRACE_PERIOD;
    }

    function isInGracePeriod(uint256 aTokenId) public view returns (bool) {
        return block.timestamp > taxEpochEnd(aTokenId) && block.timestamp <= _gracePeriodEnd(aTokenId);
    }

    function isDelinquent(uint256 aTokenId) public view returns (bool) {
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
}
