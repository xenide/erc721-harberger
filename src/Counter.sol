// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC721Harberger } from "./interfaces/IERC721Harberger.sol";
import { ReentrancyGuardTransient } from "../lib/solady/src/utils/ReentrancyGuardTransient.sol";

contract ERC721Harberger is IERC721Harberger, ReentrancyGuardTransient { }
