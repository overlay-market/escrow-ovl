// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/NIP.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address ADMIN = address(0x85f66DBe1ed470A091d338CFC7429AA871720283);

        /*NIP nip = */new NIP(ADMIN);

        vm.stopBroadcast();
    }
}
