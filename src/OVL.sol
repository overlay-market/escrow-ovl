// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract OVL is ERC20 {

    constructor() ERC20("OVL", "OVL") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

}