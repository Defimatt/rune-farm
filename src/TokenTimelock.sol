// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/math/SafeMath.sol";
import "./lib/token/IBEP20.sol";
import "./lib/token/SafeBEP20.sol";

contract TokenTimelock {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IBEP20 public token;
    uint256 public releaseTime = now + 180 days;
    address public beneficiary;

    constructor(
        IBEP20 _token,
        address _beneficiary
    ) public {
        token = _token;
        beneficiary = _beneficiary;
    }

    function release() external {
        require(now >= releaseTime, "TokenTimelock: current time is before release time");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");
        token.safeTransfer(beneficiary, amount);
    }

    function specificRelease(IBEP20 _token) external {
        require(now >= releaseTime, "TokenTimelock: current time is before release time");
        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");
        _token.safeTransfer(beneficiary, amount);
    }
}