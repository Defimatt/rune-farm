pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/token/BEP20/IBEP20.sol";
import "../lib/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../runes/Nef.sol";
import "../ArcaneItemFactoryV1.sol";
import "../ArcaneProfile.sol";



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

    address public itemsAddress;

    address public runeToken;
    address public elToken;
    address public eldToken;
    address public tirToken;
    address public nefToken;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when RUNE mining starts.
    uint256 public startBlock;

    mapping (address => uint256) public userEquippedItemMap;

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
        nefToken = address(_rune);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
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

    function stringToUint(bytes memory b) internal view returns (uint256) {
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }

    // function uintToString(uint256 v) internal view returns (string memory) {
    //     if (v == 0) return "0";

    //     uint256 maxlength = 100;
    //     bytes memory reversed = new bytes(maxlength);
    //     uint i = 0;
    //     while (v != 0) {
    //         uint remainder = v % 10;
    //         v = v / 10;
    //         reversed[i++] = byte(48 + uint8(remainder));
    //     }
    //     bytes memory s = new bytes(i); // i + 1 is inefficient
    //     for (uint j = 0; j < i; j++) {
    //         s[j] = reversed[i - j - 1]; // to avoid the off-by-one error
    //     }
    //     string memory str = string(s);  // memory isn't implicitly convertible to storage
    //     return str;
    // }

    function uintToString(
        uint v
    )
        pure
        public
        returns (string memory)
    {
        uint w = v;
        bytes32 x;
        if (v == 0) {
            x = "0";
        } else {
            while (w > 0) {
                x = bytes32(uint(x) / (2 ** 8));
                x |= bytes32(((w % 10) + 48) * 2 ** (8 * 31));
                w /= 10;
            }
        }

        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        uint j = 0;
        for (j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory resultBytes = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            resultBytes[j] = bytesString[j];
        }

        return string(resultBytes);
    }

    function getSlice(uint256 begin, uint256 end, string memory text) public pure returns (string memory) {
        bytes memory a = new bytes(end-begin);
        for(uint i=0;i<end-begin;i++){
            a[i] = bytes(text)[i+begin];
        }
        return string(a);    
    }

    function parseInt(string memory _a) internal pure returns (uint _parsedInt) {
        return parseInt(_a, 0);
    }

    function parseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                   if (_b == 0) {
                       break;
                   } else {
                       _b--;
                   }
                }
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                decimals = true;
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }

    // function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
    //     if (_i == 0) {
    //         return "0";
    //     }
    //     uint j = _i;
    //     uint len;
    //     while (j != 0) {
    //         len++;
    //         j /= 10;
    //     }
    //     bytes memory bstr = new bytes(len);
    //     uint k = len;
    //     while (_i != 0) {
    //         k = k-1;
    //         uint8 temp = (48 + uint8(_i - _i / 10 * 10));
    //         bytes1 b1 = bytes1(temp);
    //         bstr[k] = b1;
    //         _i /= 10;
    //     }
    //     return string(bstr);
    // }

    function getItem(uint256 _tokenId) public view returns (ArcaneItemFactoryV1.ArcaneItem memory) {
        // Not exactly efficient but easy to read
        string memory tokenIdStr = uintToString(_tokenId);
        uint8 version = uint8(parseInt(getSlice(1, 4, tokenIdStr)));

        ArcaneItemFactoryV1.ArcaneItemModifier[] memory mods = new ArcaneItemFactoryV1.ArcaneItemModifier[](3);

        mods[0] = ArcaneItemFactoryV1.ArcaneItemModifier({
            variant: uint8(parseInt(getSlice(9, 10, tokenIdStr))),
            value: uint16(parseInt(getSlice(10, 13, tokenIdStr)))
        });

        mods[1] = ArcaneItemFactoryV1.ArcaneItemModifier({
            variant: uint8(parseInt(getSlice(13, 14, tokenIdStr))),
            value: uint16(parseInt(getSlice(14, 17, tokenIdStr)))
        });

        mods[2] = ArcaneItemFactoryV1.ArcaneItemModifier({
            variant: uint8(parseInt(getSlice(17, 18, tokenIdStr))),
            value: uint16(parseInt(getSlice(18, 21, tokenIdStr)))
        });

        ArcaneItemFactoryV1.ArcaneItem memory item = ArcaneItemFactoryV1.ArcaneItem({
            version: version,
            itemId: uint16(parseInt(getSlice(4, 9, tokenIdStr))),
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

        require(userEquippedItemMap[_msgSender()] == 0, "Item already equiped");

        userEquippedItemMap[_msgSender()] = _tokenId;

        // Transfer NFT to this contract
        nftToken.safeTransferFrom(_msgSender(), address(this), _tokenId);
    }

    function _unequipItem(uint256 _tokenId) public {
        // massUpdatePools();

        IERC721 nftToken = IERC721(itemsAddress);

        require(userEquippedItemMap[_msgSender()] == _tokenId, "Item not equipped");

        userEquippedItemMap[_msgSender()] = 0;

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
                uint256 tokenId = userEquippedItemMap[_msgSender()];

                if (tokenId > 0) {
                    ArcaneItemFactoryV1.ArcaneItem memory item = getItem(tokenId);

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
                            safeBepTransfer(feeToken, address(msg.sender), vaultAddress, feeAmount);
                            
                            // emit HarvestFee(vaultAddress, feeAmount);
                        }

                        uint256 bonusAmount = pending.mul(item.mods[0].value).div(100);
                        safeBepTransfer(nefToken, vaultAddress, address(msg.sender), bonusAmount);

                        // emit HarvestBonus(msg.sender, bonusAmount);
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
            uint256 tokenId = userEquippedItemMap[_msgSender()];

            if (tokenId > 0) {
                ArcaneItemFactoryV1.ArcaneItem memory item = getItem(tokenId);

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
                        safeBepTransfer(feeToken, address(msg.sender), vaultAddress, feeAmount);
                        
                        // emit HarvestFee(vaultAddress, feeAmount);
                    }

                    uint256 bonusAmount = pending.mul(item.mods[0].value).div(100);
                    safeBepTransfer(nefToken, vaultAddress, address(msg.sender), bonusAmount);

                    // emit HarvestBonus(msg.sender, bonusAmount);
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

    function safeBepTransfer(address _tokenAddress, address _from, address _to, uint256 _amount) internal {
        IBEP20 _token = BEP20(_tokenAddress);
        uint256 _bal = _token.balanceOf(_from);
        if (_amount > _bal) {
            _token.safeTransferFrom(_from, _to, _bal);
        } else {
            _token.safeTransferFrom(_from, _to, _amount);
        }
    }

    //Arcane has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _runePerBlock) public onlyOwner {
        massUpdatePools();
        runePerBlock = _runePerBlock;
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

    function throwRuneInTheVoid() external {
        require(msg.sender == devAddress, "dev: wut?");
        massUpdatePools();
        runePerBlock = 0;
        rune.transferOwnership(voidAddress);
    }
}