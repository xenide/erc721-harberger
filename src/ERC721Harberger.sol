// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";
import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract ERC721Harberger is IERC721Harberger, ERC721, Ownable, ReentrancyGuardTransient {
    constructor() ERC721("Harberger", "HAR") { }

    function setPrice(uint256 price) external { }

    function getPrice() external view returns (uint256) { }

    function setTaxRate(uint256 taxRate) external { }

    function getTaxRate() external view returns (uint256) { }

    function payTax() external { }

    function withdrawTaxesToDao() external { }

    function currentTaxEpoch() external { }

    function taxEpochEnd() external { }

    function buy() external { }
}
