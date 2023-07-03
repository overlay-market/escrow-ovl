// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/NIP.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address ADMIN = address(0x5985FD48b48fdde2C5c1BC0b4f591c83D961184B);

        /*NIP nip = */new NIP(ADMIN);

        vm.stopBroadcast();
    }
}
