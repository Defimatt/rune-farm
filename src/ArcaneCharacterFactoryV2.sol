pragma solidity ^0.6.12;

import "./ArcaneCharacters.sol";

contract ArcaneCharacterFactoryV2 is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    ArcaneCharacters public arcaneCharacters;
    IBEP20 public runeToken;

    // end block number to get collectibles
    uint256 public endBlockNumber;

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

    /**
     * @dev A maximum number of NFT tokens that is distributed by this contract
     * is defined as totalSupplyDistributed.
     */
    constructor(
        ArcaneCharacters _arcaneCharacters,
        IBEP20 _runeToken,
        uint256 _tokenPrice,
        string memory _ipfsHash,
        uint256 _startBlockNumber,
        uint256 _endBlockNumber
    ) public {
        arcaneCharacters = _arcaneCharacters;
        runeToken = _runeToken;
        tokenPrice = _tokenPrice;
        ipfsHash = _ipfsHash;
        startBlockNumber = _startBlockNumber;
        endBlockNumber = _endBlockNumber;
    }

    /**
     * @dev Mint NFTs from the ArcaneCharacters contract.
     * Users can specify what characterId they want to mint. Users can claim once.
     * There is a limit on how many are distributed. It requires RUNE balance to be > 0.
     */
    function mintNFT(uint8 _characterId) external {
        // Check _msgSender() has not claimed
        require(!hasClaimed[_msgSender()], "Has claimed");
        // Check block time is not too late
        require(block.number > startBlockNumber, "too early");
        // Check block time is not too late
        require(block.number < endBlockNumber, "too late");
        // Check that the _characterId is within boundary:
        require(_characterId >= previousNumberCharacterIds, "characterId too low");
        // Check that the _characterId is within boundary:
        require(_characterId < numberCharacterIds, "characterId too high");

        // Update that _msgSender() has claimed
        hasClaimed[_msgSender()] = true;

        // Send RUNE tokens to this contract
        runeToken.safeTransferFrom(
            address(_msgSender()),
            address(this),
            tokenPrice
        );

        string memory tokenURI = characterIdURIs[_characterId];

        uint256 tokenId =
            arcaneCharacters.mint(address(_msgSender()), tokenURI, _characterId);

        emit CharacterMint(_msgSender(), tokenId, _characterId);
    }

    /**
     * @dev It transfers the ownership of the NFT contract
     * to a new address.
     */
    function changeOwnershipNFTContract(address _newOwner) external onlyOwner {
        arcaneCharacters.transferOwnership(_newOwner);
    }

    /**
     * @dev It transfers the RUNE tokens back to the chef address.
     * Only callable by the owner.
     */
    function claimFee(uint256 _amount) external onlyOwner {
        runeToken.safeTransfer(_msgSender(), _amount);
    }

    /**
     * @dev Set up json extensions for characters 5-9
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
     * @dev Allow to set up the end block number
     * Only the owner can set it.
     */
    function setEndBlockNumber(uint256 _newEndBlockNumber) external onlyOwner {
        require(_newEndBlockNumber > block.number, "too short");
        require(
            _newEndBlockNumber > startBlockNumber,
            "must be > startBlockNumber"
        );
        endBlockNumber = _newEndBlockNumber;
    }

    /**
     * @dev Allow to change the token price
     * Only the owner can set it.
     */
    function updateTokenPrice(uint256 _newTokenPrice) external onlyOwner {
        tokenPrice = _newTokenPrice;
    }
}