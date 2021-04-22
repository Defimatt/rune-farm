pragma solidity ^0.6.12;

import "./ArcaneProfile.sol";
import "./ArcaneCharacterMintingStation.sol";

contract ArcaneCharacterSpecialV1 is Ownable {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    ArcaneCharacterMintingStation public characterMintingStation;
    ArcaneProfile public arcaneProfile;

    IBEP20 public runeToken;

    uint256 public maxViewLength;
    uint256 public numberDifferentCharacters;

    // Map if address for a characterId has already claimed a NFT
    mapping(address => mapping(uint8 => bool)) public hasClaimed;

    // Map if characterId to its characteristics
    mapping(uint8 => Characters) public characterCharacteristics;

    // Number of previous series (i.e. different visuals)
    uint8 private constant previousNumberCharacterIds = 10;

    struct Characters {
        string tokenURI; // e.g. ipfsHash/hiccups.json
        uint256 thresholdUser; // e.g. 1900 or 100000
        uint256 runeCost;
        bool isActive;
        bool isCreated;
    }

    // Event to notify a new character is mintable
    event CharacterAdd(
        uint8 indexed characterId,
        uint256 thresholdUser,
        uint256 costRune
    );

    // Event to notify one of the characters' requirements to mint differ
    event CharacterChange(
        uint8 indexed characterId,
        uint256 thresholdUser,
        uint256 costRune,
        bool isActive
    );

    // Event to notify when NFT is successfully minted
    event CharacterMint(
        address indexed to,
        uint256 indexed tokenId,
        uint8 indexed characterId
    );

    constructor(
        ArcaneCharacterMintingStation _characterMintingStation,
        IBEP20 _runeToken,
        ArcaneProfile _arcaneProfile,
        uint256 _maxViewLength
    ) public {
        characterMintingStation = _characterMintingStation;
        runeToken = _runeToken;
        arcaneProfile = _arcaneProfile;
        maxViewLength = _maxViewLength;
    }

    /**
     * @dev Mint NFTs from the ArcaneCharacterMintingStation contract.
     * Users can claim once.
     */
    function mintNFT(uint8 _characterId) external {
        // Check that the _characterId is within boundary
        require(_characterId >= previousNumberCharacterIds, "ERR_ID_LOW");
        require(characterCharacteristics[_characterId].isActive, "ERR_ID_INVALID");

        address senderAddress = _msgSender();

        // 1. Check _msgSender() has not claimed
        require(!hasClaimed[senderAddress][_characterId], "ERR_HAS_CLAIMED");

        uint256 userId;
        bool isUserActive;

        (userId, , , , , isUserActive) = arcaneProfile.getUserProfile(
            senderAddress
        );

        require(
            userId < characterCharacteristics[_characterId].thresholdUser,
            "ERR_USER_NOT_ELIGIBLE"
        );

        require(isUserActive, "ERR_USER_NOT_ACTIVE");

        // Check if there is any cost associated with getting the character
        if (characterCharacteristics[_characterId].runeCost > 0) {
            runeToken.safeTransferFrom(
                senderAddress,
                address(this),
                characterCharacteristics[_characterId].runeCost
            );
        }

        // Update that _msgSender() has claimed
        hasClaimed[senderAddress][_characterId] = true;

        uint256 tokenId =
            characterMintingStation.mintCollectible(
                senderAddress,
                characterCharacteristics[_characterId].tokenURI,
                _characterId
            );

        emit CharacterMint(senderAddress, tokenId, _characterId);
    }

    function addCharacter(
        uint8 _characterId,
        string calldata _tokenURI,
        uint256 _thresholdUser,
        uint256 _runeCost
    ) external onlyOwner {
        require(!characterCharacteristics[_characterId].isCreated, "ERR_CREATED");
        require(_characterId >= previousNumberCharacterIds, "ERR_ID_LOW_2");

        characterCharacteristics[_characterId] = Characters({
            tokenURI: _tokenURI,
            thresholdUser: _thresholdUser,
            runeCost: _runeCost,
            isActive: true,
            isCreated: true
        });

        numberDifferentCharacters = numberDifferentCharacters.add(1);

        emit CharacterAdd(_characterId, _thresholdUser, _runeCost);
    }

    /**
     * @dev It transfers the RUNE tokens back to the chef address.
     * Only callable by the owner.
     */
    function claimFee(uint256 _amount) external onlyOwner {
        runeToken.safeTransfer(_msgSender(), _amount);
    }

    function updateCharacter(
        uint8 _characterId,
        uint256 _thresholdUser,
        uint256 _runeCost,
        bool _isActive
    ) external onlyOwner {
        require(characterCharacteristics[_characterId].isCreated, "ERR_NOT_CREATED");
        characterCharacteristics[_characterId].thresholdUser = _thresholdUser;
        characterCharacteristics[_characterId].runeCost = _runeCost;
        characterCharacteristics[_characterId].isActive = _isActive;

        emit CharacterChange(_characterId, _thresholdUser, _runeCost, _isActive);
    }

    function updateMaxViewLength(uint256 _newMaxViewLength) external onlyOwner {
        maxViewLength = _newMaxViewLength;
    }

    function canClaimSingle(address _userAddress, uint8 _characterId)
        external
        view
        returns (bool)
    {
        if (!arcaneProfile.hasRegistered(_userAddress)) {
            return false;
        } else {
            uint256 userId;
            bool userStatus;

            (userId, , , , , userStatus) = arcaneProfile.getUserProfile(
                _userAddress
            );

            if (!userStatus) {
                return false;
            } else {
                bool claimStatus = _canClaim(_userAddress, userId, _characterId);
                return claimStatus;
            }
        }
    }

    function canClaimMultiple(address _userAddress, uint8[] calldata _characterIds)
        external
        view
        returns (bool[] memory)
    {
        require(_characterIds.length <= maxViewLength, "ERR_LENGTH_VIEW");

        if (!arcaneProfile.hasRegistered(_userAddress)) {
            bool[] memory responses = new bool[](0);
            return responses;
        } else {
            uint256 userId;
            bool userStatus;

            (userId, , , , , userStatus) = arcaneProfile.getUserProfile(
                _userAddress
            );

            if (!userStatus) {
                bool[] memory responses = new bool[](0);
                return responses;
            } else {
                bool[] memory responses = new bool[](_characterIds.length);

                for (uint256 i = 0; i < _characterIds.length; i++) {
                    bool claimStatus =
                        _canClaim(_userAddress, userId, _characterIds[i]);
                    responses[i] = claimStatus;
                }
                return responses;
            }
        }
    }

    /**
     * @dev Check if user can claim.
     * If the address hadn't set up a profile, it will return an error.
     */
    function _canClaim(
        address _userAddress,
        uint256 userId,
        uint8 _characterId
    ) internal view returns (bool) {
        uint256 characterThreshold = characterCharacteristics[_characterId].thresholdUser;
        bool characterActive = characterCharacteristics[_characterId].isActive;

        if (hasClaimed[_userAddress][_characterId]) {
            return false;
        } else if (!characterActive) {
            return false;
        } else if (userId >= characterThreshold) {
            return false;
        } else {
            return true;
        }
    }
}