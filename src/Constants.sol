// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library Constants {
    uint256 public constant TAX_EPOCH_DURATION = 60 days;
    uint256 public constant GRACE_PERIOD = 1 days;

    // this is defined in terms of the tax epoch duration
    uint256 public constant DEFAULT_TAX_RATE = 0.01e18; // 1%
    uint256 public constant MAX_TAX_RATE = 0.2e18; // 20%

    uint256 public constant MIN_NFT_PRICE = 1e18;
}
