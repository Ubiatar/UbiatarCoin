pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Owned.sol";

contract UAC {
    function lockTransfer(bool _lock);
    function issueTokens(address _who, uint _tokens);
    function balanceOf(address _owner) public  constant  returns (uint256);
}

contract PreSaleVesting {
    function icoFinished();
}

contract FoundersVesting {

}

// This is the main UbiatarCoin ICO smart contract
contract ICO is Owned {

    using SafeMath for uint;

    address[] public multisigs;

    // Counts ETH invested by person, we might not need it
    mapping(address => uint) ethInvestedBy;
    uint collectedWei = 0;

    // Standard token price is 200 dollar CENTS per token
    uint public usdTokenPrice = 2 * 100;

    // The USD/ETH
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    // This value is given in dollar CENTS
    uint public usdPerEth = 1100 * 100;

    // Founders reward
    uint public constant FOUNDERS_REWARD = 2000000 * 1 ether;
    // Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 17584778551358900100698693;
    // 15 000 000 tokens sold during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;

    // Fields:

    // Test block number from which Ico will start, to be updated with real value before ICO starts
    uint public icoBlockNumberStart = 5305785;

    // Test time in epoch time when Ico will finish, to be updated with real value before ICO starts
    uint public icoFinishTime = 1524488400;

    address public toBeRefund = 0x0;

    uint public refundAmount;

    // Total amount of tokens sold during ICO
    uint public icoTokensSold = 0;
    // Total amount of tokens sent to UACUnsold contract after ICO is finished
    uint public icoTokensUnsold = 0;
    // This is where FOUNDERS_REWARD will be allocated
    address public foundersVestingAddress = 0x0;
    // This is where PRESALE_REWARD will be allocated
    address public preSaleVestingAddress = 0x0;

    address public uacTokenAddress = 0x0;

    address public unsoldContractAddress = 0x0;

    UAC public uacToken;

    PreSaleVesting public preSaleVesting;

    FoundersVesting public foundersVesting;

    enum State
    {
        Init,

        ICORunning,
        ICOPaused,

        // Collected ETH is transferred to multisigs.
        // Unsold tokens transferred to UACUnsold contract.
        ICOFinished
    }

    State public currentState = State.Init;

    // Modifiers:
    modifier onlyInState(State state)
    {
        require(state == currentState);
        _;
    }

    modifier onlyAfterBlockNumber()
    {
        require(block.number >= icoBlockNumberStart);
        _;
    }

    modifier onlyBeforeIcoFinishTime()
    {
        require(uint(now) <= icoFinishTime);
        _;
    }

    modifier canFinishICO()
    {
        require((uint(now) >= icoFinishTime) || (icoTokensSold == ICO_TOKEN_SUPPLY_LIMIT));
        _;
    }

    // Events:
    event LogStateSwitch(State newState);
    event LogBuy(address indexed owner, uint value);
    event LogBurn(address indexed owner, uint value);
    event LogWithdraw(address to, uint value);
    event LogOverflow(address to, uint value);
    event LogRefund(address to, uint value);

    // Functions:
    /// @dev Constructor
    function ICO
    (
        address _uacTokenAddress,
        address _unsoldContractAddress,
        address _foundersVestingAddress,
        address _preSaleVestingAddress
    )
    {
        uacToken = UAC(_uacTokenAddress);
        preSaleVesting = PreSaleVesting(_preSaleVestingAddress);
        foundersVesting = FoundersVesting(_foundersVestingAddress);

        uacTokenAddress = _uacTokenAddress;
        unsoldContractAddress = _unsoldContractAddress;
        foundersVestingAddress = _foundersVestingAddress;
        preSaleVestingAddress = _preSaleVestingAddress;
    }

    function startICO()
    public
    onlyOwner
    onlyInState(State.Init)
    {
        setState(State.ICORunning);
        uacToken.lockTransfer(true);
        uacToken.issueTokens(foundersVestingAddress, FOUNDERS_REWARD);
        uacToken.issueTokens(preSaleVestingAddress, PRESALE_REWARD);
    }

    function pauseICO()
    public
    onlyOwner
    onlyInState(State.ICORunning)
    {
        setState(State.ICOPaused);
    }

    function resumeICO()
    public
    onlyOwner
    onlyInState(State.ICOPaused)
    {
        setState(State.ICORunning);
    }

    /// This function can be called by owner at any time
    function finishICO()
    public
    onlyOwner
    canFinishICO
    onlyInState(State.ICORunning)
    {
        setState(State.ICOFinished);

        // 1 - lock all transfers
        uacToken.lockTransfer(false);

        // 2 - move all unsold tokens to unsoldTokens contract
        icoTokensUnsold = ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
        if (icoTokensUnsold > 0) {
            uacToken.issueTokens(unsoldContractAddress, icoTokensUnsold);
        }

        preSaleVesting.icoFinished();

        // Should be changed to our desired method of storing ether
        // 3 - send all ETH to multisigs
        // we have N separate multisigs for extra security
    /*    uint sendThisAmount = (this.balance / 10);

        // 3.1 - send to 9 multisigs
        for (uint i = 0; i < 9; ++i) {
            address ms = multisigs[i];

            if (this.balance >= sendThisAmount) {
                ms.transfer(sendThisAmount);
            }
        }

        // 3.2 - send everything left to 10th multisig
        if (0 != this.balance) {
            address lastMs = multisigs[9];
            lastMs.transfer(this.balance);
        }
        */
    }

    function refund()
    onlyOwner
    {
        require(toBeRefund != 0x0);
        require(refundAmount > 0);
        uint _refundAmount = refundAmount;
        address _toBeRefund = toBeRefund;
        refundAmount = 0;
        toBeRefund = 0x0;
        _toBeRefund.transfer(_refundAmount);
        LogRefund(_toBeRefund, _refundAmount);
    }

    function buyTokens(address _buyer)
    public
    payable
    onlyInState(State.ICORunning)
    onlyBeforeIcoFinishTime
    onlyAfterBlockNumber
    {
        require(msg.value >= 100 finney);

        uint newTokens = (msg.value * getUacTokensPerEth()) / 1 ether;

          if ((icoTokensSold + newTokens) <= ICO_TOKEN_SUPPLY_LIMIT)
          {
              issueTokensInternal(_buyer, newTokens);

              // Update this only when buying from ETH
              ethInvestedBy[_buyer] = ethInvestedBy[_buyer].add(msg.value);

              // This is total collected ETH
              collectedWei = collectedWei.add(msg.value);
          }
          else
          {
              uint tokensBought = ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
              uint _refundAmount = msg.value.sub((tokensBought.div(getUacTokensPerEth())).mul(1 ether));
              require(_refundAmount < msg.value);
              refundAmount = _refundAmount;
              toBeRefund = _buyer;
              LogOverflow(_buyer, _refundAmount);

              issueTokensInternal(_buyer, tokensBought);

              ethInvestedBy[_buyer] = ethInvestedBy[_buyer].add(_refundAmount);

              // This is total collected ETH
              collectedWei = collectedWei.add(_refundAmount);
          }
    }

    function issueTokensInternal(address _to, uint _tokens)
    internal
    {
        require((icoTokensSold + _tokens) <= ICO_TOKEN_SUPPLY_LIMIT);

        uacToken.issueTokens(_to, _tokens);
        icoTokensSold += _tokens;

        LogBuy(_to, _tokens);
    }

    //Setters

    function setUacTokenAddress(address _uacTokenAddress)
    onlyOwner
    onlyInState(State.Init)
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UAC(_uacTokenAddress);
    }

    function setUnsoldContractAddress(address _unsoldContractAddress)
    onlyOwner
    onlyInState(State.Init)
    {
        unsoldContractAddress = _unsoldContractAddress;
    }

    function setFoundersVestingAddress(address _foundersVestingAddress)
    onlyOwner
    onlyInState(State.Init)
    {
        foundersVestingAddress = _foundersVestingAddress;
        foundersVesting = FoundersVesting(_foundersVestingAddress);
    }

    function setPreSaleVestingAddress(address _preSaleVestingAddress)
    onlyOwner
    onlyInState(State.Init)
    {
        preSaleVestingAddress = _preSaleVestingAddress;
        preSaleVesting = PreSaleVesting(_preSaleVestingAddress);
    }

    function setBlockNumberStart(uint _blockNumber)
    onlyOwner
    {
        icoBlockNumberStart = _blockNumber;
    }

    function setIcoFinishTime(uint _time)
    onlyOwner
    {
        icoFinishTime = _time;
    }

    function setUsdPerEthRate(uint _usdPerEthRate)
    public
    onlyOwner
    {
        usdPerEth = _usdPerEthRate;
    }

    function setState(State _s)
    internal
    {
        currentState = _s;
        LogStateSwitch(_s);
    }

    function setUsdTokenPrice(uint tokenPrice)
    onlyOwner
    {
        usdTokenPrice = tokenPrice;
    }

    // Getters

    function getTokensIcoSold()
    constant
    public
    returns (uint)
    {
        return icoTokensSold;
    }

    function getTotalIcoTokens()
    constant
    public
    returns (uint)
    {
        return ICO_TOKEN_SUPPLY_LIMIT;
    }

    function getUacTokenBalance(address _of)
    constant
    public
    returns (uint)
    {
        return uacToken.balanceOf(_of);
    }

    function getTotalCollectedWei()
    constant
    public
    returns (uint)
    {
        return collectedWei;
    }

    function isIcoRunning()
    constant
    public
    returns (bool)
    {
        return (currentState == State.ICORunning);
    }

    function isIcoFinished()
    constant
    public
    returns (bool)
    {
        return (currentState == State.ICOFinished || icoTokensSold >= ICO_TOKEN_SUPPLY_LIMIT);
    }

    function getUacTokensPerEth()
    constant
    returns (uint)
    {
        uint uacPerEth = (usdPerEth * 1 ether) / usdTokenPrice;
        return uacPerEth;
    }

    // Default fallback function
    function() payable {
        // buyTokens -> issueTokensInternal
        buyTokens(msg.sender);
    }
}
