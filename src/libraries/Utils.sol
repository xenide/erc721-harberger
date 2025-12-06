pragma solidity ^0.8.28;

import { FixedPointMathLib } from "../../lib/solady/src/utils/FixedPointMathLib.sol";

library Utils {
    using FixedPointMathLib for uint256;

    uint256 public constant WAD = 1e18;

    /// @param aPrice The price in native precision.
    /// @param aPrecisionMultiplier The multiplier to convert the price to WAD base.
    /// @param aTaxRate The tax rate in WAD. WAD == 100%.
    /// @return rTaxesDue Amount due in the native precision. Rounded up to favor the tax authority.
    function calcTaxDue(uint256 aPrice, uint256 aPrecisionMultiplier, uint256 aTaxRate)
        public
        pure
        returns (uint256 rTaxesDue)
    {
        // can overflow
        uint256 lPriceWAD = aPrice * aPrecisionMultiplier;

        uint256 lTaxDueWAD = lPriceWAD.fullMulDivUp(aTaxRate, WAD);

        // add 1 to the result to mitigate rounding errors
        rTaxesDue = lTaxDueWAD / aPrecisionMultiplier + 1;
    }
}
