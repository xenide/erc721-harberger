pragma solidity ^0.8.28;

import { ERC721Test, Constants, Errors } from "./ERC721.t.sol";

contract HarbergerTest is ERC721Test {
    function test_buy() external { }

    function test_buy_own_nft() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.BuyingOwnNFT.selector);
        _erc721Harberger.buy(0);
    }

    function test_buy_non_seized_nft() external {

    }

    function test_buy_already_seized_nft() external {

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
