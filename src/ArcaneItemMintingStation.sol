
pragma solidity ^0.6.0;

import "./lib/math/SafeMath.sol";
import "./lib/token/BEP20/IBEP20.sol";
import "./lib/token/BEP20/SafeBEP20.sol";
import "./lib/access/Ownable.sol";
import "./lib/access/AccessControl.sol";

import "./ArcaneItems.sol";

/** @title ArcaneItemMintingStation.
@dev It is a contract that allow different factories to mint
Arcane Collectibles/Items.
*/

contract ArcaneItemMintingStation is AccessControl {
    ArcaneItems public arcaneItems;

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

    constructor(ArcaneItems _arcaneItems) public {
        arcaneItems = _arcaneItems;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev Mint NFTs from the ArcaneItems contract.
     * Users can specify what itemId they want to mint. Users can claim once.
     * There is a limit on how many are distributed. It requires RUNE balance to be > 0.
     */
    function mint(
        address _tokenReceiver,
        string calldata _tokenURI,
        uint8 _itemId,
        uint256 _tokenId
    ) external onlyMinter returns (uint256) {
        uint256 tokenId =
            arcaneItems.mint(_tokenReceiver, _tokenURI, _itemId, _tokenId);
        return tokenId;
    }

    /**
     * @dev Set up names for items.
     * Only the main admins can set it.
     */
    function setItemName(uint8 _itemId, string calldata _itemName)
        external
        onlyOwner
    {
        arcaneItems.setItemName(_itemId, _itemName);
    }

    /**
     * @dev It transfers the ownership of the NFT contract
     * to a new address.
     * Only the main admins can set it.
     */
    function changeOwnershipNFTContract(address _newOwner) external onlyOwner {
        arcaneItems.transferOwnership(_newOwner);
    }
}