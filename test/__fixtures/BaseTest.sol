// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ERC721Harberger, IERC20, Constants, Errors } from "../../src/ERC721Harberger.sol";
import { Test } from "forge-std/Test.sol";
import { MintableERC20 } from "./MintableERC20.sol";

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

    function _stepTime(uint256 aTime) internal {
        vm.roll(vm.getBlockNumber() + 1);
        vm.warp(vm.getBlockTimestamp() + aTime);
    }

    function setUp() public virtual {
        _tokenA = new MintableERC20("TokenA", "TA", 6);
        _tokenB = new MintableERC20("TokenB", "TB", 18);
        _erc721Harberger = new ERC721Harberger(address(this), IERC20(address(_tokenA)), address(this));

        _tokenA.mint(_alice, 1_000_000e6);
        _tokenA.mint(_bob, 1_000_000e6);
        _tokenA.mint(_cal, 1_000_000e6);

        vm.prank(_alice);
        _tokenA.approve(address(_erc721Harberger), type(uint256).max);
    }

    function test_PrecisionMultiplierCorrect() external {
        // arrange
        ERC721Harberger _erc721Harberger2 = new ERC721Harberger(address(this), IERC20(address(_tokenB)), address(this));

        // act
        uint256 lPrecisionMultiplier = _erc721Harberger.PAYMENT_TOKEN_PRECISION_MULTIPLIER();
        uint256 lPrecisionMultiplier2 = _erc721Harberger2.PAYMENT_TOKEN_PRECISION_MULTIPLIER();

        // assert
        assertEq(lPrecisionMultiplier, 1e12);
        assertEq(lPrecisionMultiplier2, 1);
    }
}
