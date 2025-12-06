// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Constants } from "./Constants.sol";
import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Errors } from "./Errors.sol";
import { Events } from "./Events.sol";
import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";
import { FixedPointMathLib } from "../lib/solady/src/utils/FixedPointMathLib.sol";
import { IERC20, SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC721Harberger is IERC721Harberger, ERC721, Ownable, ReentrancyGuardTransient {
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

    mapping(uint256 tokenId => uint256 price) private _price;
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
        uint256 lPrevPrice = _price[aTokenId];

        // If price is higher than the current, owner has to pay additional taxes till the end of the epoch
        if (aNewPrice > lPrevPrice) {
            uint256 lPriceDiff = aNewPrice - lPrevPrice;
            // TODO: fill in impl
            uint256 lTimeTillEpochEnd;
            uint256 lTaxableAmt;
            _pullPayment(msg.sender, _calcTaxDue(lTaxableAmt));
        }
        // If price is equal or lower, there is no refund to prevent griefing
        else { }

        _price[aTokenId] = aNewPrice;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    PUBLIC FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // _safeMint is reused from OZ's impl
    // TODO: do I need to return the tokenId?
    function mint(uint256 aInitialPrice) external {
        require(aInitialPrice >= Constants.MIN_NFT_PRICE, Errors.NFTPriceTooLow());
        uint256 lTokenId = _tokenCounter++;
        _price[lTokenId] = aInitialPrice;

        _pullPayment(msg.sender, _calcTaxDue(aInitialPrice));
        _safeMint(msg.sender, lTokenId);
    }

    /// @inheritdoc IERC721Harberger
    function buy(uint256 aTokenId) external {
        address lPrevOwnerStorage = _ownerOf(aTokenId);
        require(msg.sender != lPrevOwnerStorage, Errors.BuyingOwnNFT());

        uint256 lPrice = _price[aTokenId];
        // is this addition safe?
        _pullPayment(msg.sender, lPrice + _calcTaxDue(lPrice));
        // should we refund the prev owner's taxes paid? What if there's insufficient amount in the contract? Then it
        // will fail we can pull the taxes from the whole period first, then refund the prev owner

        address lPrevOwner = _update(msg.sender, aTokenId, address(0));
        assert(lPrevOwner == lPrevOwnerStorage);
    }

    function getPrice(uint256 aTokenId) external view returns (uint256 rPrice) {
        rPrice = _price[aTokenId];
    }

    function payTaxes(uint256[] calldata aTokenIds) external { }

    function taxEpochEnd(uint256 aTokenId) external view returns (uint256) { }
    function isDelinquent(uint256 aTokenId) external view returns (bool) {}
    function seizeDelinquentNft(uint256 aTokenId) external {}

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

    /// @param aTaxableAmt in WAD
    /// @return rTaxableAmt The amount to be taxed, in the PAYMENT_TOKEN, denominated in its native precision.
    function _calcTaxDue(uint256 aTaxableAmt) internal view returns (uint256 rTaxableAmt) {
        // we round up to avoid losing fractional value
        // TODO: need to +1 in the native precision, as this is insufficient
        rTaxableAmt = aTaxableAmt.mulWadUp(taxRate);
    }
}
