pragma solidity ^0.8.28;

import { BaseTest, Constants, Errors } from "../__fixtures/BaseTest.sol";
import { ERC20 } from "../__fixtures/MintableERC20.sol";

contract ERC721Test is BaseTest {
    function test_mint(uint256 aPrice) public {
        // assume
        uint256 lPrice = bound(aPrice, Constants.MIN_NFT_PRICE, _tokenA.balanceOf(_alice) / 2);

        // act
        vm.startPrank(_alice);
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
        assertEq(_erc721Harberger.balanceOf(_alice), 1);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.balanceOf(_cal), 1);
    }

    function test_mint_price_too_low() external {
        // act & assert
        vm.expectRevert(Errors.NFTPriceTooLow.selector);
        _erc721Harberger.mint(Constants.MIN_NFT_PRICE - 1);
    }

    function test_mint_no_approval() external {
        // act & assert
        vm.startPrank(_alice);
        _tokenA.approve(address(_erc721Harberger), 0);
        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        _erc721Harberger.mint(Constants.MIN_NFT_PRICE);
    }

    function test_transferFrom(uint256 aFastForward) external {
        // assume
        uint256 lFastForward = bound(aFastForward, 0, Constants.TAX_EPOCH_DURATION);

        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(lFastForward);
        vm.prank(_alice);
        _erc721Harberger.approve(address(_bob), 0);

        // act & assert
        vm.prank(_bob);
        _erc721Harberger.transferFrom(_alice, _bob, 0);
        assertEq(_erc721Harberger.ownerOf(0), _bob);
    }

    function test_transferFrom_delinquent() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);
        vm.prank(_alice);
        _erc721Harberger.approve(address(_bob), 0);

        // act & assert
        vm.prank(_bob);
        vm.expectRevert(Errors.NFTIsDelinquent.selector);
        _erc721Harberger.transferFrom(_alice, _bob, 0);
    }

    function test_transferFrom_during_grace_period() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + 1);
        vm.prank(_alice);
        _erc721Harberger.approve(address(_bob), 0);

        // act & assert
        vm.prank(_bob);
        vm.expectRevert(Errors.NFTInGracePeriod.selector);
        _erc721Harberger.transferFrom(_alice, _bob, 0);
    }
}
