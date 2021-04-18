pragma solidity 0.6.12;

import "./lib/math/SafeMath.sol";
import "./lib/token/BEP20/IBEP20.sol";
import "./lib/token/BEP20/SafeBEP20.sol";
import "./lib/access/Ownable.sol";

import "./ArcaneItemMintingStation.sol";
import "./ArcaneItems.sol";

contract ArcaneItemFactoryV1 is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    ArcaneItemMintingStation public itemMintingStation;

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
    uint8 private constant numberItemIds = 8;

    // number of previous series (i.e. different visuals)
    uint8 private constant previousNumberItemIds = 1;

    // Map the token number to URI
    mapping(uint8 => string) private itemIdURIs;

    mapping(address => mapping(address => uint256)) public recipes;

    uint8 public constant version = 1;

    // Event to notify when NFT is successfully minted
    event ItemMint(
        address indexed to,
        uint256 indexed tokenId,
        uint8 indexed itemId
    );

    struct ArcaneRecipe {
        uint16 version;
        uint16 itemId;
        ArcaneRecipeModifier[] modifiers;
    }

    struct ArcaneRecipeModifier {
        ArcaneItemAttribute attribute;
        uint16 minRange;
        uint16 maxRange;
        uint16 difficulty;
    }

    struct ArcaneItem {
        uint16 version;
        uint16 itemId;
        ArcaneItemAttribute[] attributes;
    }

    struct ArcaneItemAttribute {
        uint16 attributeId;
        uint8[] modifiers;
    }

    constructor(
        ArcaneItemMintingStation _itemMintingStation,
        IBEP20 _runeToken,
        uint256 _tokenPrice,
        string memory _ipfsHash,
        uint256 _startBlockNumber
    ) public {
        itemMintingStation = _itemMintingStation;
        runeToken = _runeToken;
        tokenPrice = _tokenPrice;
        ipfsHash = _ipfsHash;
        startBlockNumber = _startBlockNumber;
    }


    function addRecipe(address _item1, address _item2, uint _version, uint _itemId) {
        recipes[_item1][_item2] = ArcaneRecipe({
            version: _version,
            itemId: _itemId,
            modifiers: _modifiers
        });
    }

    uint public randNonce;

    /**
     * @dev Allow to change the IPFS hash
     * Only the owner can set it.
     */
    function updateIpfsHash(string memory _ipfsHash) external onlyOwner {
        ipfsHash = _ipfsHash;
    }

    function randMod(uint _modulus) internal view returns(uint) {
        randNonce += uint(msg.sender[0]);
        return uint(keccak256(abi.encodePacked(now, msg.sender, randNonce))) % _modulus;
    }
    
    function stringToUint(string s) internal view returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }

    function uintToString(uint256 v) internal view returns (string) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = byte(48 + remainder);
        }
        bytes memory s = new bytes(i); // i + 1 is inefficient
        for (uint j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1]; // to avoid the off-by-one error
        }
        string memory str = string(s);  // memory isn't implicitly convertible to storage
        return str;
    }

    function getSlice(uint256 begin, uint256 end, string text) public pure returns (string) {
        bytes memory a = new bytes(end-begin+1);
        for(uint i=0;i<=end-begin;i++){
            a[i] = bytes(text)[i+begin-1];
        }
        return string(a);    
    }

    function concat(string a, string b, string c, string d, string e) internal pure returns (string) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    function getTokenIdFromRecipe(ArcaneRecipe recipe) public view returns (uint256) {
        string tokenIdStr = uintToString(_tokenId);
        uint8 version = uint8(stringToUint(getSlice(0, 1, tokenIdStr)));

        if (version == 1) {
            ArcaneFactoryV1.ArcaneItem memory item = ArcaneFactoryV1.ArcaneItem({
                itemId: uint16(stringToUint(getSlice(i, i+5, tokenIdStr)))
            });

            ArcaneFactoryV1.ArcaneItemAttribute memory currentAttribute;

            uint l = tokenIdStr.length;
            for (uint i = 6; i < l; i+5) {
                uint16 decoded = uint16(stringToUint(getSlice(i, i+5, tokenIdStr)));

                // It's an attribute else it's a modifier
                if (decoded > 50000) {
                    currentAttribute = ArcaneFactoryV1.ArcaneItemAttribute({
                        attributeId: decoded
                    });
                } else {
                    currentAttribute.modifiers.push(decoded);
                }
            }
        }

        string version = uintToString(recipe.version);
        string itemId = uintToString(recipe.itemId);
        string modifier1 = uintToString(recipe.modifiers[0].attribute.attributeId);
        string modifier2 = uintToString(recipe.modifiers[0].minRange + randMod(recipe.modifiers[0].maxRange));
        string modifier3 = uintToString(recipe.modifiers[1].attribute.attributeId);
        string modifier4 = uintToString(recipe.modifiers[1].minRange + randMod(recipe.modifiers[1].maxRange));

        return uint256(stringToUint(string(abi.encodePacked(version, itemId, modifier1, modifier2, modifier3, modifier4))));
    }

    /**
     * @dev Mint NFTs from the ItemMintingStation contract.
     * Users can specify what itemId they want to mint. Users can claim once.
     */
    function transmute(address _item1, address _item2) external {
        address senderAddress = _msgSender();

        ArcaneRecipe memory recipe = recipes[_item1][_item2];

        // Check block time is not too late
        require(block.number > startBlockNumber, "too early");
        // // Check that the _itemId is within boundary:
        // require(_itemId >= previousNumberItemIds, "itemId too low");
        // // Check that the _itemId is within boundary:
        // require(_itemId < numberItemIds, "itemId too high");

        // Send RUNE tokens to this contract
        if (tokenPrice > 0) {
            runeToken.safeTransferFrom(senderAddress, address(this), tokenPrice);
        }

        string memory tokenURI = itemIdURIs[recipe.itemId];

        // TODO random modifiers

        uint256 _tokenId = getTokenIdFromRecipe(recipe);

        uint256 tokenId =
            itemMintingStation.mint(
                senderAddress,
                tokenURI,
                _itemId,
                _tokenId
            );

        emit ItemMint(senderAddress, tokenId, _itemId);
    }

    /**
     * @dev It transfers the RUNE tokens back to the chef address.
     * Only callable by the owner.
     */
    function claimFee(uint256 _amount) external onlyOwner {
        runeToken.safeTransfer(_msgSender(), _amount);
    }

    /**
     * @dev Set up json extensions for items
     * Assign tokenURI to look for each itemId in the mint function
     * Only the owner can set it.
     */
    function setItemJson(
        string calldata _itemId1Json,
        string calldata _itemId2Json,
        string calldata _itemId3Json,
        string calldata _itemId4Json,
        string calldata _itemId5Json,
        string calldata _itemId6Json,
        string calldata _itemId7Json
    ) external onlyOwner {
        itemIdURIs[1] = string(abi.encodePacked(ipfsHash, _itemId1Json));
        itemIdURIs[2] = string(abi.encodePacked(ipfsHash, _itemId2Json));
        itemIdURIs[3] = string(abi.encodePacked(ipfsHash, _itemId3Json));
        itemIdURIs[4] = string(abi.encodePacked(ipfsHash, _itemId4Json));
        itemIdURIs[5] = string(abi.encodePacked(ipfsHash, _itemId5Json));
        itemIdURIs[6] = string(abi.encodePacked(ipfsHash, _itemId6Json));
        itemIdURIs[7] = string(abi.encodePacked(ipfsHash, _itemId7Json));
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
        return true;
    }
}