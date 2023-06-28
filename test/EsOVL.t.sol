// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {EsOVL} from "../src/EsOVL.sol";
import {OVL} from "../src/OVL.sol";

contract EsOVLTest is Test {
    EsOVL public esOVL;

    OVL public ovl;

    address public OWNER;
    address public constant USER = address(0x2);
    uint256 public constant AMOUNT = 1000;
    uint64 public constant START = 1687877663;
    uint64 public constant DURATION = 30*24*60*60; // 30 days

    event VestingPeriodUpdated(uint64 start, uint64 duration);
    event ExcessOVLWithdrawn(address to, uint256 amount);
    event OVLRedeemed(address indexed to, uint256 amount);

    function setUp() public {
        OWNER = address(this);

        ovl = new OVL();
        esOVL = new EsOVL(ovl, START, DURATION);

        assertTrue(esOVL.hasRole(esOVL.DEFAULT_ADMIN_ROLE(), OWNER));
        assertEq(esOVL.end(), START + DURATION);

        deal(address(ovl), OWNER, AMOUNT);
        ovl.approve(address(esOVL), AMOUNT);
    }

    function testMintTo() public {
        vm.expectRevert(EsOVL.TransferToZeroAddress.selector);
        esOVL.mintTo(address(0), AMOUNT);

        esOVL.mintTo(USER, AMOUNT);
        assertEq(esOVL.totalSupply(), AMOUNT);
        assertEq(esOVL.balanceOf(USER), AMOUNT);
        assertEq(ovl.balanceOf(address(esOVL)), AMOUNT);
        assertEq(ovl.balanceOf(OWNER), 0);
    }

    function testUpdateVestingPeriod() public {
        uint64 newStart = START + 1000;
        uint64 newDuration = DURATION * 2;

        vm.expectEmit();
        emit VestingPeriodUpdated(newStart, newDuration);
        esOVL.updateVestingPeriod(newStart, newDuration);
        assertEq(esOVL.end(), newStart + newDuration);

        vm.startPrank(USER);
        vm.expectRevert(); // user does not have DEFAULT_ADMIN_ROLE
        esOVL.updateVestingPeriod(newStart, newDuration);
    }

    function testWithdrawExcessOVL() public {
        uint256 excess = 100;
        deal(address(ovl), address(esOVL), excess);

        esOVL.mintTo(OWNER, AMOUNT);
        assertEq(ovl.balanceOf(OWNER), 0);

        vm.expectEmit();
        emit ExcessOVLWithdrawn(OWNER, excess);
        esOVL.withdrawExcessOVL();
        assertEq(ovl.balanceOf(OWNER), excess);
        assertEq(ovl.balanceOf(address(esOVL)), AMOUNT);

        vm.startPrank(USER);
        vm.expectRevert(); // user does not have DEFAULT_ADMIN_ROLE
        esOVL.withdrawExcessOVL();
    }

    // TODO: adapt to linear vesting
    // function testRedeem() public {
    //     vm.warp(RELEASE_TIMESTAMP - 1);

    //     uint256 userBalance = 100;
    //     esOVL.transfer(USER, userBalance);

    //     vm.expectRevert(abi.encodePacked(
    //         EsOVL.TimestampNotReached.selector,
    //         RELEASE_TIMESTAMP,
    //         RELEASE_TIMESTAMP - 1
    //     ));
    //     esOVL.redeem();

    //     vm.warp(RELEASE_TIMESTAMP);
        
    //     esOVL.redeem();
    //     assertEq(esOVL.balanceOf(OWNER), 0);
        
    //     changePrank(USER);
    //     esOVL.redeem();
    //     assertEq(ovl.balanceOf(USER), userBalance);
    //     assertEq(esOVL.balanceOf(USER), 0);

    //     assertEq(ovl.balanceOf(address(esOVL)), 0);
    //     assertEq(esOVL.totalSupply(), 0);
    // }
}
