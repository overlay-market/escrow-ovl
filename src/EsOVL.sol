// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "openzeppelin/security/Pausable.sol";
import {AccessControl} from "openzeppelin/access/AccessControl.sol";

contract EsOVL is ERC20, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    error NotDistributor();
    error TransferToZeroAddress();

    event VestingPeriodUpdated(uint64 start, uint64 duration);
    event ExcessOVLWithdrawn(address to, uint256 amount);
    event OVLRedeemed(address indexed to, uint256 amount);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    IERC20 public immutable ovl;
    // Timestamp after which tokens will start vesting.
    uint64 public start;
    // Duration in seconds of the period in which the tokens will vest.
    uint64 public duration;
    // Amount of tokens already released for each account.
    mapping (address account => uint256 amount) public released;

    constructor(
        IERC20 _ovl,
        uint64 _start,
        uint64 _duration
    ) ERC20("esOVL", "esOVL") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        if (_ovl == IERC20(address(0))) revert TransferToZeroAddress();
        ovl = _ovl;
        start = _start;
        duration = _duration;
    }

    /// @notice Returns the timestamp at which the vesting period ends.
    /// All tokens will be reedemable after this timestamp.
    function end() public view returns (uint64) {
        return start + duration;
    }

    /// @notice Mints esOVL to `account` in exchange for depositing OVL.
    function mintTo(address account, uint256 amount) external {
        if (account == address(0)) revert TransferToZeroAddress();
        ovl.safeTransferFrom(msg.sender, address(this), amount);
        _mint(account, amount);
    }

    function updateVestingPeriod(uint64 _start, uint64 _duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        start = _start;
        duration = _duration;
        emit VestingPeriodUpdated(_start, _duration);
    }

    /// @notice Allows the owner to withdraw any excess OVL sent to the contract.
    function withdrawExcessOVL() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 excess = ovl.balanceOf(address(this)) - totalSupply();
        ovl.safeTransfer(msg.sender, excess);
        emit ExcessOVLWithdrawn(msg.sender, excess);
    }

    /// @notice Allows users to redeem their esOVL for OVL after the release timestamp.
    function redeem() external {
        uint256 amount = releasable();
        released[msg.sender] += amount;
        _burn(msg.sender, amount);
        ovl.safeTransfer(msg.sender, amount);
        emit OVLRedeemed(msg.sender, amount);
    }

    /// @notice Calculates the amount of esOVL that can currently be reedemed.
    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released[msg.sender];
    }

    /// @notice Calculates the amount of esOVL that has already vested.
    /// This includes the esOVL already reedemed.
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        return _vestingSchedule(balanceOf(msg.sender) + released[msg.sender], timestamp);
    }

    /// @dev Linear vesting curve.
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view returns (uint256) {
        if (timestamp < start) {
            return 0;
        } else if (timestamp > end()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start)) / duration;
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        if (from != address(0) && to != address(0) && !hasRole(DISTRIBUTOR_ROLE, from)) {
            revert NotDistributor();
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
