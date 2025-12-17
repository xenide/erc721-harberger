// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

struct TaxInfo {
    uint112 price;
    uint112 lastPaidAmt;
    uint32 lastPaidTimestamp;
}
