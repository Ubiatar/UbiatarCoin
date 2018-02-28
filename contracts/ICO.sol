pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Owned.sol";

contract UAC {
    function lockTransfer(bool _lock);
    function issueTokens(address _who, uint _tokens);
    function balanceOf(address _owner) public constant returns (uint256);
}

contract PreSaleVesting {
    function icoFinished();
}

contract FoundersVesting {

}

contract Bounties {

}

contract UbiatarPlay {
    function icoFinished();
}

// This is the main UbiatarCoin ICO smart contract
contract ICO is Owned {

    using SafeMath for uint;

    address[] public multisigs;

    uint public reservedTokens = 0;

    uint collectedWei = 0;

    // Standard token price is 200 dollar CENTS per token
    uint public usdTokenPrice = 2 * 100;

    // The USD/ETH
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    // This value is given in dollar CENTS
    uint public usdPerEth = 1100 * 100;

    // Founders reward
    uint public constant FOUNDERS_REWARD = 0 * 1 ether;
    // Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 17584778551358900100698693;
    // 15 000 000 tokens sold during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;
    // 3 000 000 tokens for bounties
    uint public constant BOUNTIES_TOKENS = 3000000 * 1 ether;
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

    address public bountiesWalletAddress = 0x0;

    UAC public uacToken;

    PreSaleVesting public preSaleVesting;

    FoundersVesting public foundersVesting;

    Bounties public bounties;

    UbiatarPlay public ubiatarPlay;

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
        require((uint(now) >= icoFinishTime) || (icoTokensSold + reservedTokens == ICO_TOKEN_SUPPLY_LIMIT));
        _;
    }

    // Events:
    event LogStateSwitch(State newState);
    event LogBuy(address owner, uint value);
    event LogBurn(address owner, uint value);
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
        address _preSaleVestingAddress,
        address _ubiatarPlayAddress
    )
    {
        uacToken = UAC(_uacTokenAddress);
        preSaleVesting = PreSaleVesting(_preSaleVestingAddress);
        foundersVesting = FoundersVesting(_foundersVestingAddress);
        ubiatarPlay = UbiatarPlay(_ubiatarPlayAddress);

        uacTokenAddress = _uacTokenAddress;
        unsoldContractAddress = _unsoldContractAddress;
        foundersVestingAddress = _foundersVestingAddress;
        preSaleVestingAddress = _preSaleVestingAddress;
        ubiatarPlayAddress = _ubiatarPlayAddress;
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
        uacToken.issueTokens(bountiesWalletAddress, BOUNTIES_TOKENS);
        uacToken.issueTokens(ubiatarPlayAddress, UBIATARPLAY_TOKENS);
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
        ubiatarPlay.icoFinished();

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

    function buyTokens(address _buyer, uint bonusPercent)
    internal
    onlyInState(State.ICORunning)
    onlyBeforeIcoFinishTime
    onlyAfterBlockNumber
    {
        require(msg.value >= 100 finney);

        uint newTokens = (msg.value * getUacTokensPerEth(bonusPercent)) / 1 ether;

          if ((icoTokensSold + reservedTokens + newTokens) <= ICO_TOKEN_SUPPLY_LIMIT)
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
        require((icoTokensSold + icoTokensSold + _tokens) <= ICO_TOKEN_SUPPLY_LIMIT);

        uacToken.issueTokens(_to, _tokens);
        icoTokensSold += _tokens;

        LogBuy(_to, _tokens);
    }

    //Setters

    function setBountiesWalletAddress(address _bountiesWalletAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        bountiesWalletAddress = _bountiesWalletAddress;
    }

    function setUbiatarPlayAddress(address _ubiatarPlayAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        ubiatarPlayAddress = _ubiatarPlayAddress;
        ubiatarPlay = UbiatarPlay(_ubiatarPlayAddress);
    }

    function setUacTokenAddress(address _uacTokenAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UAC(_uacTokenAddress);
    }

    function setUnsoldContractAddress(address _unsoldContractAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        unsoldContractAddress = _unsoldContractAddress;
    }

    function setFoundersVestingAddress(address _foundersVestingAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        foundersVestingAddress = _foundersVestingAddress;
        foundersVesting = FoundersVesting(_foundersVestingAddress);
    }

    function setPreSaleVestingAddress(address _preSaleVestingAddress)
    public
    onlyOwner
    onlyInState(State.Init)
    {
        preSaleVestingAddress = _preSaleVestingAddress;
        preSaleVesting = PreSaleVesting(_preSaleVestingAddress);
    }

    function setBlockNumberStart(uint _blockNumber)
    public
    onlyOwner
    {
        icoBlockNumberStart = _blockNumber;
    }

    function setIcoFinishTime(uint _time)
    public
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
    public
    onlyOwner
    {
        usdTokenPrice = tokenPrice;
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
        return (currentState == State.ICOFinished || icoTokensSold + reservedTokens >= ICO_TOKEN_SUPPLY_LIMIT);
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

    function buyTokensFor(address _to)
    payable
    public{
        // buyTokens -> issueTokensInternal
        buyTokens(_to, 0);
    }

    // Default fallback function
    function() payable {
        // buyTokens -> issueTokensInternal
        buyTokens(msg.sender, 0);
    }
}
