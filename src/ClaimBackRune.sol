pragma solidity ^0.6.12;

import "./ArcaneProfile.sol";

contract ClaimBackRune is Ownable {
    using SafeBEP20 for IBEP20;

    IBEP20 public runeToken;
    ArcaneProfile arcaneProfile;

    uint256 public numberRune;
    uint256 public thresholdUser;

    mapping(address => bool) public hasClaimed;

    constructor(
        IBEP20 _runeToken,
        address _arcaneProfileAddress,
        uint256 _numberRune,
        uint256 _thresholdUser
    ) public {
        runeToken = _runeToken;
        arcaneProfile = ArcaneProfile(_arcaneProfileAddress);
        numberRune = _numberRune;
        thresholdUser = _thresholdUser;
    }

    function getRuneBack() external {
        // 1. Check if she has registered
        require(arcaneProfile.hasRegistered(_msgSender()), "not active");

        // 2. Check if she has claimed
        require(!hasClaimed[_msgSender()], "has claimed RUNE");

        // 3. Check if she is active
        uint256 userId;
        (userId, , , , , ) = arcaneProfile.getUserProfile(_msgSender());

        require(userId < thresholdUser, "not impacted");

        // Update status
        hasClaimed[_msgSender()] = true;

        // Transfer RUNE tokens from this contract
        runeToken.safeTransfer(_msgSender(), numberRune);
    }

    /**
     * @dev Claim RUNE back.
     * Callable only by owner admins.
     */
    function claimFee(uint256 _amount) external onlyOwner {
        runeToken.safeTransfer(_msgSender(), _amount);
    }

    function canClaim(address _userAddress) external view returns (bool) {
        if (!arcaneProfile.hasRegistered(_userAddress)) {
            return false;
        } else if (hasClaimed[_userAddress]) {
            return false;
        } else {
            uint256 userId;
            (userId, , , , , ) = arcaneProfile.getUserProfile(_userAddress);
            if (userId < thresholdUser) {
                return true;
            } else {
                return false;
            }
        }
    }
}