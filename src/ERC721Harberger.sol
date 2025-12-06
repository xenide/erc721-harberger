// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { DEFAULT_TAX_RATE, MAX_TAX_RATE } from "./Constants.sol";
import { Errors } from "./Errors.sol";
import { Events } from "./Events.sol";

contract ERC721Harberger is IERC721Harberger, ERC721, Ownable, ReentrancyGuardTransient {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        STORAGE                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(uint256 => uint256) private _price;

    /// @notice Universal rate for all NFTs in this collection.
    uint256 public taxRate = DEFAULT_TAX_RATE;

    uint256 public immutable TAX_EPOCH_DURATION = 60 days;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            CONSTRUCTOR / FALLBACKS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(address aOwner) ERC721("Harberger", "HAR") {
        _initializeOwner(aOwner);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     MODIFIERS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GOVERNOR FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setTaxRate(uint256 aTaxRate) external onlyOwner {
        require(aTaxRate <= MAX_TAX_RATE, Errors.TaxRateTooHigh());
        taxRate = aTaxRate;
        emit Events.TaxRateSet(aTaxRate);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            TOKEN OWNER FUNCTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setPrice(uint256 aPrice) external { }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                         OWNERSHIP TRANSFER FUNCTIONS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function getPrice(uint256 aTokenId) external view returns (uint256 rPrice) {
        rPrice = _price[aTokenId];
    }

    function payTax() external { }

    function withdrawTaxesToDao() external { }

    function currentTaxEpoch() external { }

    function taxEpochEnd() external { }

    function buy() external { }
}
