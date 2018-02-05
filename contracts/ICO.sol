pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./UAC.sol";
import "./UACUnsold.sol";
import "./Owned.sol";

// This is the main UbiatarCoin ICO smart contract
contract ICO is Owned{

    using SafeMath for uint;

    address[] public multisigs;

    // We count ETH invested by person, for refunds (see below)
    //Might not need it
    mapping(address => uint) ethInvestedBy;
    uint collectedWei = 0;

    // These can be changed before ICO starts
    // uint constant STD_PRICE_USD_PER_1000_TOKENS = 7000;

    // Standard token price is 2 dollars per token
    uint public usdTokenPrice = 2;

    // The USD change rate can be changed every hour
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    uint public usdPerEth = 1100;

    // 1 000 000 tokens
    uint public constant BONUS_REWARD = 1000000 * 1 ether;
    // 2 000 000 tokens
    uint public constant FOUNDERS_REWARD = 2000000 * 1 ether;
    // Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 17584778551358900100698693;
    // 15 000 000 is sold during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;

    // Fields:
    address public owner = 0x0;

    uint public icoBlockNumberStart = 5305785;

    UAC public uacToken;

    UACUnsold public unsoldContract;

    // Total amount of tokens sold during ICO
    uint public icoTokensSold = 0;
    // Total amount of tokens sent to UACUnsold contract after ICO is finished
    uint public icoTokensUnsold = 0;
    // This is where FOUNDERS_REWARD will be allocated
    address public foundersRewardsAccount = 0x0;
    // This is where PRESALE_REWARD will be allocated
    address public preSaleRewardsAccount = 0x0;

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
    modifier onlyOwner()
    {
        require(msg.sender==owner);
        _;
    }

    modifier onlyInState(State state)
    {
        require(state==currentState);
        _;
    }

    modifier onlyAfterBlockNumber()
    {
        require(block.number >= icoBlockNumberStart);
        _;
    }

    // Events:
    event LogStateSwitch(State newState);
    event LogBuy(address indexed owner, uint value);
    event LogBurn(address indexed owner, uint value);
    event LogWithdraw(address to, uint value);

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
        owner = msg.sender;

        uacToken = UAC(_uacTokenAddress);
        unsoldContract = UACUnsold(_unsoldContractAddress);

        // slight rename
        foundersRewardsAccount = _foundersVestingAddress;

        preSaleRewardsAccount = _preSaleVestingAddress;
    }

    function startICO()
    public
    onlyOwner
    onlyInState(State.Init)
    {
        setState(State.ICORunning);
        uacToken.lockTransfer(true);
        uacToken.issueTokens(foundersRewardsAccount, FOUNDERS_REWARD);
        uacToken.issueTokens(preSaleRewardsAccount, PRESALE_REWARD);
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

    /// @dev This function can be called by owner at any time,
    function finishICO()
    public
    onlyOwner
    onlyInState(State.ICORunning)
    {
        setState(State.ICOFinished);

        // 1 - lock all transfers
        uacToken.lockTransfer(false);

        // 2 - move all unsold tokens to unsoldTokens contract
        icoTokensUnsold = ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
        if(icoTokensUnsold>0){
            uacToken.issueTokens(unsoldContract,icoTokensUnsold);
            unsoldContract.finishIco();
        }

        // Should be changed to our desired method of storing ether
        // 3 - send all ETH to multisigs
        // we have N separate multisigs for extra security
         uint sendThisAmount = (this.balance / 10);

        // 3.1 - send to 9 multisigs
        for(uint i=0; i<9; ++i){
            address ms = multisigs[i];

            if(this.balance>=sendThisAmount){
                ms.transfer(sendThisAmount);
            }
        }

        // 3.2 - send everything left to 10th multisig
        if(0!=this.balance){
            address lastMs = multisigs[9];
            lastMs.transfer(this.balance);
        }
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

    // These are used by frontend so we can not remove them
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
/*
    function getCurrentPrice()constant public returns (uint){
        return getUacTokensPerEth();
    }
*/
    function getTotalCollectedWei()
    constant
    public
    returns (uint)
    {
        return collectedWei;
    }

    function isIcoFinished()
    constant
    public
    returns(bool)
    {
        return (currentState == State.ICOFinished || icoTokensSold >= ICO_TOKEN_SUPPLY_LIMIT);
    }

    // To be completely rewritten
   /* function getUacTokensPerEth(uint _tokensSold) public constant returns (uint){
        // 10 buckets
        uint priceIndex = (_tokensSold / 1 ether) / SINGLE_BLOCK_LEN;
        assert(priceIndex>=0 && (priceIndex<=9));

        uint8[10] memory discountPercents = [20,15,10,8,6,4,2,0,0,0];

        // We have to multiply by '1 ether' to avoid float truncations
        // Example: ($7000 * 100) / 120 = $5833.33333
        uint pricePer1000tokensUsd =
        ((STD_PRICE_USD_PER_1000_TOKENS * 100) * 1 ether) / (100 + discountPercents[priceIndex]);

        // Correct: 300000 / 5833.33333333 = 51.42857142
        // We have to multiply by '1 ether' to avoid float truncations
        uint uacPerEth = (usdPerEth * 1000 * 1 ether * 1 ether) / pricePer1000tokensUsd;
        return uacPerEth;
    }*/

    function getUacTokensPerEth()
    constant
    returns (uint)
    {
        // Discount to be applied, should be changed to something useful
        uint discountPercent = 0;

        uint tokenPrice = (usdTokenPrice * 100) / (100 + discountPercent);
        uint uacPerEth = (usdPerEth * 1 ether * 1 ether) / tokenPrice;
        return uacPerEth;
    }


    function buyTokens(address _buyer)
    public
    payable
    onlyInState(State.ICORunning)
    onlyAfterBlockNumber
    {
        require(msg.value!=0);

        uint newTokens = (msg.value * getUacTokensPerEth()) / 1 ether;

        issueTokensInternal(_buyer,newTokens);

        // Update this only when buying from ETH
        ethInvestedBy[msg.sender] = ethInvestedBy[msg.sender].add(msg.value);

        // This is total collected ETH
        collectedWei = collectedWei.add(msg.value);
    }

    function issueTokensInternal(address _to, uint _tokens)
    internal
    {
        require((icoTokensSold + _tokens)<=ICO_TOKEN_SUPPLY_LIMIT);

        uacToken.issueTokens(_to,_tokens);
        icoTokensSold+=_tokens;

        LogBuy(_to,_tokens);
    }

    function setUsdPerEthRate(uint _usdPerEthRate)
    public
    onlyOwner
    {
        // 1 - update
        usdPerEth = _usdPerEthRate;
    }

    // Default fallback function
    function() payable {
        // buyTokens -> issueTokensInternal
        buyTokens(msg.sender);
    }
}
