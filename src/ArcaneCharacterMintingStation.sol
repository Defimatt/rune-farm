pragma solidity ^0.6.0;

import "./ArcaneCharacters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/** @title ArcaneCharacterMintingStation.
@dev It is a contract that allow different factories to mint
Arcane Collectibles/Characters.
*/

contract ArcaneCharacterMintingStation is AccessControl {
    ArcaneCharacters public arcaneCharacters;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Modifier for minting roles
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Not a minting role");
        _;
    }

    // Modifier for admin roles
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an admin role");
        _;
    }

    constructor(ArcaneCharacters _arcaneCharacters) public {
        arcaneCharacters = _arcaneCharacters;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev Mint NFTs from the ArcaneCharacters contract.
     * Users can specify what characterId they want to mint. Users can claim once.
     * There is a limit on how many are distributed. It requires RUNE balance to be > 0.
     */
    function mintCollectible(
        address _tokenReceiver,
        string calldata _tokenURI,
        uint8 _characterId
    ) external onlyMinter returns (uint256) {
        uint256 tokenId =
            arcaneCharacters.mint(_tokenReceiver, _tokenURI, _characterId);
        return tokenId;
    }

    /**
     * @dev Set up names for characters.
     * Only the main admins can set it.
     */
    function setCharacterName(uint8 _characterId, string calldata _characterName)
        external
        onlyOwner
    {
        arcaneCharacters.setCharacterName(_characterId, _characterName);
    }

    /**
     * @dev It transfers the ownership of the NFT contract
     * to a new address.
     * Only the main admins can set it.
     */
    function changeOwnershipNFTContract(address _newOwner) external onlyOwner {
        arcaneCharacters.transferOwnership(_newOwner);
    }
}
