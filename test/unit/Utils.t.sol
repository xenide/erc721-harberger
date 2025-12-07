pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { Utils } from "../../src/libraries/Utils.sol";

contract UtilsTest is Test {
    function test_calcTaxDue() public pure {
        // arrange
        uint256 lPrice = 1e18;
        uint256 lTaxRate = 0.01e18;

        // act
        uint256 lTaxDue = Utils.calcTaxDue(lPrice, 1, lTaxRate);

        // assert
        assertEq(lTaxDue, 1e16 + 1);
    }

    function test_calcTaxDue_small_amt() public pure {
        // arrange
        uint256 lPrice = 1e2;
        uint256 lTaxRate = 0.01e18;

        // act
        uint256 lTaxDue = Utils.calcTaxDue(lPrice, 1, lTaxRate);

        // assert
        assertEq(lTaxDue, 2);
    }

    function test_calcTaxDue_different_multiplier() public pure {
        uint256 lPrice = 1e4;
        uint256 lTaxRate = 0.01e18;
        uint256 lPrecisionMultiplier = 1e14;

        // act
        uint256 lTaxDue = Utils.calcTaxDue(lPrice, lPrecisionMultiplier, lTaxRate);

        // assert
        assertEq(lTaxDue, 101);
    }
}
