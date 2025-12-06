// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC721Harberger, IERC20, Constants, Errors } from "../src/ERC721Harberger.sol";
import { Test } from "forge-std/Test.sol";
import { MintableERC20, ERC20 } from "./__fixtures/MintableERC20.sol";

contract BaseTest is Test {
    ERC721Harberger internal _erc721Harberger;

    MintableERC20 internal _tokenA;
    MintableERC20 internal _tokenB;

    address internal _alice = _makeAddress("alice");
    address internal _bob = _makeAddress("bob");
    address internal _cal = _makeAddress("cal");

    function _makeAddress(string memory aName) internal returns (address) {
        address lAddress = address(uint160(uint256(keccak256(abi.encodePacked(aName)))));
        vm.label(lAddress, aName);

        return lAddress;
    }

    function setUp() public {
        _tokenA = new MintableERC20("TokenA", "TA", 6);
        _tokenB = new MintableERC20("TokenB", "TB", 18);
        _erc721Harberger = new ERC721Harberger(address(this), IERC20(address(_tokenA)), address(this));

        _tokenA.mint(_alice, 100e18);
        _tokenA.mint(_bob, 100e18);
        _tokenA.mint(_cal, 100e18);
    }

    function test_PrecisionMultiplierCorrect() external {
        // arrange
        ERC721Harberger _erc721Harberger2 =
            new ERC721Harberger(address(this), IERC20(address(_tokenB)), address(this));

        // act
        uint256 lPrecisionMultiplier = _erc721Harberger.PAYMENT_TOKEN_PRECISION_MULTIPLIER();
        uint256 lPrecisionMultiplier2 = _erc721Harberger2.PAYMENT_TOKEN_PRECISION_MULTIPLIER();

        // assert
        assertEq(lPrecisionMultiplier, 1e12);
        assertEq(lPrecisionMultiplier2, 1);
    }

    function test_mint(uint256 aPrice) public {
        // assume
        uint256 lPrice = bound(aPrice, Constants.MIN_NFT_PRICE, _tokenA.balanceOf(_alice) / 2);

        // arrange
        vm.startPrank(_alice);
        _tokenA.approve(address(_erc721Harberger), lPrice);

        // act
        _erc721Harberger.mint(lPrice);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _alice);
        assertEq(_erc721Harberger.getPrice(0), lPrice);
    }

    function test_mint_multiple(uint256 aPrice1, uint256 aPrice2, uint256 aPrice3) external {
        // assume
        uint256 lPrice1 = bound(aPrice1, Constants.MIN_NFT_PRICE, _tokenA.balanceOf(_alice));
        uint256 lPrice2 = bound(aPrice2, Constants.MIN_NFT_PRICE, _tokenA.balanceOf(_bob));
        uint256 lPrice3 = bound(aPrice3, Constants.MIN_NFT_PRICE, _tokenA.balanceOf(_cal));

        // act
        vm.startPrank(_alice);
        _tokenA.approve(address(_erc721Harberger), lPrice1);
        _erc721Harberger.mint(lPrice1);
        vm.stopPrank();

        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), lPrice2);
        _erc721Harberger.mint(lPrice2);
        vm.stopPrank();

        vm.startPrank(_cal);
        _tokenA.approve(address(_erc721Harberger), lPrice3);
        _erc721Harberger.mint(lPrice3);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _alice);
        assertEq(_erc721Harberger.ownerOf(1), _bob);
        assertEq(_erc721Harberger.ownerOf(2), _cal);
        assertEq(_erc721Harberger.getPrice(0), lPrice1);
        assertEq(_erc721Harberger.getPrice(1), lPrice2);
        assertEq(_erc721Harberger.getPrice(2), lPrice3);
    }

    function test_mint_price_too_low() external {
        // act & assert
        vm.expectRevert(Errors.NFTPriceTooLow.selector);
        _erc721Harberger.mint(Constants.MIN_NFT_PRICE - 1);
    }

    function test_mint_no_approval() external {
        // act & assert
        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        _erc721Harberger.mint(Constants.MIN_NFT_PRICE);
    }

    function test_buy() external {

    }

    function test_buy_own_nft() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.BuyingOwnNFT.selector);
        _erc721Harberger.buy(0);
    }

    function test_buy_insufficient_fund() external { }

    function test_setPrice_Higher(uint256 aOriginalPrice, uint256 aNewPrice) external {
        // arrange
        test_mint(aOriginalPrice);
        uint256 lOriginalPrice = _erc721Harberger.getPrice(0);

        // assume
        uint256 lNewPrice = bound(aNewPrice, lOriginalPrice + 1, _tokenA.balanceOf(_alice));

        // act
        vm.prank(_alice);
        _erc721Harberger.setPrice(0, lNewPrice);

        // assert
        assertEq(_erc721Harberger.getPrice(0), lNewPrice);
        // TODO: check taxes paid
    }

    function test_setPrice_Lower(uint256 aOriginalPrice) external {
        // arrange
        test_mint(aOriginalPrice);
        uint256 lOriginalPrice = _erc721Harberger.getPrice(0);

        // assume
        uint256 lNewPrice = Constants.MIN_NFT_PRICE;

        // act
        vm.prank(_alice);
        _erc721Harberger.setPrice(0, lNewPrice);

        // assert
        assertEq(_erc721Harberger.getPrice(0), lNewPrice);
        // TODO: check that no taxes paid / refunded
    }

    function test_setPrice_TooLow() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.NFTPriceTooLow.selector);
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE - 1);
    }
}
