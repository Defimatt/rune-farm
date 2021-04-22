pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/token/BEP20/BEP20.sol";
import "../lib/token/BEP20/SafeBEP20.sol";
import "../runes/Nef.sol";

contract NefVoid {
    using SafeMath for uint256;

    NefRune public rune;
    address public devAddress;

    constructor(
        NefRune _rune,
        address _devAddress
    ) public {
        rune = _rune;
        devAddress = _devAddress;
    }

    function rune_proxy_setFeeInfo(address _vaultAddress, address _charityAddress, address _devAddress, address _botAddress, uint256 _vaultFee, uint256 _charityFee, uint256 _devFee, uint256 _botFee) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        rune.setFeeInfo(_vaultAddress, _charityAddress, _devAddress, _botAddress, _vaultFee, _charityFee, _devFee, _botFee);
    }

    function proxy_addExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addExcluded(_account);
    }

    function proxy_removeExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeExcluded(_account);
    }

    function proxy_addBot(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addBot(_account);
    }

    function proxy_removeBot(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeBot(_account);
    }
}