pragma solidity 0.6.12;

import "./lib/math/SafeMath.sol";
import "./lib/token/BEP20/IBEP20.sol";
import "./lib/token/BEP20/SafeBEP20.sol";
import "./lib/access/Ownable.sol";


contract ArcaneCharacters is ERC721, Ownable {
    using Counters for Counters.Counter;

    // Map the number of tokens per characterId
    mapping(uint8 => uint256) public characterCount;

    // Map the number of tokens burnt per characterId
    mapping(uint8 => uint256) public characterBurnCount;

    // Used for generating the tokenId of new NFT minted
    Counters.Counter private _tokenIds;

    // Map the characterId for each tokenId
    mapping(uint256 => uint8) private characterIds;

    // Map the characterName for a tokenId
    mapping(uint8 => string) private characterNames;

    constructor(string memory _baseURI) public ERC721("Arcane Characters", "AC") {
        _setBaseURI(_baseURI);
    }

    /**
     * @dev Get characterId for a specific tokenId.
     */
    function getCharacterId(uint256 _tokenId) external view returns (uint8) {
        return characterIds[_tokenId];
    }

    /**
     * @dev Get the associated characterName for a specific characterId.
     */
    function getCharacterName(uint8 _characterId)
        external
        view
        returns (string memory)
    {
        return characterNames[_characterId];
    }

    /**
     * @dev Get the associated characterName for a unique tokenId.
     */
    function getCharacterNameOfTokenId(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        uint8 characterId = characterIds[_tokenId];
        return characterNames[characterId];
    }

    /**
     * @dev Mint NFTs. Only the owner can call it.
     */
    function mint(
        address _to,
        string calldata _tokenURI,
        uint8 _characterId
    ) external onlyOwner returns (uint256) {
        uint256 newId = _tokenIds.current();
        _tokenIds.increment();
        characterIds[newId] = _characterId;
        characterCount[_characterId] = characterCount[_characterId].add(1);
        _mint(_to, newId);
        _setTokenURI(newId, _tokenURI);
        return newId;
    }

    /**
     * @dev Set a unique name for each characterId. It is supposed to be called once.
     */
    function setCharacterName(uint8 _characterId, string calldata _name)
        external
        onlyOwner
    {
        characterNames[_characterId] = _name;
    }

    /**
     * @dev Burn a NFT token. Callable by owner only.
     */
    function burn(uint256 _tokenId) external onlyOwner {
        uint8 characterIdBurnt = characterIds[_tokenId];
        characterCount[characterIdBurnt] = characterCount[characterIdBurnt].sub(1);
        characterBurnCount[characterIdBurnt] = characterBurnCount[characterIdBurnt].add(1);
        _burn(_tokenId);
    }
}