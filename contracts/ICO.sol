pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";

/*
    Eidoo ICO Engine interface
    This interface enables Eidoo wallet to query our ICO and display all the informations needed in the app
*/
contract ICOEngineInterface {
    function started() public view returns (bool);

    function ended() public view returns (bool);

    function startTime() public view returns (uint);

    function endTime() public view returns (uint);

    function startBlock() public view returns (uint);

    function endBlock() public view returns (uint);

    function totalTokens() public view returns (uint);

    function remainingTokens() public view returns (uint);

    function price() public view returns (uint);
}

// UbiatarCoin Abstract Contract
contract UACAC {
    function lockTransfer(bool _lock) public;

    function issueTokens(address _who, uint _tokens) public;

    function balanceOf(address _owner) public constant returns (uint256);
}

// PreSaleVesting Abstract Contract
contract PreSaleVestingAC {
    function finishIco() public;
}

// Founders Vesting Abstract Contract
contract FoundersVestingAC {
    function finishIco() public;
}

// UbiatarPlay Abstract Contract
contract UbiatarPlayAC {
    function finishIco() public;
}

/*
    ICO crowdsale main contract
    It is in charge to issue all the token for the ICO, preSales, advisors and founders vesting
*/
contract ICO is Ownable, ICOEngineInterface {

    // SafeMath standard lib
    using SafeMath for uint;

    // total Wei collected during the ICO
    uint collectedWei = 0;

    // Standard token price in USD CENTS per token
    uint public usdTokenPrice = 2 * 100;

    // The USD/ETH
    // UPDATE CHANGE RATE WITH CURRENT RATE WHEN DEPLOYING
    // This value is given in USD CENTS
    uint public usdPerEth = 1100 * 100;

    // Founders reward
    uint public constant FOUNDERS_REWARD = 12000000 * 1 ether;
    // Total Tokens bought in PreSale
    uint public constant PRESALE_REWARD = 17584778551358900100698693;
    // 15 000 000 tokens on sale during the ICO
    uint public constant ICO_TOKEN_SUPPLY_LIMIT = 15000000 * 1 ether;
    // Tokens for advisors
    uint public constant ADVISORS_TOKENS = 4915221448641099899301307;
    // 50 500 000 tokens for Ubiatar Play
    uint public constant UBIATARPLAY_TOKENS = 50500000 * 1 ether;
    // 7 500 000 tokens for Reservation contract campaign
    uint public constant RC_TOKEN_LIMIT = 7500000 * 1 ether;

    /// Fields:

    // ICO starting block number
    uint public icoBlockNumberStart = 5305785;

    // ICO finish time in epoch time
    uint public icoFinishTime = 1524488400;

    // ICO partecipant to be refund in case of overflow on the last token purchase
    address public toBeRefund = 0x0;
    // ICO refund amount in case of overflow on the last token purchase
    uint public refundAmount;
    // Reservation contract participant to be refund in case of overflow on the last token purchase
    address public toBeRefundRC = 0x0;
    // Reservation contract participant to be refund in case of overflow on the last token purchase
    uint public refundAmountRC = 0;



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
    // UbiatarCoin ERC20 address
    address public uacTokenAddress = 0x0;
    // Unsold token contract address
    address public unsoldContractAddress = 0x0;
    // This is where ADVISORS_TOKEN will be allocated
    address public advisorsWalletAddress = 0x0;
    // This is where Ethers will be transfered
    address public ubiatarColdWallet = 0x0;
    // Reservation contract address
    address public RCContractAddress = 0x0;

    // UbiatarCoin contract reference
    UACAC public uacToken;
    // PreSaleVesting contract reference
    PreSaleVestingAC public preSaleVesting;
    // FoundersVesting contract reference
    FoundersVestingAC public foundersVesting;
    // UbiatarPlay contract reference
    UbiatarPlayAC public ubiatarPlay;

    // ICO possibles state.
    enum State
    {
        Init,
        ICORunning,
        ICOFinished
    }

    // ICO current state, initialized with Init state
    State public currentState = State.Init;

    /// Modifiers

    // Only in a given ICO state
    modifier onlyInState(State state)
    {
        require(state == currentState);
        _;
    }

    // Only before ICO crowdsale starting block number
    modifier onlyBeforeBlockNumber()
    {
        require(block.number < icoBlockNumberStart);
        _;
    }

    // Only after ICO crowdsale starting block number
    modifier onlyAfterBlockNumber()
    {
        require(block.number >= icoBlockNumberStart);
        _;
    }

    // Only before ICO crowdsale finishing epoch time
    modifier onlyBeforeIcoFinishTime()
    {
        require(uint(now) <= icoFinishTime);
        _;
    }

    // Only if ICO can finish (so after finishing epoch time, or when all tokens are sold)
    modifier canFinishICO()
    {
        require((uint(now) >= icoFinishTime) || (icoTokensSold == ICO_TOKEN_SUPPLY_LIMIT));
        _;
    }

    // Can only be called from the reservation contract
    modifier onlyFromRC()
    {
        require(msg.sender == RCContractAddress);
        _;
    }

    /// Events

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
    event LogFinishICO();

    ///  Functions:

    // ICO constructor. It takes main contracts adresses
    function ICO
    (
        address _uacTokenAddress,
        address _unsoldContractAddress,
        address _foundersVestingAddress,
        address _preSaleVestingAddress,
        address _ubiatarPlayAddress,
        address _advisorsWalletAddress
    )
    public
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

    // It will put ICO in Running state, it should be launched before starting block
    function startICO()
    public
    onlyOwner
    onlyInState(State.Init)
    {
        setState(State.ICORunning);
        uacToken.issueTokens(foundersVestingAddress, FOUNDERS_REWARD);
        uacToken.issueTokens(preSaleVestingAddress, PRESALE_REWARD);
        uacToken.issueTokens(advisorsWalletAddress, ADVISORS_TOKENS);
        uacToken.issueTokens(ubiatarPlayAddress, UBIATARPLAY_TOKENS);
        LogStartICO();
    }

    // It allows to withdraw crowdsale Ether only when ICO is finished
    function withdraw(uint withdrawAmount)
    public
    onlyOwner
    onlyInState(State.ICOFinished)
    {
        // Checks if the UbiatarColdWallet address has been set
        require(ubiatarColdWallet != 0x0);

        // If we're trying to withdraw more than the current contract's balance withdraws remaining ether
        if (withdrawAmount > this.balance)
        {
            withdrawAmount = this.balance;
        }

        ubiatarColdWallet.transfer(withdrawAmount);
        LogWithdraw(ubiatarColdWallet, withdrawAmount);
    }

    // It will set ICO in Finished state and it will call finish functions in side contracts
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

        // Calls finish function in other contracts and sets their starting times for the withdraw functions
        preSaleVesting.finishIco();
        ubiatarPlay.finishIco();
        foundersVesting.finishIco();
        LogFinishICO();
    }

    // It will refunds last address in case of overflow
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

    // This is the main function for Token purchase during ICO. It takes a buyer address where tokens should be issued
    function buyTokens(address _buyer)
    internal
    onlyInState(State.ICORunning)
    onlyBeforeIcoFinishTime
    onlyAfterBlockNumber
    {
        // Checks that the investor has sent at least 0.1 ETH
        require(msg.value >= 100 finney);

        uint bonusPercent = 0;
        // Gives 4% of discount for the first 42 hours of the ICO
        if (block.number < icoBlockNumberStart.add(10164))
        {
            bonusPercent = 4;
        }
        // Gives 6% of discount for the first 24 hours of the ICO
        if (block.number < icoBlockNumberStart.add(2541))
        {
            bonusPercent = 6;
        }
        // Gives 8% of discount for the first 3 hours of the ICO
        if (block.number < icoBlockNumberStart.add(635))
        {
            bonusPercent = 8;
        }
        // Calculates the amount of tokens to be issued by multiplying the amount of ether sent by the number of tokens
        // per ETH. We multiply and divide by 1 ETH to avoid approximation errors
        uint newTokens = (msg.value.mul(getUacTokensPerEth(bonusPercent))).div(1 ether);

        // Checks if there are enough tokens left to be issued, if not
        if ((icoTokensSold.add(newTokens)) <= ICO_TOKEN_SUPPLY_LIMIT)
        {
            issueTokensInternal(_buyer, newTokens);

            collectedWei = collectedWei.add(msg.value);
        }
        // Refund function, calculates the amount of tokens still available and issues them to the investor, then calculates
        // the amount of etther to be sent back
        else
        {
            // Calculates the amount of token remaining in the ICO
            uint tokensBought = ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
            // Calculates the amount of ETH to be sent back to the buyer depending on the amount of tokens still available
            // at the moment of the purchase
            uint _refundAmount = msg.value.sub((tokensBought.div(getUacTokensPerEth(bonusPercent))).mul(1 ether));
            // Checks if the refund amount is actually less than the ETH sent by the investor then saves the amount to
            // be refund and the address which will receive the refund
            require(_refundAmount < msg.value);
            refundAmount = _refundAmount;
            toBeRefund = _buyer;
            LogOverflow(_buyer, _refundAmount);

            issueTokensInternal(_buyer, tokensBought);

            collectedWei = collectedWei.add(msg.value).sub(_refundAmount);
        }
    }

    // Same as buyTokens, can only be called by the reservation contract and sets the bonus percent to 10%
    function buyTokensRC(address _buyer)
    public
    payable
    onlyFromRC
    {
        // Checks that the investor has sent at least 0.1 ETH
        require(msg.value >= 100 finney);


        uint bonusPercent = 10;

        // Calculates the amount of tokens to be issued by multiplying the amount of ether sent by the number of tokens
        // per ETH. We multiply and divide by 1 ETH to avoid approximation errors
        uint newTokens = (msg.value.mul(getUacTokensPerEth(bonusPercent))).div(1 ether);

        // Checks if the amount of tokens to be sold is lower than the amount of tokens available to the reservation contract
        if ((icoTokensSold.add(newTokens)) <= RC_TOKEN_LIMIT)
        {
            issueTokensInternal(_buyer, newTokens);

            collectedWei = collectedWei.add(msg.value);
        }
        // Refund function, calculates the amount of tokens still available and issues them to the investor, then calculates
        // the amount of etther to be sent back
        else
        {
            // Calculates the amount of token still available to the reservation contract
            uint tokensBought = RC_TOKEN_LIMIT.sub(icoTokensSold);
            // Calculates the amount of ETH to be sent back to the buyer depending on the amount of tokens still available
            // at the moment of the purchase
            uint _refundAmount = msg.value.sub((tokensBought.div(getUacTokensPerEth(bonusPercent))).mul(1 ether));
            // Checks if the refund amount is actually less than the ETH sent by the investor then saves the amount to
            // be refund and the address which will receive the refund
            require(_refundAmount < msg.value);
            refundAmountRC = _refundAmount;
            toBeRefundRC = _buyer;
            issueTokensInternal(_buyer, tokensBought);

            LogOverflow(_buyer, _refundAmount);

            collectedWei = collectedWei.add(msg.value).sub(_refundAmount);
        }
    }

    // It is an internal function that will call UAC ERC20 contract to issue the tokens
    function issueTokensInternal(address _to, uint _tokens)
    internal
    {
        require((icoTokensSold.add(_tokens)) <= ICO_TOKEN_SUPPLY_LIMIT);

        uacToken.issueTokens(_to, _tokens);
        icoTokensSold = icoTokensSold.add(_tokens);

        LogBuy(_to, _tokens);
    }

    /// Setters

    function setUbiatarColdWallet(address _ubiatarColdWallet)
    public
    onlyOwner
    {
        ubiatarColdWallet = _ubiatarColdWallet;
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

    function setRcContractAddress(address _RCContractAddress)
    public
    onlyOwner
    {
        RCContractAddress = _RCContractAddress;
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

    // It will set ICO crowdsale starting block number
    function setBlockNumberStart(uint _blockNumber)
    public
    onlyOwner
    {
        icoBlockNumberStart = _blockNumber;
        LogBlockNumberStartSet(icoBlockNumberStart);
    }

    // It will set ICO finishing epoch time
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

    // It will switch ICO State
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

    /// Getters

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
    pure
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

    // Calculates the token price including the bonus percent received from the buyTokens function
    // Returns the amount of UAC per 1 ETH to be given
    function getUacTokensPerEth(uint bonusPercent)
    constant
    internal
    returns (uint)
    {
        uint tokenPrice = (usdTokenPrice.mul(100).mul(1 ether)).div(bonusPercent.add(100));
        uint uacPerEth = (usdPerEth.mul(1 ether).mul(1 ether)).div(tokenPrice);
        return uacPerEth;
    }

    /// ICOEngineInterface

    // false if the ico is not started, true if the ico is started and running, true if the ico is completed
    function started()
    public
    view
    returns (bool)
    {
        if ((currentState == State.ICORunning || currentState == State.ICOFinished) && block.number >= icoBlockNumberStart)
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
    returns (bool)
    {
        return ((uint(now) >= icoFinishTime) || (icoTokensSold == ICO_TOKEN_SUPPLY_LIMIT));
    }

    // time stamp of the starting time of the ico, must return 0 if it depends on the block number
    function startTime()
    public
    view
    returns (uint)
    {
        return 0;
    }

    // time stamp of the ending time of the ico, must return 0 if it depends on the block number
    function endTime()
    public
    view
    returns (uint)
    {
        return icoFinishTime;
    }

    // Optional function, can be implemented in place of startTime
    // Returns the starting block number of the ico, must return 0 if it depends on the time stamp
    function startBlock()
    public
    view
    returns (uint)
    {
        return icoBlockNumberStart;
    }

    // Optional function, can be implemented in place of endTime
    // Returns theending block number of the ico, must retrun 0 if it depends on the time stamp
    function endBlock()
    public
    view
    returns (uint)
    {
        return 0;
    }

    // returns the total number of the tokens available for the sale, must not change when the ico is started
    function totalTokens()
    public
    view
    returns (uint)
    {
        return ICO_TOKEN_SUPPLY_LIMIT;
    }

    // returns the number of the tokens available for the ico. At the moment that the ico starts it must be equal to totalTokens(),
    // then it will decrease. It is used to calculate the percentage of sold tokens as remainingTokens() / totalTokens()
    function remainingTokens()
    public
    view
    returns (uint)
    {
        return ICO_TOKEN_SUPPLY_LIMIT.sub(icoTokensSold);
    }

    // return the price as number of tokens released for each ether
    function price()
    public
    view
    returns (uint)
    {
        uint bonusPercent = 0;

        if (block.number < icoBlockNumberStart.add(10164))
        {
            bonusPercent = 4;
        }

        if (block.number < icoBlockNumberStart.add(2541))
        {
            bonusPercent = 6;
        }

        if (block.number < icoBlockNumberStart.add(635))
        {
            bonusPercent = 8;
        }

        return getUacTokensPerEth(bonusPercent);
    }

    // It allows to buy tokens for an other address than msg.sender
    function buyTokensFor(address _to)
    payable
    public
    {
        // buyTokens -> issueTokensInternal
        buyTokens(_to);
    }

    // Default fallback function
    function()
    payable
    public
    {
        buyTokens(msg.sender);
    }
}
