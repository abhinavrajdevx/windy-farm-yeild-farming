pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./Wind.sol";

//DEV ONLY REMOVE IN PRODI+UCTION
import "hardhat/console.sol";

contract Chef  {
    
    using SafeERC20 for IERC20;

    struct UserInfo {
        bool exists; // Checks if the user exists 
        uint256 reward_pending; // Reward pending before the latest deposit
        uint256 reward_per_block; // Current reward block
        uint256 latest_deposit_block; // Block at which latest deposit was done. 
        uint256 amount; // total amount deposited in the pool

        // On every deposit :
        //                      if not (first_deposit):            
        //                          reward_pending = reward_pending + ( current_block - latest_deposit_block ) * reward_per_block;
        //                          latest_deposit_block= current_block
        //                          reward_per_block= ( reward_per_block_percent of this pool / 100 ) * amount
        //                          amount= amount + _amount
    }
    struct Poolinfo {
        bool exists;
        IERC20 lpToken;
        uint256 reward_per_block_percent_per_block;
        uint256 last_reward_block;
    }

    address public owner;
    Wind public wind;
    uint256 public startblock;
    uint256 public poolIndex= 0;
    Poolinfo [] public polinfo;
    mapping (uint256 => mapping ( address => UserInfo)) public userInfo;
    
    constructor (uint256 _startblock, Wind _wind)  {
        startblock= _startblock;
        wind= _wind;
        owner= msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function add (IERC20 _lpToken, uint256 _last_reward_block, uint256 _reward_per_block_percent_per_block) public onlyOwner {
        polinfo.push(Poolinfo({
        exists: true,
         lpToken: _lpToken,
         reward_per_block_percent_per_block: _reward_per_block_percent_per_block,
         last_reward_block: _last_reward_block
        }));
        poolIndex= poolIndex +1;
    }

    function divide(uint256 numerator, uint256 denominator, uint256 precision) internal pure returns (uint256) {
            require(denominator != 0, "Denominator cannot be zero");
            if ( numerator == denominator) {
                return 1;
            } else {
                uint256 scalingFactor = 10 ** precision;
                uint256 scaledNumerator = numerator * scalingFactor;
                uint256 result = scaledNumerator / denominator;
                return result; 
            }
        }

        function getResultAsFloat(uint256 scaledResult, uint256 precision) public pure returns (string memory) {
            uint256 integerPart = scaledResult / (10 ** precision);
            uint256 decimalPart = scaledResult % (10 ** precision);

            return string(abi.encodePacked(uint2str(integerPart), ".", uint2str(decimalPart)));
        }

        function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
            if (_i == 0) {
                return "0";
            }
            uint256 j = _i;
            uint256 len;
            while (j != 0) {
                len++;
                j /= 10;
            }
            bytes memory bstr = new bytes(len);
            uint256 k = len;
            while (_i != 0) {
                k = k-1;
                uint8 temp = (48 + uint8(_i - _i / 10 * 10));
                bytes1 b1 = bytes1(temp);
                bstr[k] = b1;
                _i /= 10;
            }
            return string(bstr);
    }

    function deposit (uint256 _pid, uint256 _amount) public {
        Poolinfo storage pool = polinfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (_amount > 0) {
            require (pool.lpToken.allowance(msg.sender, address(this)) == _amount , "Not enough allowance");
            bool transfer_succes= pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            require (transfer_succes, "Error in transfer");
            (bool isok, uint256 _total_new_amount) = Math.tryAdd(user.amount, _amount);
            require(isok, "Unknown Error");
            user.exists= true;
            user.amount= _total_new_amount;
            user.reward_pending = user.reward_pending + ( block.number - user.latest_deposit_block ) * user.reward_per_block;
            user.latest_deposit_block= block.number;
            uint256 times_of_100 = divide( _total_new_amount, 100, 0);
            user.reward_per_block= times_of_100 * pool.reward_per_block_percent_per_block;
        }
    }

    function withdrawLpTokens (uint256 _pid) public {
        Poolinfo storage pool = polinfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender),  user.amount);
        user.amount=0;
        if (block.number > user.latest_deposit_block){
            user.reward_pending = user.reward_pending + ( block.number - (user.latest_deposit_block +1) ) * user.reward_per_block;
        }
        user.reward_pending= 0;
        user.reward_per_block= 0;
    }

    function withdrawReward () public {
        uint256 total_reward = pendingReward(msg.sender);
        wind.mint(total_reward);
        console.log("Current block number");
        wind.transfer(msg.sender, total_reward);
    }

    function pendingReward (address _user) public view  returns (uint256){
        uint256 i= 0;
        uint256 total_reward= 0;
        while (i < poolIndex) {
            UserInfo storage user = userInfo[i][_user];
            if (block.number > user.latest_deposit_block){
                console.log(user.latest_deposit_block);
                (bool mul_success, uint256 mul_res) =  Math.tryMul( (block.number - user.latest_deposit_block -1) ,user.reward_per_block) ;
                total_reward= total_reward+  mul_res;
            }
            i++;
        }
        return total_reward;
    }
}