pragma solidity ^0.8.28;

import { ERC721Test, Constants, Errors } from "./ERC721.t.sol";
import { console } from "../../lib/forge-std/src/Test.sol";
import { IERC721Errors } from "../../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { Utils } from "../../src/libraries/Utils.sol";

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

    function test_buy_during_tax_epoch(uint256 aFastForward) external {
        // assume
        uint256 lFastForward = bound(aFastForward, 1, Constants.TAX_EPOCH_DURATION - 1);

        // arrange
        uint256 lPrice = Constants.MIN_NFT_PRICE * 2;
        test_mint(lPrice);
        _stepTime(lFastForward);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, lPrice * 3 / 2);

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), lPrice);
        assertGt(_tokenA.balanceOf(_alice), lAliceBal);
    }

    function test_buy_during_grace_period() external {
        // arrange
        uint256 lPrice = Constants.MIN_NFT_PRICE * 2;
        test_mint(lPrice);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);
        uint256 lBobBal = _tokenA.balanceOf(_bob);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, lPrice * 3 / 2);

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), lPrice);
        assertEq(_tokenA.balanceOf(_bob), lBobBal - lPrice - Utils.calcTaxDue(lPrice, 1e12, _erc721Harberger.taxRate()));
        // Alice got exactly the price back
        assertEq(_tokenA.balanceOf(_alice), lAliceBal + lPrice);
    }

    function test_buy_during_auction_period() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE * 5);
        _stepTime(Constants.TAX_EPOCH_DURATION * 2);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);
        uint256 lBobBal = _tokenA.balanceOf(_bob);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, Constants.MIN_NFT_PRICE * 2);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), Constants.MIN_NFT_PRICE);
        assertEq(
            _tokenA.balanceOf(_bob),
            lBobBal - Constants.MIN_NFT_PRICE
                - Utils.calcTaxDue(Constants.MIN_NFT_PRICE, 1e12, _erc721Harberger.taxRate())
        );
        assertEq(_tokenA.balanceOf(_alice), lAliceBal);
    }

    function test_buy_during_post_auction_period() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE * 5);
        uint256 lAliceStartingBal = _tokenA.balanceOf(_alice);
        _stepTime(Constants.TAX_EPOCH_DURATION * 3);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, Constants.MIN_NFT_PRICE * 2);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), Constants.MIN_NFT_PRICE);
        assertGt(_tokenA.balanceOf(address(_erc721Harberger)), Constants.MIN_NFT_PRICE);
        assertEq(_tokenA.balanceOf(_alice), lAliceStartingBal);
    }

    // Someone can snipe the NFT as soon as it's minted
    // The original should be compensated in full, price + taxes
    function test_buy_same_block_as_mint(uint256 aMintPrice) external {
        // arrange
        test_mint(aMintPrice);
        uint256 lMintPrice = _erc721Harberger.getPrice(0);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);
        uint256 lBobBal = _tokenA.balanceOf(_bob);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, lMintPrice * 11 / 10);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), lMintPrice);
        assertEq(
            _tokenA.balanceOf(_bob),
            lBobBal - lMintPrice - Utils.calcTaxDue(lMintPrice, 1e12, _erc721Harberger.taxRate())
        );
        assertEq(
            _tokenA.balanceOf(_alice),
            lAliceBal + lMintPrice + Utils.calcTaxDue(lMintPrice, 1e12, _erc721Harberger.taxRate())
        );
    }

    function test_mint_then_lower_tax_rate_then_buy(uint256 aNewLowerTaxRate, uint256 aFastFoward) external {
        // assume
        uint256 lFastForward = bound(aFastFoward, 1, Constants.TAX_EPOCH_DURATION - 1);
        uint256 lNewLowerTaxRate = bound(aNewLowerTaxRate, 0, _erc721Harberger.taxRate() - 1);

        // arrange
        uint256 lAliceStartingAmt = _tokenA.balanceOf(_alice);
        uint256 lMintPrice = Constants.MIN_NFT_PRICE * 100;
        test_mint(lMintPrice);

        _stepTime(lFastForward);
        _erc721Harberger.setTaxRate(lNewLowerTaxRate);

        // act
        vm.startPrank(_bob);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
        _erc721Harberger.buy(0, lMintPrice * 11 / 10);
        vm.stopPrank();

        // assert
        assertEq(_erc721Harberger.ownerOf(0), _bob);
        assertEq(_erc721Harberger.balanceOf(_bob), 1);
        assertEq(_erc721Harberger.getPrice(0), lMintPrice);
        // Alice would have lost out a little
        assertLt(_tokenA.balanceOf(_alice), lAliceStartingAmt);
    }

    function test_buy_max_price_exceeded(uint256 aPrice) external {
        // assume
        uint256 lPrice = bound(aPrice, Constants.MIN_NFT_PRICE + 1, _tokenA.balanceOf(_alice) / 2);

        // arrange
        test_mint(lPrice);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);

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

    function test_getPrice() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(vm.randomAddress());
        assertEq(_erc721Harberger.getPrice(0), Constants.MIN_NFT_PRICE);
    }

    function test_getPrice_nonexistent_token(uint256 aTokenId) external {
        // assume
        vm.assume(aTokenId != 0);

        // act & assert
        vm.expectPartialRevert(IERC721Errors.ERC721NonexistentToken.selector);
        _erc721Harberger.getPrice(aTokenId);
    }

    function test_setPrice_Higher(uint256 aNewPrice) external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE * 2);
        _stepTime(Constants.TAX_EPOCH_DURATION / 2);
        uint256 lOriginalPrice = _erc721Harberger.getPrice(0);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);
        uint256 lContractBal = _tokenA.balanceOf(address(_erc721Harberger));

        // assume
        uint256 lNewPrice = bound(aNewPrice, lOriginalPrice + 1, _tokenA.balanceOf(_alice) * 8 / 10);

        // act
        vm.prank(_alice);
        _erc721Harberger.setPrice(0, lNewPrice);

        // assert
        assertEq(_erc721Harberger.getPrice(0), lNewPrice);
        assertLt(_tokenA.balanceOf(_alice), lAliceBal);
        assertGt(_tokenA.balanceOf(address(_erc721Harberger)), lContractBal);
    }

    function test_setPrice_Lower(uint256 aOriginalPrice) external {
        // arrange
        test_mint(aOriginalPrice);
        _stepTime(Constants.TAX_EPOCH_DURATION);
        uint256 lContractBal = _tokenA.balanceOf(address(_erc721Harberger));

        // assume
        uint256 lNewPrice = Constants.MIN_NFT_PRICE;

        // act
        vm.prank(_alice);
        _erc721Harberger.setPrice(0, lNewPrice);

        // assert
        assertEq(_erc721Harberger.getPrice(0), lNewPrice);
        // contract should never lose/refund money
        assertGe(_tokenA.balanceOf(address(_erc721Harberger)), lContractBal);
    }

    function test_setPrice_TooLow() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.NFTPriceTooLow.selector);
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE - 1);
    }

    function test_setPrice_delinquent() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD + 1);

        // act & assert
        vm.prank(_alice);
        vm.expectRevert(Errors.NFTIsDelinquent.selector);
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE);
    }

    function test_setPrice_same_price_during_grace_period() external {
        // arrange
        uint256 lPenalty = Utils.calcTaxDue(Constants.MIN_NFT_PRICE, 1e12, Constants.DEFAULT_TAX_RATE)
            * Constants.GRACE_PERIOD / Constants.TAX_EPOCH_DURATION;
        test_mint(Constants.MIN_NFT_PRICE);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD - 5);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);

        // act
        vm.prank(_alice);
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE);

        // assert
        uint256 lCurrentEpochTax = Utils.calcTaxDue(Constants.MIN_NFT_PRICE, 1e12, Constants.DEFAULT_TAX_RATE);
        assertEq(_tokenA.balanceOf(_alice), lAliceBal - lPenalty - lCurrentEpochTax);
    }

    function test_setPrice_lower_price_during_grace_period() external {
        // arrange
        uint256 lInitialPrice = Constants.MIN_NFT_PRICE * 10;
        uint256 lPenalty = Utils.calcTaxDue(lInitialPrice, 1e12, Constants.DEFAULT_TAX_RATE)
            * Constants.GRACE_PERIOD / Constants.TAX_EPOCH_DURATION;
        test_mint(lInitialPrice);
        _stepTime(Constants.TAX_EPOCH_DURATION + Constants.GRACE_PERIOD - 5);
        uint256 lAliceBal = _tokenA.balanceOf(_alice);

        // act
        vm.prank(_alice);
        // set price 90% lower
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE);

        // assert
        uint256 lCurrentEpochTax = Utils.calcTaxDue(Constants.MIN_NFT_PRICE, 1e12, Constants.DEFAULT_TAX_RATE);
        assertEq(_tokenA.balanceOf(_alice), lAliceBal - lPenalty - lCurrentEpochTax);
    }

    function test_setPrice_NotTokenOwner() external {
        // arrange
        test_mint(Constants.MIN_NFT_PRICE);

        // act & assert
        vm.prank(_bob);
        vm.expectRevert(Errors.NotTokenOwner.selector);
        _erc721Harberger.setPrice(0, Constants.MIN_NFT_PRICE);
    }

    function test_setPrice_nonexistent_token(uint256 aTokenId) external {
        // assume
        vm.assume(aTokenId != 0);

        // act & assert
        vm.expectPartialRevert(IERC721Errors.ERC721NonexistentToken.selector);
        _erc721Harberger.setPrice(aTokenId, Constants.MIN_NFT_PRICE);
    }
}
