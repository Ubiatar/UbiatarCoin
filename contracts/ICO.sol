pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./UAC.sol";
import "./UACUnsold.sol";
import "./Owned.sol";

// This is the main UbiatarCoin ICO smart contract
contract ICO is Owned{

    using SafeMath for uint;

    // We count ETH invested by person, for refunds (see below)
    mapping(address => uint) ethInvestedBy;
    uint collectedWei = 0;

    // These can be changed before ICO starts
    // uint constant STD_PRICE_USD_PER_1000_TOKENS = 7000;

    // Standard token price is 2 dollars per token
    uint usdTokenPrice = 2;

    // The USD/ETH exchange rate may be changed every hour and can vary from $100 to $700 depending on the market. The exchange rate is retrieved from coinmarketcap.com site and is rounded to $1 dollar. For example if current marketcap price is $306.123 per ETH, the price is set as $306 to the contract.
    // Should probably change limits
    uint public usdPerEthCoinmarketcapRate = 300;
    uint64 public lastUsdPerEthChangeDate = 0;

    // Price changes from block to block
    uint constant SINGLE_BLOCK_LEN = 700000;
    // 1 000 000 tokens
    uint public constant BONUS_REWARD = 1000000 * 1 ether;
    // 2 000 000 tokens
    uint public constant FOUNDERS_REWARD = 2000000 * 1 ether;
    // Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 0 * 1 ether;
    // 15 000 000 is sold during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;

    // 3 000 000 can be issued from other currencies
    uint public constant MAX_ISSUED_FROM_OTHER_CURRENCIES = 3000000 * 1 ether;
    // 30 000 MNTP tokens per one call only
    uint public constant MAX_SINGLE_ISSUED_FROM_OTHER_CURRENCIES = 30000 * 1 ether;
    uint public issuedFromOtherCurrencies = 0;

    // Fields:
    address public creator = 0x0;                // can not be changed after deploy
    address public ethRateChanger = 0x0;         // can not be changed after deploy
    address public tokenManager = 0x0;           // can be changed by token manager only
    address public otherCurrenciesChecker = 0x0; // can not be changed after deploy

    uint64 public icoStartedTime = 0;

    UAC public uacToken;

    UACUnsold public unsoldContract;

    // Total amount of tokens sold during ICO
    uint public icoTokensSold = 0;
    // Total amount of tokens sent to UACUnsold contract after ICO is finished
    uint public icoTokensUnsold = 0;
    // Total number of tokens that were issued by a scripts
    uint public issuedExternallyTokens = 0;
    // This is where FOUNDERS_REWARD will be allocated
    address public foundersRewardsAccount = 0x0;
    // This is where PRESALE_REWARD will be allocated
    address public preSaleRewardsAccount = 0x0;
    // This is the percent discount applied at the moment
    uint public discountPercent = 0;

    enum State{
        Init,

        ICORunning,
        ICOPaused,

        // Collected ETH is transferred to multisigs.
        // Unsold tokens transferred to UACUnsold contract.
        ICOFinished,

        // In this state we lock all UAC tokens forever.
        //
        // There is no any possibility to transfer tokens
        // There is no any possibility to move back
        Migrating
    }
    State public currentState = State.Init;

    // Modifiers:
    modifier onlyCreator() {
        require(msg.sender==creator);
        _;
    }
    modifier onlyTokenManager() {
        require(msg.sender==tokenManager);
        _;
    }
    modifier onlyOtherCurrenciesChecker() {
        require(msg.sender==otherCurrenciesChecker);
        _;
    }
    modifier onlyEthSetter() {
        require(msg.sender==ethRateChanger);
        _;
    }

    modifier onlyInState(State state){
        require(state==currentState);
        _;
    }

    // Events:
    event LogStateSwitch(State newState);
    event LogBuy(address indexed owner, uint value);
    event LogBurn(address indexed owner, uint value);
    event LogWithdraw(address to, uint value);

    // Functions:
    /// @dev Constructor
    function ICO(
        address _tokenManager,
        address _ethRateChanger,
        address _otherCurrenciesChecker,

        address _uacTokenAddress,
        address _unsoldContractAddress,
        address _foundersVestingAddress,
        address _preSaleVestingAddress)
    {
        creator = msg.sender;

        tokenManager = _tokenManager;
        ethRateChanger = _ethRateChanger;
        lastUsdPerEthChangeDate = uint64(now);

        otherCurrenciesChecker = _otherCurrenciesChecker;

        uacToken = UAC(_uacTokenAddress);
        unsoldContract = UACUnsold(_unsoldContractAddress);

        // slight rename
        foundersRewardsAccount = _foundersVestingAddress;

        preSaleRewardsAccount = _preSaleVestingAddress;
    }

    function startICO() public onlyCreator onlyInState(State.Init) {
        setState(State.ICORunning);
        icoStartedTime = uint64(now);
        uacToken.lockTransfer(true);
        uacToken.issueTokens(foundersRewardsAccount, FOUNDERS_REWARD);
        uacToken.issueTokens(preSaleRewardsAccount, PRESALE_REWARD);
    }

    function pauseICO() public onlyCreator onlyInState(State.ICORunning) {
        setState(State.ICOPaused);
    }

    function resumeICO() public onlyCreator onlyInState(State.ICOPaused) {
        setState(State.ICORunning);
    }

    // Shouldn't be necessary since we don't have a soft cap
   /* function startRefunding() public onlyCreator onlyInState(State.ICORunning) {
        // only switch to this state if less than ICO_TOKEN_SOFT_CAP sold
        require(icoTokensSold < ICO_TOKEN_SOFT_CAP);
        setState(State.Refunding);

        // in this state tokens still shouldn't be transferred
        assert(uacToken.lockTransfers());
    } */

    function startMigration() public onlyCreator onlyInState(State.ICOFinished) {
        // there is no way back...
        setState(State.Migrating);

        // disable token transfers
        uacToken.lockTransfer(true);
    }

    /// @dev This function can be called by creator at any time,
    /// or by anyone if ICO has really finished.
    /// Should we change it to be callable only by creator?
    function finishICO() public onlyInState(State.ICORunning) {
        require(msg.sender == creator || isIcoFinished());
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
        // uint sendThisAmount = (this.balance / 10);

        // 3.1 - send to 9 multisigs
       /* for(uint i=0; i<9; ++i){
            address ms = multisigs[i];

            if(this.balance>=sendThisAmount){
                ms.transfer(sendThisAmount);
            }
        }*/

        // 3.2 - send everything left to 10th multisig
       /* if(0!=this.balance){
            address lastMs = multisigs[9];
            lastMs.transfer(this.balance);
        }*/
    }

    function setState(State _s) internal {
        currentState = _s;
        LogStateSwitch(_s);
    }

    function setDiscountPercent(uint _discountPercent) public onlyTokenManager {
        discountPercent = _discountPercent;
    }

    // Access methods:
    function setTokenManager(address _new) public onlyTokenManager {
        tokenManager = _new;
    }
    /*
    function setOtherCurrenciesChecker(address _new) public onlyCreator {
         otherCurrenciesChecker = _new;
    }
    */

    // These are used by frontend so we can not remove them
    function getTokensIcoSold() constant public returns (uint){
        return icoTokensSold;
    }

    function getTotalIcoTokens() constant public returns (uint){
        return ICO_TOKEN_SUPPLY_LIMIT;
    }

    function getUacTokenBalance(address _of) constant public returns (uint){
        return uacToken.balanceOf(_of);
    }

    function getBlockLength()constant public returns (uint){
        return SINGLE_BLOCK_LEN;
    }

    function getCurrentPrice()constant public returns (uint){
        return getUacTokensPerEth(discountPercent);
    }

    function getTotalCollectedWei()constant public returns (uint){
        return collectedWei;
    }

    function isIcoFinished() constant public returns(bool) {
        return (icoStartedTime > 0)
        && (now > (icoStartedTime + 30 days) || (icoTokensSold >= ICO_TOKEN_SUPPLY_LIMIT));
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
        uint uacPerEth = (usdPerEthCoinmarketcapRate * 1000 * 1 ether * 1 ether) / pricePer1000tokensUsd;
        return uacPerEth;
    }*/

    function getUacTokensPerEth(uint discountPercent) public constant returns (uint) {

        uint tokenPrice = (usdTokenPrice * 100) / (100 + discountPercent);
        uint uacPerEth = (usdPerEthCoinmarketcapRate * 100 * 1 ether * 1 ether) / tokenPrice;
        return uacPerEth;
    }


    function buyTokens(address _buyer) public payable onlyInState(State.ICORunning) {
        require(msg.value!=0);

        // The price is selected based on current sold tokens.
        // Price can 'overlap'. For example:
        //   1. if currently we sold 699950 tokens (the price is 10% discount)
        //   2. buyer buys 1000 tokens
        //   3. the price of all 1000 tokens would be with 10% discount!!!
        uint newTokens = (msg.value * getUacTokensPerEth(discountPercent)) / 1 ether;

        issueTokensInternal(_buyer,newTokens);

        // Update this only when buying from ETH
        ethInvestedBy[msg.sender] = ethInvestedBy[msg.sender].add(msg.value);

        // This is total collected ETH
        collectedWei = collectedWei.add(msg.value);
    }

    /// @dev This is called by other currency processors to issue new tokens
    function issueTokensFromOtherCurrency(address _to, uint _weiCount) onlyInState(State.ICORunning) public onlyOtherCurrenciesChecker {
        require(_weiCount!=0);

        uint newTokens = (_weiCount * getUacTokensPerEth(discountPercent)) / 1 ether;

        require(newTokens<=MAX_SINGLE_ISSUED_FROM_OTHER_CURRENCIES);
        require((issuedFromOtherCurrencies + newTokens)<=MAX_ISSUED_FROM_OTHER_CURRENCIES);

        issueTokensInternal(_to,newTokens);

        issuedFromOtherCurrencies = issuedFromOtherCurrencies + newTokens;
    }

    /// @dev This can be called to manually issue new tokens
    /// from the bonus reward
    function issueTokensExternal(address _to, uint _tokens) public onlyTokenManager {
        // in 2 states
        require((State.ICOFinished==currentState) || (State.ICORunning==currentState));
        // can not issue more than BONUS_REWARD
        require((issuedExternallyTokens + _tokens)<=BONUS_REWARD);

        uacToken.issueTokens(_to,_tokens);

        issuedExternallyTokens = issuedExternallyTokens + _tokens;
    }

    function issueTokensInternal(address _to, uint _tokens) internal {
        require((icoTokensSold + _tokens)<=ICO_TOKEN_SUPPLY_LIMIT);

        uacToken.issueTokens(_to,_tokens);
        icoTokensSold+=_tokens;

        LogBuy(_to,_tokens);
    }

    // anyone can call this and get his money back
    // Should we have this function?
   /* function getMyRefund() public onlyInState(State.Refunding) {
        address sender = msg.sender;
        uint ethValue = ethInvestedBy[sender];

        require(ethValue > 0);

        ethInvestedBy[sender] = 0;
        uacToken.burnTokens(sender, uacToken.balanceOf(sender));

        sender.transfer(ethValue);
    }*/

    // Should probably remove the required limits
    function setUsdPerEthRate(uint _usdPerEthRate) public onlyEthSetter {
        // 1 - check
        require((_usdPerEthRate>=100) && (_usdPerEthRate<=700));
        uint64 hoursPassed = lastUsdPerEthChangeDate + 1 hours;
        require(uint(now) >= hoursPassed);

        // 2 - update
        usdPerEthCoinmarketcapRate = _usdPerEthRate;
        lastUsdPerEthChangeDate = uint64(now);
    }

    function withdraw ()
    onlyOwner
    {
        uint256 value = this.balance;
        owner.transfer(this.balance);
        LogWithdraw(owner, value);
    }

    // Default fallback function
    function() payable {
        // buyTokens -> issueTokensInternal
        buyTokens(msg.sender);
    }
}
