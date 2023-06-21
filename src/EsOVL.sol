// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract EsOVL is ERC20, Ownable {
    using SafeERC20 for IERC20;

    uint256 public releaseTimestamp;
    IERC20 public ovl;

    error TimestampNotReached(uint256 releaseTimestamp, uint256 currentTimestamp);

    constructor(
        IERC20 _ovl,
        uint256 _releaseTimestamp
    ) ERC20("esOVL", "esOVL") {
        ovl = _ovl;
        releaseTimestamp = _releaseTimestamp;
    }

    /// @notice Allows the owner to mint esOVL, having to deposit OVL in exchange.
    function mint(uint256 amount) external onlyOwner {
        ovl.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function updateReleaseTimestamp(uint256 _releaseTimestamp) external onlyOwner {
        releaseTimestamp = _releaseTimestamp;
    }

    /// @notice Allows users to redeem their esOVL for OVL after the release timestamp.
    function redeem() external {
        if (block.timestamp < releaseTimestamp)
            revert TimestampNotReached(releaseTimestamp, block.timestamp);
        
        uint256 balance = balanceOf(msg.sender);
        _burn(msg.sender, balance);
        ovl.safeTransfer(msg.sender, balance);
    }
}
