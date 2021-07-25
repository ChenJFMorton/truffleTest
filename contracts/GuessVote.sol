// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@nomiclabs/buidler/console.sol";

contract GuessVote {
    // 账号对应投票集合
    mapping(address => Voter[]) _addressVoterMap;
    // 期数对应投票集合
    mapping(uint256 => Voter[]) _periodVoterMap;
    // 期数对应结果
    mapping(uint256 => PeriodVoteResult) _periodResultMap;

    // 期数
    uint256 _periodNum;

    // 状态
    States _periodState = States.Ended;

    IERC20 _gusc;

    // 投票id，自增
    uint _voteId;

    // 状态枚举（投注中、已截止、已开奖）
    enum States {
        Voting,
        Ended
    }

    struct Voter {
        // 投票id
        uint _voteId;    
        // 账号
        address _account;
        // 期数
        uint256 _periodNum;
        // 投注数量
        uint256 _amount;
        // 投注目标
        uint256 _vote;
        // 开奖结果(0:小，1：大，2：未开奖)
        uint256 _result;
        // 赢取数量
        uint256 _winAmount;
    }

    struct PeriodVoteResult {
        // 期数
        uint256 _periodNum;
        // 投注数量
        uint256 _amount;
        // 竞猜结果(0:小，1：大，2：未开奖)
        uint256 _voteResult;
        // 处理结果
        bool _isHandled;
    }

    constructor() {
        _gusc=IERC20(0x2455f09186298a5Fb7545C1260D7Ab8f4D7998D8);
    }

    function generateVoteId() internal returns(uint) {
        _voteId += 1;
        return _voteId;
    }

    /**
     * 投注
     */
    function voteGuess(uint256 vote, uint256 amount) external returns (Voter[] memory voters) {
        // 当期可投注状态才允许投注
        _periodState = queryLatestPeriodState();
        require(_periodState == States.Voting);

        // 每20块为1期
        if (block.number % 20 > 0) {
            _periodNum = (block.number / 20) + 1;
        } else {
            _periodNum = block.number / 20;
        }
        // 投注记录
        Voter memory voter = Voter({_voteId: generateVoteId(), _account: msg.sender, _periodNum: _periodNum, _amount:amount, _vote:vote, _result:2, _winAmount:0});
        _addressVoterMap[msg.sender].push(voter);
        _periodVoterMap[_periodNum].push(voter);

        // 更新本期投注总数
        updateTotalAmount(_periodNum, amount);

        // 扣钱到合约账号
        _gusc.transferFrom(msg.sender, address(this), amount);

        return queryVoteListByAddressWithResult();
    }
    
    function updateTotalAmount(uint256 periodNum, uint256 amount) internal {
        if (_periodResultMap[periodNum]._periodNum == periodNum) {
            // 已存在
            _periodResultMap[periodNum]._amount += amount;
        } else {
            // map中不存在，则新建
            _periodResultMap[periodNum] = PeriodVoteResult({_periodNum:periodNum, _amount:amount, _voteResult:2, _isHandled:false});
        }
    }

    /**
     * 查询账号投注记录
     */
    function queryVoteListByAddressWithResult() internal returns (Voter[] memory voters) {
        Voter[] storage voterList = _addressVoterMap[msg.sender];
         for (uint i = 0; i < voterList.length; i++) {
             voterList[i]._result = _periodResultMap[voterList[i]._periodNum]._voteResult;
        }
        return voterList;
    }

    /**
     * 查询账号投注记录
     */
    function queryVoteListByAddress() public view returns (Voter[] memory voters) {
        return _addressVoterMap[msg.sender];
    }

    /**
     * 查询最新期投注状态（投注中、已截止）
     */
    function queryLatestPeriodState() internal view returns (States) {
        // 每20块中前10块为“投注中”，后10块为“已截止”
        if (block.number % 20 > 0 && block.number % 20 <= 10) {
            return States.Voting;
        } else {
            return States.Ended;
        }
    }

    /**
     * 生成竞猜结果（大或者小）
     */
    function generateVoteResult() public {
        // 遍历所有期数生成竞猜结果
        for (uint256 i=1;i<=(block.number / 20);i++) {
            PeriodVoteResult storage periodVoteResult = _periodResultMap[i];
            // 遍历当期之前的所有期数
            if (periodVoteResult._periodNum == i && !periodVoteResult._isHandled) {
                _periodResultMap[i]._voteResult = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%2;
                if (sendAwards(periodVoteResult)) {
                    _periodResultMap[i]._isHandled = true;
                }
            }
        }
    }

    /**
     * 派奖
     */
    function sendAwards(PeriodVoteResult memory periodVoteResult) public returns (bool) {
        // 未处理过的才派奖，并且是历史期数
        require(!periodVoteResult._isHandled);

        Voter[] storage periodVoterList = _periodVoterMap[periodVoteResult._periodNum];
        uint winTotalAmount = 0;
        for(uint i = 0; i < periodVoterList.length; i++) {
            Voter storage voter = periodVoterList[i];
            // 设置每个投注结果
            voter._result = periodVoteResult._voteResult;
            if (voter._vote == voter._result) {
                winTotalAmount += voter._amount;
            }
        }
        for(uint i = 0; i < periodVoterList.length; i++) {
            Voter storage voter = periodVoterList[i];

            // 设置每个投注结果
            voter._result = periodVoteResult._voteResult;
            if (voter._vote == voter._result) {
                // 10%给平台, 赢的人按照 TODO
                voter._winAmount = voter._amount * periodVoteResult._amount * 9 / (10 * winTotalAmount);
                if (voter._winAmount > 0) {
                    // 转账打钱
                    _gusc.transfer(voter._account, voter._winAmount);
                }
            }
            // 用户账号下的投票列表更新
            updateVoteResultByAccountAfterSendAwards(voter._account, voter._voteId, voter._result, voter._winAmount);
        }

        return true;
    }

    /**
    * 用户账号下的投票列表更新,在派奖成功之后
    */
    function updateVoteResultByAccountAfterSendAwards(address account, uint voteId, uint result, uint winAmount) internal {
        Voter[] storage voterList = _addressVoterMap[account];
        if (voterList.length > 0) {
            for (uint256 index = 0; index < voterList.length; index++) {
                if (voterList[index]._voteId == voteId) {
                    voterList[index]._result = result;
                    voterList[index]._winAmount = winAmount;
                }
            }
        }

    }
}
