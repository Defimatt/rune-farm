pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

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

    // IPFS hash for new json
    string private ipfsHash;

    // Map the token number to URI
    mapping(uint16 => string) private itemIdURIs;

    mapping(address => mapping(address => ArcaneRecipe)) public recipes;

    // Is minting enabled
    bool private mintingEnabled;

    uint8 public constant version = 1;

    // Event to notify when NFT is successfully minted
    event ItemMint(
        address indexed to,
        uint256 indexed tokenId,
        uint16 indexed itemId
    );

    struct ArcaneRecipe {
        uint16 version;
        uint16 itemId;
        ArcaneRecipeModifier[] mods;
    }

    struct ArcaneRecipeModifier {
        ArcaneItemModifier mod;
        uint16 minRange;
        uint16 maxRange;
        uint16 difficulty;
    }

    struct ArcaneItem {
        uint16 version;
        uint16 itemId;
        ArcaneItemModifier[] mods;
    }

    struct ArcaneItemModifier {
        uint8 variant;
        uint16 value;
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

    function addRecipe(address _item1, address _item2, uint16 _version, uint16 _itemId, ArcaneRecipeModifier[] memory _mods) external onlyOwner {
        ArcaneRecipeModifier[] memory _mods2 = new ArcaneRecipeModifier[](_mods.length);

        for(uint i = 0; i < _mods.length; i++) {
            ArcaneRecipeModifier memory mod = _mods[i];
            _mods2[i] = ArcaneRecipeModifier({
                mod: ArcaneItemModifier({
                    variant: mod.mod.variant,
                    value: mod.mod.value
                }),
                minRange: mod.minRange,
                maxRange: mod.maxRange,
                difficulty: mod.difficulty
            });
        }

        recipes[_item1][_item2] = ArcaneRecipe({
            version: _version,
            itemId: _itemId,
            mods: _mods
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

    function randMod(uint _modulus) internal returns(uint) {
        bytes memory addressBytes = abi.encodePacked(address(msg.sender));
        randNonce += uint(uint8(addressBytes[0]));
        return uint(keccak256(abi.encodePacked(now, msg.sender, randNonce))) % _modulus;
    }
    
    function stringToUint(string memory s) internal view returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }

    function uintToString(uint256 v) internal view returns (string memory) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = byte(48 + uint8(remainder));
        }
        bytes memory s = new bytes(i); // i + 1 is inefficient
        for (uint j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1]; // to avoid the off-by-one error
        }
        string memory str = string(s);  // memory isn't implicitly convertible to storage
        return str;
    }

    function getSlice(uint256 begin, uint256 end, string memory text) public pure returns (string memory) {
        bytes memory a = new bytes(end-begin+1);
        for(uint i=0;i<=end-begin;i++){
            a[i] = bytes(text)[i+begin-1];
        }
        return string(a);    
    }

    function concat(string memory a, string memory b, string memory c, string memory d, string memory e) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    function getTokenIdFromRecipe(ArcaneRecipe memory recipe) public returns (uint256) {
        string memory _version = uintToString(recipe.version);
        string memory itemId = uintToString(recipe.itemId);
        string memory mod1 = uintToString(recipe.mods[0].mod.variant);
        string memory mod2 = uintToString(recipe.mods[0].minRange + randMod(recipe.mods[0].maxRange));
        string memory mod3 = uintToString(recipe.mods[0].mod.variant);
        string memory mod4 = uintToString(recipe.mods[1].minRange + randMod(recipe.mods[1].maxRange));

        return uint256(stringToUint(string(abi.encodePacked(_version, itemId, mod1, mod2, mod3, mod4))));
    }

    /**
     * @dev Mint NFTs from the ItemMintingStation contract.
     * Users can specify what itemId they want to mint. Users can claim once.
     */
    function transmute(address _item1, address _item2) external {
        require(mintingEnabled == true, "Minting disabled");
        
        address senderAddress = _msgSender();

        ArcaneRecipe memory recipe = recipes[_item1][_item2];

        // Check block time is not too late
        require(block.number > startBlockNumber, "too early");

        // Send RUNE tokens to this contract
        if (tokenPrice > 0) {
            runeToken.safeTransferFrom(senderAddress, address(this), tokenPrice);
        }

        string memory tokenURI = itemIdURIs[recipe.itemId];

        // TODO random mods

        uint16 _itemId = recipe.itemId;
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
        uint16 _itemId,
        string calldata _itemIdJson
    ) external onlyOwner {
        itemIdURIs[_itemId] = string(abi.encodePacked(ipfsHash, _itemIdJson));
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

    function setMintingEnabled(bool _mintingEnabled) external onlyOwner {
        mintingEnabled = _mintingEnabled;
    }
}