// SPDX-Licence-Identifier: MIT

pragma solidity 0.6.12;

import "../lib/token/BEP20/IBEP20.sol";
import "../lib/token/BEP20/BEP20.sol";
import "../lib/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BEP20Mock is BEP20 {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public BEP20(name, symbol) {
        _mint(msg.sender, supply);
    }
}