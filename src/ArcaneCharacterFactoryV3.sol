pragma solidity ^0.6.12;

import "./ArcaneCharacterFactoryV2.sol";
import "./ArcaneCharacterMintingStation.sol";

contract ArcaneCharacterFactoryV3 is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    ArcaneCharacterFactoryV2 public characterFactoryV2;
    ArcaneCharacterMintingStation public characterMintingStation;

    IBEP20 public runeToken;

    // starting block
    uint256 public startBlockNumber;

    // Number of RUNEs a user needs to pay to acquire a token
    uint256 public tokenPrice;

    // Map if address has already claimed a NFT
    mapping(address => bool) public hasClaimed;

    // IPFS hash for new json
    string private ipfsHash;

    // number of total series (i.e. different visuals)
    uint8 private constant numberCharacterIds = 8;

    // number of previous series (i.e. different visuals)
    uint8 private constant previousNumberCharacterIds = 1;

    // Map the token number to URI
    mapping(uint8 => string) private characterIdURIs;

    // Event to notify when NFT is successfully minted
    event CharacterMint(
        address indexed to,
        uint256 indexed tokenId,
        uint8 indexed characterId
    );

    constructor(
        ArcaneCharacterFactoryV2 _characterFactoryV2,
        ArcaneCharacterMintingStation _characterMintingStation,
        IBEP20 _runeToken,
        uint256 _tokenPrice,
        string memory _ipfsHash,
        uint256 _startBlockNumber
    ) public {
        characterFactoryV2 = _characterFactoryV2;
        characterMintingStation = _characterMintingStation;
        runeToken = _runeToken;
        tokenPrice = _tokenPrice;
        ipfsHash = _ipfsHash;
        startBlockNumber = _startBlockNumber;
    }

    /**
     * @dev Allow to change the IPFS hash
     * Only the owner can set it.
     */
    function updateIpfsHash(string memory _ipfsHash) external onlyOwner {
        ipfsHash = _ipfsHash;
    }

    /**
     * @dev Mint NFTs from the CharacterMintingStation contract.
     * Users can specify what characterId they want to mint. Users can claim once.
     */
    function mintNFT(uint8 _characterId) external {
        address senderAddress = _msgSender();

        bool hasClaimedV2 = characterFactoryV2.hasClaimed(senderAddress);

        // Check if _msgSender() has claimed in previous factory
        require(!hasClaimedV2, "Has claimed in v2");
        // Check _msgSender() has not claimed
        require(!hasClaimed[senderAddress], "Has claimed");
        // Check block time is not too late
        require(block.number > startBlockNumber, "too early");
        // Check that the _characterId is within boundary:
        require(_characterId >= previousNumberCharacterIds, "characterId too low");
        // Check that the _characterId is within boundary:
        require(_characterId < numberCharacterIds, "characterId too high");

        // Update that _msgSender() has claimed
        hasClaimed[senderAddress] = true;

        // Send RUNE tokens to this contract
        runeToken.safeTransferFrom(senderAddress, address(this), tokenPrice);

        string memory tokenURI = characterIdURIs[_characterId];

        uint256 tokenId =
            characterMintingStation.mintCollectible(
                senderAddress,
                tokenURI,
                _characterId
            );

        emit CharacterMint(senderAddress, tokenId, _characterId);
    }

    /**
     * @dev It transfers the RUNE tokens back to the chef address.
     * Only callable by the owner.
     */
    function claimFee(uint256 _amount) external onlyOwner {
        runeToken.safeTransfer(_msgSender(), _amount);
    }

    /**
     * @dev Set up json extensions for characters
     * Assign tokenURI to look for each characterId in the mint function
     * Only the owner can set it.
     */
    function setCharacterJson(
        string calldata _characterId1Json,
        string calldata _characterId2Json,
        string calldata _characterId3Json,
        string calldata _characterId4Json,
        string calldata _characterId5Json,
        string calldata _characterId6Json,
        string calldata _characterId7Json
    ) external onlyOwner {
        characterIdURIs[1] = string(abi.encodePacked(ipfsHash, _characterId1Json));
        characterIdURIs[2] = string(abi.encodePacked(ipfsHash, _characterId2Json));
        characterIdURIs[3] = string(abi.encodePacked(ipfsHash, _characterId3Json));
        characterIdURIs[4] = string(abi.encodePacked(ipfsHash, _characterId4Json));
        characterIdURIs[5] = string(abi.encodePacked(ipfsHash, _characterId5Json));
        characterIdURIs[6] = string(abi.encodePacked(ipfsHash, _characterId6Json));
        characterIdURIs[7] = string(abi.encodePacked(ipfsHash, _characterId7Json));
    }

    /**
     * @dev Allow to set up the start number
     * Only the owner can set it.
     */
    function setStartBlockNumber(uint256 _newStartBlockNumber)
        external
        onlyOwner
    {
        require(_newStartBlockNumber > block.number, "too short");
        startBlockNumber = _newStartBlockNumber;
    }

    /**
     * @dev Allow to change the token price
     * Only the owner can set it.
     */
    function updateTokenPrice(uint256 _newTokenPrice) external onlyOwner {
        tokenPrice = _newTokenPrice;
    }

    function canMint(address userAddress) external view returns (bool) {
        if (
            (hasClaimed[userAddress]) ||
            (characterFactoryV2.hasClaimed(userAddress))
        ) {
            return false;
        } else {
            return true;
        }
    }
}