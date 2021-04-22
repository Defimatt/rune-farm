pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./lib/token/BEP20/IBEP20.sol";
import "./lib/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ArcaneItems is ERC721, Ownable {
    using Counters for Counters.Counter;

    // Map the number of tokens per itemId
    mapping(uint16 => uint256) public itemCount;

    // Map the number of tokens burnt per itemId
    mapping(uint16 => uint256) public itemBurnCount;

    // Used for generating the tokenId of new NFT minted
    // Counters.Counter private _tokenIds;

    // Map the itemId for each tokenId
    mapping(uint256 => uint16) public itemIds;

    // Map the itemName for a tokenId
    mapping(uint16 => string) public itemNames;

    constructor(string memory _baseURI) public ERC721("Arcane Items", "AI") {
        _setBaseURI(_baseURI);
    }

    /**
     * @dev Get itemId for a specific tokenId.
     */
    function getItemId(uint256 _tokenId) external view returns (uint16) {
        return itemIds[_tokenId];
    }

    /**
     * @dev Get the associated itemName for a specific itemId.
     */
    function getItemName(uint16 _itemId)
        external
        view
        returns (string memory)
    {
        return itemNames[_itemId];
    }

    /**
     * @dev Get the associated itemName for a unique tokenId.
     */
    function getItemNameOfTokenId(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        uint16 itemId = itemIds[_tokenId];
        return itemNames[itemId];
    }

    /**
     * @dev Mint NFTs. Only the owner can call it.
     */
    function mint(
        address _to,
        string calldata _tokenURI,
        uint16 _itemId,
        uint256 _tokenId
    ) external onlyOwner returns (uint256) {
        // uint256 newId = _tokenIds.current();
        // _tokenIds.increment();
        itemIds[_tokenId] = _itemId;
        itemCount[_itemId] = itemCount[_itemId].add(1);
        _mint(_to, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        return _tokenId;
    }

    /**
     * @dev Set a unique name for each itemId. It is supposed to be called once.
     */
    function setItemName(uint16 _itemId, string calldata _name)
        external
        onlyOwner
    {
        itemNames[_itemId] = _name;
    }

    /**
     * @dev Burn a NFT token. Callable by owner only.
     */
    function burn(uint256 _tokenId) external onlyOwner {
        uint16 itemIdBurnt = itemIds[_tokenId];
        itemCount[itemIdBurnt] = itemCount[itemIdBurnt].sub(1);
        itemBurnCount[itemIdBurnt] = itemBurnCount[itemIdBurnt].add(1);
        _burn(_tokenId);
    }
}