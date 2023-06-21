// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EsOVL} from "../src/EsOVL.sol";
import {OVL} from "../src/OVL.sol";

contract EsOVLTest is Test {
    EsOVL public esOVL;

    OVL public ovl;

    address public constant OWNER = address(0x1);
    address public constant USER = address(0x2);
    uint256 public constant TOTAL_SUPPLY = 1000;
    uint256 public constant RELEASE_TIMESTAMP = 6123215;

    function setUp() public {
        vm.startPrank(OWNER);

        ovl = new OVL();
        esOVL = new EsOVL(ovl, RELEASE_TIMESTAMP);

        assertEq(esOVL.owner(), OWNER);

        deal(address(ovl), OWNER, TOTAL_SUPPLY);
        ovl.approve(address(esOVL), TOTAL_SUPPLY);
        esOVL.mint(TOTAL_SUPPLY);
    }

    function testMint() public {
        // OWNER mints TOTAL_SUPPLY in the setUp function
        assertEq(esOVL.totalSupply(), TOTAL_SUPPLY);
        assertEq(esOVL.balanceOf(OWNER), TOTAL_SUPPLY);
        assertEq(ovl.balanceOf(address(esOVL)), TOTAL_SUPPLY);
        assertEq(ovl.balanceOf(OWNER), 0);

        changePrank(USER);
        vm.expectRevert();
        esOVL.mint(TOTAL_SUPPLY);
    }

    function testUpdateReleaseTimestamp() public {
        uint256 newTimestamp = 2*RELEASE_TIMESTAMP;
        esOVL.updateReleaseTimestamp(newTimestamp);
        assertEq(esOVL.releaseTimestamp(), newTimestamp);
        
        changePrank(USER);
        vm.expectRevert();
        esOVL.updateReleaseTimestamp(newTimestamp);
    }

    function testRedeem() public {
        vm.warp(RELEASE_TIMESTAMP - 1);

        uint256 userBalance = 100;
        esOVL.transfer(USER, userBalance);

        vm.expectRevert(abi.encodePacked(
            EsOVL.TimestampNotReached.selector,
            RELEASE_TIMESTAMP,
            RELEASE_TIMESTAMP - 1
        ));
        esOVL.redeem();

        vm.warp(RELEASE_TIMESTAMP);
        
        esOVL.redeem();
        assertEq(esOVL.balanceOf(OWNER), 0);
        
        changePrank(USER);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), userBalance);
        assertEq(esOVL.balanceOf(USER), 0);

        assertEq(ovl.balanceOf(address(esOVL)), 0);
        assertEq(esOVL.totalSupply(), 0);
    }
}
