// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { BaseTest } from "../__fixtures/BaseTest.sol";
import { Constants } from "../../src/Constants.sol";

/**
 * @title PriceRangeInvariants
 * @notice Fuzzes user interactions and asserts that every NFT's declared price
 *         always stays within the permitted range defined by the protocol
 */
contract PriceRangeInvariants is BaseTest {
    uint256 internal _nextTokenId;
    uint256[] internal _mintedTokenIds;

    //--------------------------------------------------------------------------------------------------
    // Setup
    //--------------------------------------------------------------------------------------------------

    function setUp() public override {
        super.setUp();

        // Expose all public functions in this contract to the invariant fuzzer
        targetContract(address(this));
    }

    //----------------------x----------------------------------------------------------------------------
    // Handler functions (targets for the fuzzer)
    //--------------------------------------------------------------------------------------------------

    /// @notice Mint a new NFT at a fuzzed price within bounds
    function mint(uint256 aPrice) public {
        uint256 lPrice = bound(aPrice, 0, Constants.MAX_SUPPORTED_PRICE * 10);

        vm.prank(_alice);
        _erc721Harberger.mint(lPrice);

        _mintedTokenIds.push(_nextTokenId);
        unchecked {
            ++_nextTokenId;
        }
    }

    /// @notice Owner adjusts the price of an existing NFT
    function setPrice(uint256 aTokenId, uint256 aNewPrice) public {
        if (_mintedTokenIds.length == 0) return;

        uint256 lTokenId = aTokenId % _mintedTokenIds.length;
        uint256 lPrice = bound(aNewPrice, 0, Constants.MAX_SUPPORTED_PRICE * 10);

        address lOwner = _erc721Harberger.ownerOf(lTokenId);

        vm.prank(lOwner);
        _erc721Harberger.setPrice(lTokenId, lPrice);
    }

    /// @notice A different user buys an NFT if possible
    function buy(uint256 aTokenId) public {
        if (_mintedTokenIds.length == 0) return;

        uint256 lTokenId = aTokenId % _mintedTokenIds.length;
        address lOwner = _erc721Harberger.ownerOf(lTokenId);
        address lBuyer = lOwner == _alice ? _bob : _alice;

        vm.startPrank(lBuyer);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        // Max price is set to max uint so the call reverts only if other protocol
        // conditions are violated (e.g., delinquency), which is acceptable for the fuzzer.
        _erc721Harberger.buy(lTokenId, type(uint256).max);
        vm.stopPrank();
    }

    //--------------------------------------------------------------------------------------------------
    // Invariants
    //--------------------------------------------------------------------------------------------------

    /// @notice Ensure all declared prices always stay within the protocol bounds
    function invariant_AllPricesWithinBounds() public view {
        for (uint256 i; i < _mintedTokenIds.length; ++i) {
            uint256 lPrice = _erc721Harberger.getPrice(_mintedTokenIds[i]);
            assertTrue(lPrice >= Constants.MIN_NFT_PRICE && lPrice <= Constants.MAX_SUPPORTED_PRICE);
        }
    }

    function invariant_NFTsShouldNotBeOwnedByContract() public view {
        for (uint256 i; i < _mintedTokenIds.length; ++i) {
            address lOwner = _erc721Harberger.ownerOf(_mintedTokenIds[i]);
            assertNotEq(lOwner, address(_erc721Harberger));
        }
    }
}
