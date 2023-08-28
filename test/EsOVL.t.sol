// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {EsOVL} from "../src/EsOVL.sol";
import {OVL} from "../src/OVL.sol";

contract EsOVLTest is Test {
    EsOVL public esOVL;

    OVL public ovl;

    address public OWNER;
    address public constant USER = address(0x1);
    address public constant BOB = address(0x2);
    address public constant DISTRIBUTOR = address(0x3);
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

        esOVL.grantRole(esOVL.DISTRIBUTOR_ROLE(), DISTRIBUTOR);

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

    function testRedeem() public {
        esOVL.mintTo(USER, AMOUNT);
        assertEq(ovl.balanceOf(USER), 0);

        vm.startPrank(USER);

        // Vesting period not started
        vm.warp(START - 1);
        assertEq(esOVL.releasable(USER), 0);
        assertEq(esOVL.vestedAmount(uint64(block.timestamp), USER), 0);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), 0);
        assertEq(esOVL.balanceOf(USER), AMOUNT);
        assertEq(esOVL.totalSupply(), AMOUNT);
        assertEq(ovl.balanceOf(address(esOVL)), AMOUNT);

        // 1/2 of vesting period passed
        vm.warp(START + DURATION/2);
        assertEq(esOVL.releasable(USER), AMOUNT/2);
        assertEq(esOVL.vestedAmount(uint64(block.timestamp), USER), AMOUNT/2);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), AMOUNT/2);
        assertEq(esOVL.balanceOf(USER), AMOUNT/2);
        assertEq(esOVL.totalSupply(), AMOUNT/2);
        assertEq(ovl.balanceOf(address(esOVL)), AMOUNT/2);

        // 3/4 of vesting period passed
        vm.warp(START + (DURATION * 3) / 4);
        assertEq(esOVL.releasable(USER), (AMOUNT * 1) / 4);
        assertEq(esOVL.vestedAmount(uint64(block.timestamp), USER), (AMOUNT * 3) / 4);
        vm.expectEmit();
        emit OVLRedeemed(USER, (AMOUNT * 1) / 4);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), AMOUNT * 3 / 4);
        assertEq(esOVL.balanceOf(USER), (AMOUNT * 1) / 4);
        assertEq(esOVL.totalSupply(), (AMOUNT * 1) / 4);
        assertEq(ovl.balanceOf(address(esOVL)), (AMOUNT * 1) / 4);

        // Vesting period passed
        vm.warp(START + DURATION);
        assertEq(esOVL.releasable(USER), (AMOUNT * 1) / 4);
        assertEq(esOVL.vestedAmount(uint64(block.timestamp), USER), AMOUNT);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), AMOUNT);
        assertEq(esOVL.balanceOf(USER), 0);
        assertEq(esOVL.totalSupply(), 0);
        assertEq(ovl.balanceOf(address(esOVL)), 0);

        // Vesting period passed
        vm.warp(START + DURATION + 1);
        deal(address(ovl), USER, AMOUNT);
        ovl.approve(address(esOVL), AMOUNT);
        esOVL.mintTo(USER, AMOUNT);
        assertEq(ovl.balanceOf(USER), 0);
        assertEq(esOVL.releasable(USER), AMOUNT);
        assertEq(esOVL.vestedAmount(uint64(block.timestamp), USER), AMOUNT*2);
        esOVL.redeem();
        assertEq(ovl.balanceOf(USER), AMOUNT);
        assertEq(esOVL.balanceOf(USER), 0);
    }

    function testPause() public {
        vm.startPrank(USER);
        vm.expectRevert(); // USER does not have PAUSER_ROLE
        esOVL.pause();

        changePrank(OWNER);
        esOVL.mintTo(USER, AMOUNT/2);
        esOVL.pause();

        vm.expectRevert("Pausable: paused");
        esOVL.mintTo(USER, AMOUNT/2);

        changePrank(USER);
        vm.expectRevert("Pausable: paused");
        esOVL.redeem();

        changePrank(OWNER);
        vm.expectRevert("Pausable: paused");
        esOVL.pause();

        esOVL.unpause();

        changePrank(USER);
        esOVL.redeem();
    }

    function testDistributorRole() public {
        deal(address(esOVL), USER, AMOUNT);

        vm.startPrank(USER);
        vm.expectRevert(EsOVL.NotDistributor.selector);
        esOVL.transfer(BOB, AMOUNT);
        
        esOVL.transfer(DISTRIBUTOR, AMOUNT);
        assertEq(esOVL.balanceOf(DISTRIBUTOR), AMOUNT);
        assertEq(esOVL.balanceOf(USER), 0);

        changePrank(DISTRIBUTOR);
        esOVL.transfer(USER, AMOUNT);
        assertEq(esOVL.balanceOf(DISTRIBUTOR), 0);
        assertEq(esOVL.balanceOf(USER), AMOUNT);
    }
}
