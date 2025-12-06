pragma solidity ^0.8.28;

import { ERC721Test, Constants, Errors, console } from "./ERC721.t.sol";

contract HarbergerTest is ERC721Test {
    function test_isDelinquent() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);

        // act
        bool lIsDelinquent = _erc721Harberger.isDelinquent(0);

        // assert
        assertEq(lIsDelinquent, true);
    }

    function test_seize() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);

        // act
        _erc721Harberger.seizeDelinquentNft(0);

        // assert
        assertEq(_erc721Harberger.ownerOf(0), address(_erc721Harberger));
        assertEq(_erc721Harberger.isSeized(0), true);
        assertEq(_erc721Harberger.isDelinquent(0), true);
    }

    function test_seize_cannot_seize_during_tax_epoch_and_grace_period() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION);

        // act & assert
        vm.expectPartialRevert(Errors.NFTNotDelinquent.selector);
        _erc721Harberger.seizeDelinquentNft(0);

        // arrange
        _stepTime(Constants.GRACE_PERIOD);

        // act & assert
        vm.expectPartialRevert(Errors.NFTNotDelinquent.selector);
        _erc721Harberger.seizeDelinquentNft(0);
    }

    function test_seize_already_seized_nft() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);
        _erc721Harberger.seizeDelinquentNft(0);

        // act & assert
        vm.expectRevert(Errors.NFTAlreadySeized.selector);
        _erc721Harberger.seizeDelinquentNft(0);
    }

    function test_buy_during_tax_epoch() external {


        // assert
        // check that taxes refunded
    }
    function test_buy_during_grace_period() external {
        // check that taxes not refunded
    }
    function test_buy_during_auction_period() external {
        // check taxes not refunded to prev owner
    }
    function test_buy_during_post_auction_period() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION * 3);
        _erc721Harberger.seizeDelinquentNft(0);

        // act
        _erc721Harberger.buy(0, Constants.MIN_NFT_PRICE);

        // check that it's at the min price
        // check that taxes not refunded to prev owner
    }

    function test_buy_max_price_exceeded(uint256 aPrice) external {
        // assume
        uint256 lPrice = bound(aPrice, Constants.MIN_NFT_PRICE + 1, _tokenA.balanceOf(_alice) / 2);

        // arrange
        test_mint(lPrice);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);
        _erc721Harberger.seizeDelinquentNft(0);

        // act & assert
        vm.expectRevert(Errors.MaxPriceIncludingTaxesExceeded.selector);
        _erc721Harberger.buy(0, lPrice);
    }

    function test_buy_own_nft() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.BuyingOwnNFT.selector);
        _erc721Harberger.buy(0, Constants.MIN_NFT_PRICE);
    }

    function test_buy_non_seized_nft() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);

        // act & assert
        vm.expectRevert(Errors.BuyingNonSeizedNFT.selector);
        _erc721Harberger.buy(0, Constants.MIN_NFT_PRICE);
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
