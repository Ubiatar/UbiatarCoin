pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Owned.sol";

contract ICOEngineInterface{
    function started() public view returns(bool);
    function ended() public view returns(bool);
    function startTime() public view returns(uint);
    function endTime() public view returns(uint);
    function startBlock() public view returns(uint);
    function endBlock() public view returns(uint);
    function totalTokens() public view returns(uint);
    function remainingTokens() public view returns(uint);
    function price() public view returns(uint);
}

contract UACAC {
    function lockTransfer(bool _lock) public;

    function issueTokens(address _who, uint _tokens) public;

    function balanceOf(address _owner) public constant returns (uint256);
}

contract PreSaleVestingAC {
    function finishIco();
}

contract FoundersVestingAC {
    function finishIco() public;
}

contract UbiatarPlayAC {
    function finishIco();
}

// This is the main UbiatarCoin ICO smart contract
contract ICO is Owned, ICOEngineInterface {

    using SafeMath for uint;

    uint collectedWei = 0;

    // Standard token price is 200 dollar CENTS per token
    uint public usdTokenPrice = 2 * 100;

    // The USD/ETH
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    // This value is given in dollar CENTS
    uint public usdPerEth = 1100 * 100;

    // Founders reward
    uint public constant FOUNDERS_REWARD = 12000000 * 1 ether;
    // Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 17584778551358900100698693;
    // 15 000 000 tokens sold during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;
    // Tokens for advisors
    uint public constant ADVISORS_TOKENS = 4915221448641099899301307;
    // 50 500 000 tokens for Ubiatar Play
    uint public constant UBIATARPLAY_TOKENS = 50500000 * 1 ether;

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
    // This is where UBIATARPLAY_TOKENS will be allocated
    address public ubiatarPlayAddress = 0x0;

    address public uacTokenAddress = 0x0;

    address public unsoldContractAddress = 0x0;

    address public advisorsWalletAddress = 0x0;

    address public ubiatarColdWallet = 0x0;

    UACAC public uacToken;

    PreSaleVestingAC public preSaleVesting;

    FoundersVestingAC public foundersVesting;

    UbiatarPlayAC public ubiatarPlay;

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

    modifier onlyBeforeBlockNumber()
    {
        require(block.number < icoBlockNumberStart);
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
    event LogBuy(address owner, uint value);
    event LogBurn(address owner, uint value);
    event LogWithdraw(address to, uint value);
    event LogOverflow(address to, uint value);
    event LogRefund(address to, uint value);
    event LogUbiatarColdWalletSet(address ubiatarColdWallet);
    event LogAdvisorsWalletAddressSet(address advisorsWalletAddress);
    event LogUbiatarPlayAddressSet(address ubiatarPlayAddress);
    event LogUacTokenAddressSet(address uacTokenAddress);
    event LogUnsoldContractAddressSet(address unsoldContractAddress);
    event LogFoundersVestingAddressSet(address foundersVestingAddress);
    event LogPreSaleVestingAddressSet(address preSaleVestingAddress);
    event LogBlockNumberStartSet(uint icoBlockNumberStart);
    event LogIcoFinishTimeSet(uint icoFinishTime);
    event LogUsdPerEthRateSet(uint usdPerEth);
    event LogUsdTokenPrice(uint usdTokenPrice);
    event LogStartICO();
    event LogPauseICO();
    event LogResumeICO();
    event LogFinishICO();

    // Functions:
    /// @dev Constructor
    function ICO
    (
        address _uacTokenAddress,
        address _unsoldContractAddress,
        address _foundersVestingAddress,
        address _preSaleVestingAddress,
        address _ubiatarPlayAddress,
        address _advisorsWalletAddress
    )
    {
        uacToken = UACAC(_uacTokenAddress);
        preSaleVesting = PreSaleVestingAC(_preSaleVestingAddress);
        foundersVesting = FoundersVestingAC(_foundersVestingAddress);
        ubiatarPlay = UbiatarPlayAC(_ubiatarPlayAddress);

        uacTokenAddress = _uacTokenAddress;
        unsoldContractAddress = _unsoldContractAddress;
        foundersVestingAddress = _foundersVestingAddress;
        preSaleVestingAddress = _preSaleVestingAddress;
        ubiatarPlayAddress = _ubiatarPlayAddress;
        advisorsWalletAddress = _advisorsWalletAddress;
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
        uacToken.issueTokens(advisorsWalletAddress, ADVISORS_TOKENS);
        uacToken.issueTokens(ubiatarPlayAddress, UBIATARPLAY_TOKENS);
        LogStartICO();
    }

    function pauseICO()
    public
    onlyOwner
    onlyInState(State.ICORunning)
    {
        setState(State.ICOPaused);
        LogPauseICO();
    }

    function resumeICO()
    public
    onlyOwner
    onlyInState(State.ICOPaused)
    {
        setState(State.ICORunning);
        LogResumeICO();
    }

    function withdraw(uint withdrawAmount)
    public
    onlyOwner
    {
        require(ubiatarColdWallet != 0x0);
        if(withdrawAmount > this.balance) {
            withdrawAmount = this.balance;
        }
        ubiatarColdWallet.transfer(withdrawAmount);
        LogWithdraw(ubiatarColdWallet, withdrawAmount);
    }

    /// This function can be called by owner only when the ICO is finished
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
            LogBurn(unsoldContractAddress, icoTokensUnsold);
        }

        preSaleVesting.finishIco();
        ubiatarPlay.finishIco();
        foundersVesting.finishIco();
        LogFinishICO();
    }

    function refund()
    public
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
    internal
    onlyInState(State.ICORunning)
    onlyBeforeIcoFinishTime
    onlyAfterBlockNumber
    {
        require(msg.value >= 100 finney);

        uint bonusPercent = 0;

        if(block.number < icoBlockNumberStart + 10164)
        {
            bonusPercent = 4;
        }

        if(block.number < icoBlockNumberStart + 2541)
        {
            bonusPercent = 6;
        }

        if(block.number < icoBlockNumberStart + 635)
        {
            bonusPercent = 8;
        }

        uint newTokens = (msg.value * getUacTokensPerEth(bonusPercent)) / 1 ether;

        if ((icoTokensSold + newTokens) <= ICO_TOKEN_SUPPLY_LIMIT)
        {
            issueTokensInternal(_buyer, newTokens);

            // This is total collected ETH
            collectedWei = collectedWei.add(msg.value);
        }
        else
        {
            uint tokensBought = ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
            uint _refundAmount = msg.value.sub((tokensBought.div(getUacTokensPerEth(bonusPercent))).mul(1 ether));
            require(_refundAmount < msg.value);
            refundAmount = _refundAmount;
            toBeRefund = _buyer;
            LogOverflow(_buyer, _refundAmount);

            issueTokensInternal(_buyer, tokensBought);

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

    function setUbiatarColdWallet(address _ubiatarColdWallet)
    public
    onlyOwner
    {
        ubiatarColdWallet =_ubiatarColdWallet;
        LogUbiatarColdWalletSet(ubiatarColdWallet);
    }

    function setAdvisorsWalletAddress(address _advisorsWalletAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        advisorsWalletAddress = _advisorsWalletAddress;
        LogAdvisorsWalletAddressSet(advisorsWalletAddress);
    }

    function setUbiatarPlayAddress(address _ubiatarPlayAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        ubiatarPlayAddress = _ubiatarPlayAddress;
        ubiatarPlay = UbiatarPlayAC(_ubiatarPlayAddress);
        LogUbiatarPlayAddressSet(ubiatarPlayAddress);
    }

    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UACAC(_uacTokenAddress);
        LogUacTokenAddressSet(uacTokenAddress);
    }

    function setUnsoldContractAddress(address _unsoldContractAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        unsoldContractAddress = _unsoldContractAddress;
        LogUnsoldContractAddressSet(unsoldContractAddress);
    }

    function setFoundersVestingAddress(address _foundersVestingAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        foundersVestingAddress = _foundersVestingAddress;
        foundersVesting = FoundersVestingAC(_foundersVestingAddress);
        LogFoundersVestingAddressSet(foundersVestingAddress);
    }

    function setPreSaleVestingAddress(address _preSaleVestingAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        preSaleVestingAddress = _preSaleVestingAddress;
        preSaleVesting = PreSaleVestingAC(_preSaleVestingAddress);
        LogPreSaleVestingAddressSet(preSaleVestingAddress);
    }

    function setBlockNumberStart(uint _blockNumber)
    public
    onlyOwner
    {
        icoBlockNumberStart = _blockNumber;
        LogBlockNumberStartSet(icoBlockNumberStart);
    }

    function setIcoFinishTime(uint _time)
    public
    onlyOwner
    {
        icoFinishTime = _time;
        LogIcoFinishTimeSet(icoFinishTime);
    }

    function setUsdPerEthRate(uint _usdPerEthRate)
    public
    onlyOwner
    {
        usdPerEth = _usdPerEthRate;
        LogUsdPerEthRateSet(usdPerEth);
    }

    function setState(State _s)
    internal
    {
        currentState = _s;
        LogStateSwitch(_s);
    }

    function setUsdTokenPrice(uint tokenPrice)
    public
    onlyOwner
    {
        usdTokenPrice = tokenPrice;
        LogUsdTokenPrice(usdTokenPrice);
    }

    // Getters

    function getBlockNumberStart()
    constant
    public
    returns (uint)
    {
        return icoBlockNumberStart;
    }

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

    function getUacTokensPerEth(uint bonusPercent)
    constant
    internal
    returns (uint)
    {
        uint tokenPrice = (usdTokenPrice * 100) / (100 + bonusPercent);
        uint uacPerEth = (usdPerEth * 1 ether) / tokenPrice;
        return uacPerEth;
    }

    // ICOEngineInterface

    // false if the ico is not started, true if the ico is started and running, true if the ico is completed
    function started()
    public
    view
    returns(bool)
    {
        if(currentState == State.ICORunning || currentState == State.ICOFinished)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    // false if the ico is not started, false if the ico is started and running, true if the ico is completed
    function ended()
    public
    view
    returns(bool)
    {
        if(currentState == State.ICOFinished)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    // time stamp of the starting time of the ico, must return 0 if it depends on the block number
    function startTime()
    public
    view
    returns(uint)
    {
        return 0;
    }

    // time stamp of the ending time of the ico, must return 0 if it depends on the block number
    function endTime()
    public
    view
    returns(uint)
    {
        return icoFinishTime;
    }

    // Optional function, can be implemented in place of startTime
    // Returns the starting block number of the ico, must return 0 if it depends on the time stamp
     function startBlock()
     public
     view
     returns(uint)
     {
        return icoBlockNumberStart;
     }

    // Optional function, can be implemented in place of endTime
    // Returns theending block number of the ico, must retrun 0 if it depends on the time stamp
     function endBlock()
     public
     view
     returns(uint)
     {
        return 0;
     }

    // returns the total number of the tokens available for the sale, must not change when the ico is started
    function totalTokens()
    public
    view
    returns(uint)
    {
        return ICO_TOKEN_SUPPLY_LIMIT;
    }

    // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
    // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
    function remainingTokens()
    public
    view
    returns(uint)
    {
        return ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
    }

    // return the price as number of tokens released for each ether
    function price()
    public
    view
    returns(uint)
    {
        uint bonusPercent = 0;

        if(block.number < icoBlockNumberStart + 10164)
        {
            bonusPercent = 4;
        }

        if(block.number < icoBlockNumberStart + 2541)
        {
            bonusPercent = 6;
        }

        if(block.number < icoBlockNumberStart + 635)
        {
            bonusPercent = 8;
        }

        return getUacTokensPerEth(bonusPercent);
    }

    function buyTokensFor(address _to)
    payable
    public {
        // buyTokens -> issueTokensInternal
        buyTokens(_to);
    }

    // Default fallback function
    function() payable {
        // buyTokens -> issueTokensInternal
        buyTokens(msg.sender);
    }
}
