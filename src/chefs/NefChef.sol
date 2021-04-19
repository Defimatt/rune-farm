pragma solidity 0.6.12;

import "../lib/math/SafeMath.sol";
import "../lib/token/BEP20/IBEP20.sol";
import "../lib/token/BEP20/SafeBEP20.sol";
import "../lib/access/Ownable.sol";

import "../runes/Nef.sol";
import "../ArcaneCharacters.sol";
import "../ArcaneItems.sol";
import "../ArcaneItemFactoryV1.sol";
import "../ArcaneProfile.sol";
import "../ArcaneItemMintingStation.sol";



// MasterChef is the master of Rune. He can make Rune and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once RUNE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract NefChef is Ownable, ERC721Holder {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        ArcaneItemFactoryV1.ArcaneItem[] items; // Equiped items
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of RUNEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRunePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRunePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. RUNEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that RUNEs distribution occurs.
        uint256 accRunePerShare;   // Accumulated RUNEs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The RUNE!
    NefRune public rune;
    // Dev address
    address public devAddress;
    // Charity address
    address public charityAddress;
    // RUNE tokens created per block.
    uint256 public runePerBlock;
    // Bonus muliplier for early rune makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Vault address
    address public vaultAddress;
    // Void address
    address public voidAddress;

    address public profileAddress;
    address public itemMintingStationAddress;


    // Mint percent breakdown
    uint256 public devMintPercent = 0;
    uint256 public vaultMintPercent = 0;
    uint256 public charityMintPercent = 0;

    // Deposit fee breakdown
    uint256 public devDepositPercent = 0;
    uint256 public vaultDepositPercent = 0;
    uint256 public charityDepositPercent = 0;

    // Withdraw fee
    uint256 public vaultWithdrawPercent = 0;

    address public itemsAddress;

    address public runeToken;
    address public elToken;
    address public eldToken;
    address public tirToken;
    address public nefToken;

    // Map if address has already claimed their Worldstone Shard
    mapping(address => bool) public hasClaimedShard;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when RUNE mining starts.
    uint256 public startBlock;

    mapping (address => uint256[]) public userEquippedItems;
    mapping (uint16 => uint256) public userEquippedItemMap;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event HarvestFee(address indexed user, uint256 amount);
    event HarvestBonus(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        NefRune _rune,
        address _profileAddress,
        address _itemMintingStationAddress,
        address _itemsAddress,
        address _devAddress,
        address _vaultAddress,
        address _charityAddress,
        address _voidAddress,
        uint256 _runePerBlock,
        uint256 _startBlock
    ) public {
        rune = _rune;
        profileAddress = _profileAddress;
        itemMintingStationAddress = _itemMintingStationAddress;
        itemsAddress = _itemsAddress;
        devAddress = _devAddress;
        vaultAddress = _vaultAddress;
        charityAddress = _charityAddress;
        voidAddress = _voidAddress;
        runePerBlock = _runePerBlock;
        startBlock = _startBlock;
        runeToken = 0xA9776B590bfc2f956711b3419910A5Ec1F63153E;
        elToken = 0x210C14fbeCC2BD9B6231199470DA12AD45F64D45;
        eldToken = 0xe00B8109bcB70B1EDeb4cf87914efC2805020995;
        tirToken = 0x125a3E00a9A11317d4d95349E68Ba0bC744ADDc4;
        nefToken = 0xBfd3BfaD349fbC96EBAEC737f49239eE5168151F;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function userItemsLength(address _user) external view returns (uint256) {
        return userEquippedItems[_user].length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRunePerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's RUNE allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending RUNEs on frontend.
    function pendingRune(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRunePerShare = pool.accRunePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 runeReward = multiplier.mul(runePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRunePerShare = accRunePerShare.add(runeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRunePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0 || runePerBlock == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 runeReward = multiplier.mul(runePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        rune.mint(devAddress, runeReward.mul(devMintPercent).div(10000));
        rune.mint(vaultAddress, runeReward.mul(vaultMintPercent).div(10000));
        rune.mint(charityAddress, runeReward.mul(charityMintPercent).div(10000));
        rune.mint(address(this), runeReward);

        pool.accRunePerShare = pool.accRunePerShare.add(runeReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function claimShard() public {
        require(!hasClaimedShard[_msgSender()], "Already claimed");
        
        hasClaimedShard[_msgSender()] = true;

        uint16 itemId = 10000;
        string memory tokenURI = 'mtwirsqawjuoloq2gvtyug2tc3jbf5htm2zeo4rsknfiv3fdp46a/item-10000.json';

        uint256 tokenId = 0x16220673BECD24F6889ACE92996B36659B4D8F5E05DABB000000000000000000; //10011000000000000000000000000000000000000000000000000000000000000000000000000;

        ArcaneItemMintingStation(itemMintingStationAddress).mint(
            _msgSender(),
            tokenURI,
            itemId,
            tokenId
        );
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

    function getItem(uint256 _tokenId) public view returns (ArcaneItemFactoryV1.ArcaneItem memory) {
        // Not exactly efficient but easy to read
        string memory tokenIdStr = uintToString(_tokenId);
        uint8 version = uint8(stringToUint(getSlice(1, 4, tokenIdStr)));

        ArcaneItemFactoryV1.ArcaneItemModifier[] memory mods = new ArcaneItemFactoryV1.ArcaneItemModifier[](17);
        uint l = 70;
        for (uint i = 9; i+4 < l; i+4) {
            uint8 _variant = uint8(stringToUint(getSlice(i, i+1, tokenIdStr)));
            uint16 _value = uint16(stringToUint(getSlice(i+1, i+4, tokenIdStr)));

            ArcaneItemFactoryV1.ArcaneItemModifier memory mod = ArcaneItemFactoryV1.ArcaneItemModifier({
                variant: _variant,
                value: _value
            });

            mods[i] = mod;
        }

        ArcaneItemFactoryV1.ArcaneItem memory item = ArcaneItemFactoryV1.ArcaneItem({
            version: version,
            itemId: uint16(stringToUint(getSlice(4, 9, tokenIdStr))),
            mods: mods
        });

        return item;
    }

    function getUserProfile(address _address) internal view returns (ArcaneProfile.User memory) {
        uint256 userId;
        uint256 numberPoints;
        uint256 teamId;
        address nftAddress;
        uint256 tokenId;
        bool isActive;
        
        (
            userId,
            numberPoints,
            teamId,
            nftAddress,
            tokenId,
            isActive
        ) = ArcaneProfile(profileAddress).getUserProfile(_address);
        
        
        ArcaneProfile.User memory user = ArcaneProfile.User({
            userId: userId,
            numberPoints: numberPoints,
            teamId: teamId,
            nftAddress: nftAddress,
            tokenId: tokenId,
            isActive: isActive
        });

        return user;
    }

    function equipItem(uint256 _tokenId) public {
        // massUpdatePools();

        // Loads the interface to deposit the NFT contract
        IERC721 nftToken = IERC721(itemsAddress);

        require(_msgSender() == nftToken.ownerOf(_tokenId), "Only NFT owner can register");

        ArcaneItemFactoryV1.ArcaneItem memory item = getItem(_tokenId);
        require(userEquippedItemMap[item.itemId] == 0, "Item already equiped");

        // Transfer NFT to this contract
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);

        userEquippedItemMap[item.itemId] = userEquippedItems[_msgSender()].length+1;
        userEquippedItems[_msgSender()].push(_tokenId);
    }

    function _unequipItem(uint256 _tokenId) public {
        // massUpdatePools();

        IERC721 nftToken = IERC721(itemsAddress);

        ArcaneItemFactoryV1.ArcaneItem memory item = getItem(_tokenId);
        require(userEquippedItemMap[item.itemId] != 0, "Item already equiped");

        userEquippedItemMap[item.itemId] = 0;

        delete userEquippedItems[_msgSender()][userEquippedItemMap[item.itemId]-1];

        // Transfer NFT back to user
        nftToken.safeTransferFrom(address(this), _msgSender(), _tokenId);
    }

    function unequipItem(uint256 _tokenId) public {
        // massUpdatePools();
        _unequipItem(_tokenId);
    }

    function emergencyUnequipItem(uint256 _tokenId) public {
        require(runePerBlock == 0, "Emission must be zero");
        _unequipItem(_tokenId);
    }

    // Deposit LP tokens to MasterChef for RUNE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        ArcaneProfile.User memory arcaneUser = getUserProfile(_msgSender());

        require(arcaneUser.isActive == true, "User must be active");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRunePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                uint l = userEquippedItems[_msgSender()].length;
                for (uint i = 0; i < l; i++) {
                    ArcaneItemFactoryV1.ArcaneItem memory item = getItem(userEquippedItems[_msgSender()][i]);

                    if (item.itemId == 1 && item.version == 1) {
                        if (item.mods[1].value > 0) {
                            address feeToken;
                            if (item.mods[2].value == 1) {
                                feeToken = elToken;
                            } else if (item.mods[2].value == 2) {
                                feeToken = tirToken;
                            } else {
                                feeToken = runeToken;
                            }

                            uint256 feeAmount = pending.mul(item.mods[1].value).div(100);
                            IBEP20(feeToken).safeTransferFrom(address(msg.sender), vaultAddress, feeAmount);
                            
                            emit HarvestFee(vaultAddress, feeAmount);
                        }

                        uint256 bonusAmount = pending.mul(item.mods[0].value).div(100);
                        IBEP20(nefToken).safeTransferFrom(vaultAddress, address(msg.sender), bonusAmount);

                        emit HarvestBonus(address(msg.sender), bonusAmount);
                    }
                }
                safeRuneTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(vaultAddress, depositFee.mul(vaultDepositPercent).div(10000));
                pool.lpToken.safeTransfer(devAddress, depositFee.mul(devDepositPercent).div(10000));
                pool.lpToken.safeTransfer(charityAddress, depositFee.mul(charityDepositPercent).div(10000));
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accRunePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRunePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            uint l = userEquippedItems[_msgSender()].length;
            for (uint i = 0; i < l; i++) {
                ArcaneItemFactoryV1.ArcaneItem memory item = getItem(userEquippedItems[_msgSender()][i]);

                if (item.itemId == 1 && item.version == 1) {
                    if (item.mods[1].value > 0) {
                        address feeToken;
                        if (item.mods[2].value == 1) {
                            feeToken = elToken;
                        } else if (item.mods[2].value == 2) {
                            feeToken = tirToken;
                        } else {
                            feeToken = runeToken;
                        }

                        uint256 feeAmount = pending.mul(item.mods[1].value).div(100);
                        IBEP20(feeToken).safeTransferFrom(address(msg.sender), vaultAddress, feeAmount);
                        
                        emit HarvestFee(vaultAddress, feeAmount);
                    }

                    uint256 bonusAmount = pending.mul(item.mods[0].value).div(100);
                    IBEP20(nefToken).safeTransferFrom(vaultAddress, address(msg.sender), bonusAmount);

                    emit HarvestBonus(address(msg.sender), bonusAmount);
                }
            }
            safeRuneTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRunePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe rune transfer function, just in case if rounding error causes pool to not have enough RUNEs.
    function safeRuneTransfer(address _to, uint256 _amount) internal {
        uint256 runeBal = rune.balanceOf(address(this));
        if (_amount > runeBal) {
            rune.transfer(_to, runeBal);
        } else {
            rune.transfer(_to, _amount);
        }
    }

    //Arcane has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _runePerBlock) public onlyOwner {
        massUpdatePools();
        runePerBlock = _runePerBlock;
    }

    function setWithdrawFee(uint256 _vaultWithdrawPercent) external {
        require(msg.sender == devAddress, "dev: wut?");
        require (_vaultWithdrawPercent <= 1000, "Withdraw percent constraints");

        vaultWithdrawPercent = _vaultWithdrawPercent;
    }

    function setInfo(address _vaultAddress, address _charityAddress, address _devAddress, uint256 _vaultMintPercent, uint256 _charityMintPercent, uint256 _devMintPercent, uint256 _vaultDepositPercent, uint256 _charityDepositPercent, uint256 _devDepositPercent) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        require (_vaultAddress != address(0) && _charityAddress != address(0) && _devAddress != address(0), "Cannot use zero address");
        require (_vaultMintPercent <= 9500 && _charityMintPercent <= 250 && _devMintPercent <= 250, "Mint percent constraints");
        require (_vaultDepositPercent <= 9500 && _charityDepositPercent <= 250 && _devDepositPercent <= 250, "Mint percent constraints");

        vaultAddress = _vaultAddress;
        charityAddress = _charityAddress;
        devAddress = _devAddress;

        vaultMintPercent = _vaultMintPercent;
        charityMintPercent = _charityMintPercent;
        devMintPercent = _devMintPercent;

        vaultDepositPercent = _vaultDepositPercent;
        charityDepositPercent = _charityDepositPercent;
        devDepositPercent = _devDepositPercent;
    }

    function rune_proxy_setFeeInfo(address _vaultAddress, address _charityAddress, address _devAddress, address _botAddress, uint256 _vaultFee, uint256 _charityFee, uint256 _devFee, uint256 _botFee) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        rune.setFeeInfo(_vaultAddress, _charityAddress, _devAddress, _botAddress, _vaultFee, _charityFee, _devFee, _botFee);
    }

    function rune_proxy_addExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addExcluded(_account);
    }

    function rune_proxy_removeExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeExcluded(_account);
    }

    function rune_proxy_addBot(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addBot(_account);
    }

    function rune_proxy_removeBot(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeBot(_account);
    }

    function throwRuneInTheVoid() external {
        require(msg.sender == devAddress, "dev: wut?");
        massUpdatePools();
        runePerBlock = 0;
        rune.transferOwnership(voidAddress);
    }
}