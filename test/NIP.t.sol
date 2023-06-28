// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {NIP} from "../src/NIP.sol";

contract NIPTest is Test {
    NIP private nip;

    address constant USER = address(0x1);
    address constant MINTER = address(0x2);
    address constant BURNER = address(0x3);
    address constant PAUSER = address(0x4);
    uint256 constant AMOUNT = 1000;

    function setUp() public {
        nip = new NIP();
        nip.grantRole(nip.MINTER_ROLE(), MINTER);
        nip.grantRole(nip.BURNER_ROLE(), BURNER);
        nip.grantRole(nip.PAUSER_ROLE(), PAUSER);
    }

    function testMint() public {
        vm.startPrank(MINTER);

        assertEq(nip.totalSupply(), 0);
        assertEq(nip.balanceOf(USER), 0);
        nip.mint(USER, AMOUNT);
        assertEq(nip.totalSupply(), AMOUNT);
        assertEq(nip.balanceOf(USER), AMOUNT);

        changePrank(USER);
        vm.expectRevert(); // USER does not have MINTER_ROLE
        nip.mint(USER, AMOUNT);
    }

    function testBurn() public {
        nip.mint(USER, AMOUNT);

        vm.startPrank(USER);
        nip.burn(AMOUNT/2);
        assertEq(nip.totalSupply(), AMOUNT/2);
        assertEq(nip.balanceOf(USER), AMOUNT/2);
        
        changePrank(BURNER);
        nip.burnFrom(USER, AMOUNT/2);
        assertEq(nip.totalSupply(), 0);
        assertEq(nip.balanceOf(USER), 0);

        changePrank(USER);
        deal(address(nip), USER, AMOUNT);
        vm.expectRevert(); // USER does not have BURNER_ROLE
        nip.burnFrom(USER, AMOUNT);
    }

    function testPause() public {
        vm.startPrank(USER);
        vm.expectRevert(); // USER does not have PAUSER_ROLE
        nip.pause();

        vm.startPrank(PAUSER);
        nip.pause();

        changePrank(MINTER);
        vm.expectRevert("Pausable: paused");
        nip.mint(USER, AMOUNT);

        changePrank(PAUSER);
        vm.expectRevert("Pausable: paused");
        nip.pause();

        nip.unpause();

        changePrank(MINTER);
        nip.mint(USER, AMOUNT);

        changePrank(USER);
        vm.expectRevert(); // USER does not have PAUSER_ROLE
        nip.pause();
    }

    function testPermit() public {
        uint256 BOB_PRIVATE_KEY = 0x123;
        address BOB = vm.addr(BOB_PRIVATE_KEY);
        uint256 deadline = block.timestamp + 60;

        deal(address(nip), BOB, AMOUNT);

        bytes32 permitHash = _getPermitHash(
            BOB,
            USER,
            AMOUNT,
            nip.nonces(BOB),
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BOB_PRIVATE_KEY, permitHash);

        assertEq(nip.allowance(BOB, USER), 0);
        nip.permit(BOB, USER, AMOUNT, deadline, v, r, s);
        assertEq(nip.allowance(BOB, USER), AMOUNT);
    }

    function _getPermitHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) private view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            keccak256(
                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
            ),
            owner,
            spender,
            value,
            nonce,
            deadline
        ));
        // Ethereum Signed Typed Data. This produces hash corresponding
        // to the one signed with the
        // https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
        // JSON-RPC method as part of EIP-712.
        return keccak256(abi.encodePacked(
            "\x19\x01",
            nip.DOMAIN_SEPARATOR(),
            structHash
        ));
    }
}