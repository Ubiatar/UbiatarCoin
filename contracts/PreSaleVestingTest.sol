pragma solidity ^0.4.18;

// Maps account addresses and balances from PreSale

import "./SafeMath.sol";
import "./Owned.sol";

contract UAC {
    function transfer(address _to, uint256 _value) public returns(bool);
}

contract PreSaleVestingTest is Owned
{

    using SafeMath for uint;

    uint public firstThreshold;
    uint public secondThreshold;

    bool public icoFinished = false;

    address public icoContractAddress = 0x0;

    address public uacTokenAddress =0x0;

    struct Investor
    {
        uint initialBalance;
        uint balance;
        uint lastWithdrawTime;
        uint8 firstWithdraw;
    }

    mapping(address => Investor) investors;


    UAC public uacToken;

    function PreSaleVestingTest(address _uacTokenAddress)
    {
        require(_uacTokenAddress != 0x0);

        investors[address(0x7fe01ff0aDaF111A94ad0d69eD27cDe23553AF44)].initialBalance = 266955000000000513888375;
        investors[address(0xBEED6764508667b0dA60BA354F5BE2d34797AeA3)].initialBalance = 12025000000000023148125;
        investors[address(0xf156C946592048db11Fd6A63C36e21db5b8A15Fc)].initialBalance = 1010100000000001944442;
        investors[address(0x0eE3c92B266bae66A7257a2CAAF94EE82E7725D6)].initialBalance = 962000000000001851850000;
        investors[address(0x744e25EdCFF3A6620aF9BB3559Cc02f4e81C909c)].initialBalance = 716690000000001379628250;
        investors[address(0x92307aab45c07A318ca7187d9Bc7130856882aBe)].initialBalance = 10822500000000020833312;
        investors[address(0x3f31061793AfA2Fd52E2544439D70Ac2783eB9FD)].initialBalance = 360750000000000694443;
        investors[address(0x2151075438fF11c1CE63e6c8D2ffD238D7447DBb)].initialBalance = 1210508650000002330229;
        investors[address(0x3c5435aF9E2006EA26A639753DFf87455336ED6d)].initialBalance = 24050000000000046296250;
        investors[address(0x85155381a199846e3846319DB13bEB6C87Aa915d)].initialBalance = 28860000000000055555500;
        investors[address(0xb148a967D91b64a1CaCEbEceb38363A859073582)].initialBalance = 24050000000000046296250;
        investors[address(0x09c6DD3e4c66202769CD19C6c3c0835e233DdD41)].initialBalance = 1038276421198251998682109;
        investors[address(0x5239249C90D0c31C9F2A861af4da7E3393399Cb9)].initialBalance = 16835000000000032407375;
        investors[address(0x3440e437dB988319fc6A2e1b506a73C26606b51c)].initialBalance = 4809959403600009259171851;
        investors[address(0x479B556886e699f8A3C079837D0fcC6552D4c7AA)].initialBalance = 245310000000000472221750;
        investors[address(0x7DfCC68fe8f45C2EA5f952Fa140A1dBD66087995)].initialBalance = 2789800000000005370364;
        investors[address(0x002F331DD9949283c6f9f9B1833dfcDcBA874740)].initialBalance = 24050000000000046296250;
        investors[address(0xfcE10345d4875b9c605584829698AaFC3F92a0bF)].initialBalance = 1072115330000002063822;
        investors[address(0x39c0B67A563d7ffF390FAb0Ea830ae7457272ED9)].initialBalance = 19222924500000037004129;
        investors[address(0x0Da2b3afa74585104B86b773211fA65b3A81fdFd)].initialBalance = 175862017500000338534383;
        investors[address(0x5702521dE449Ff77db8F2E575b3D4B9Ebb9CD67F)].initialBalance = 57260164000000110225815;
        investors[address(0xF916f5768E4e7F77c9c18Bdcf7B882FEED915F00)].initialBalance = 27417000000000052777724;
        investors[address(0x33778Ff97Bd0f2485262e91adaeafAEC624F58A0)].initialBalance = 601250000000001157406;
        investors[address(0x9bf6903c44d68310B9C9CA826f5d76B303FA0b49)].initialBalance = 125060000000000240740500;
        investors[address(0x338620F16Be9c0fb78Eb868a6Cb878798085f1c5)].initialBalance = 2405000000000004629625000;
        investors[address(0x3BD641e3FF7a80b90500C2B2168B7a5816B6Fb06)].initialBalance = 21108829300000040634496;
        investors[address(0xC7294Dc58Afb275c58c28D8eA8d7D37F9c40C6a5)].initialBalance = 16835000000000032407375;
        investors[address(0x7c208EdA3eFc828db68ea268b5F7A3dde5F4F5f5)].initialBalance = 9610812082300018500813;
        investors[address(0x9Fa8FaEeF0A30062360bFeE237B465Fe02cCDb60)].initialBalance = 520500851360101001964137;
        investors[address(0xcDD891A8534dC047Cf948BaB5f758D537D0e9675)].initialBalance = 180375000000000347221875;
        investors[address(0x0b21605ab48C345D44eF3BCC4Ab53310D12b36E7)].initialBalance = 72150000000000138888750;
        investors[address(0x72406b276369e54c3896ee5cee1AB8Ce3A9E04e8)].initialBalance = 50505000000000097222125;
        investors[address(0x48c04d07Ed26C38198A2411982D046d3CF952c5D)].initialBalance = 12025000000000023148125;
        investors[address(0x55A0B2b1A705dD09F15e7120cC0c39ACb9Ea7978)].initialBalance = 649350000000001249998750;
        investors[address(0xb28A0279730b3a763890bB0e70bC648a4c8520d7)].initialBalance = 1491100000000002870367;
        investors[address(0xD46d9fE2d8f991913Bd4f77536abBa4598EA29A9)].initialBalance = 120250000000000231481250;
        investors[address(0x0797D4797cCadA90E0298dCAeEB80c4246f703df)].initialBalance = 336700000000000648147500;
        investors[address(0xdb16D385eAc132a404ce2Dd3AB741EACb2BDee86)].initialBalance = 1563250000000003009256250;
        investors[address(0xE857A8B02bAbC4fE91f36FD20bD47ad63A66A621)].initialBalance = 75748031515000145814960;
        investors[address(0xa88302C8a0014C01432d41c3a2fBa646354d7E68)].initialBalance = 256445150000000493656913;
        investors[address(0x74Ba4cb5D5E2aB1A136e9f9640aC7628b6CB2Fc6)].initialBalance = 24044058888216296284813;
        investors[address(0x53A09AEEfa53DA9D0737b5cA663c0CDD9bf8187D)].initialBalance = 16835000000000032407375;
        investors[address(0x005B735E2f3f10B061b33a56558aef6A550890E7)].initialBalance = 75517000000000145370225;
        investors[address(0x250e6Ddb79af67Be99EE66ed914B42C72CaBBb85)].initialBalance = 16810950000000032361078;
        investors[address(0x403453fBc9a1ab17B0d90B044d1f8091e9bE50f2)].initialBalance = 731665935000001408456;
        investors[address(0xAD4618bAa8Be28907f47bb470A6540c9d5f3646b)].initialBalance = 33670000000000064814750;
        investors[address(0x91B16F87933f0805F1D82521caec150Bd7BaCDed)].initialBalance = 10822500000000020833312;
        investors[address(0x511cB31E2315b8339f9D25eFE80A86980F3Fb285)].initialBalance = 2405000000000004629625000;
        investors[address(0x34999E19D6248d878FC468F7E4FA17FB11F948F6)].initialBalance = 36075000000000069444375;
        investors[address(0x966C09b4F18cAEe28eBA6AfC875f89A7925ad9D3)].initialBalance = 24050000000000046296250;
        investors[address(0x2363348C4F35C2959B9F73926ebEB256fe64b0d9)].initialBalance = 4810000000000009259250;
        investors[address(0xEA522641f5033723cda70dD5D2479446c6e8938b)].initialBalance = 3246750000000006249993;
        investors[address(0x13A7b665c91259873dFF9D685811Bc916b5E403c)].initialBalance = 18037500000000034722187;
        investors[address(0x96ceF27FC705c70e12a9955FeA81ea6B5E7E89b4)].initialBalance = 170755000000000328703;
        investors[address(0x832a1bE7d51077f495aceE9a7edB576816e054EA)].initialBalance = 1679892500000003233793;
        investors[address(0x364B47B1e82D74a702ba79572514E78897686746)].initialBalance = 120250000000000231481;
        investors[address(0x6b3C5AeEB11A2dB76E60E2a27Dd929c35Ca0B323)].initialBalance = 2405000000000004629625;
        investors[address(0xCb8aB95570c9DFd16b0995f9fe4AA0BDe0C749Aa)].initialBalance = 27657500000000053240687;

        uacToken = UAC(_uacTokenAddress);
    }

    modifier byIcoContract()
    {
        require(msg.sender == icoContractAddress);
        _;
    }

    modifier onlyIcoFinished()
    {
        require(icoFinished == true);
        _;
    }

    function icoFinished()
    byIcoContract
    {
        firstThreshold = uint(now).add(7 days);
        secondThreshold = uint(now).add(97 days);
        icoFinished = true;
    }

    function setIcoContractAddress(address _icoContractAddress)
    onlyOwner
    {
        icoContractAddress = _icoContractAddress;
    }

    function setUacTokenAddress(address _uacTokenAddress)
    onlyOwner
    {
        uacTokenAddress = _uacTokenAddress;
        uacToken = UAC(_uacTokenAddress);
    }

    function withdrawTokens()
    public
    onlyIcoFinished
    {
        uint tempBalance = (investors[msg.sender].initialBalance.mul(1 ether)).div(3);
        uint amountToSend = 0;


        if ((uint(now) >= firstThreshold) && (investors[msg.sender].firstWithdraw == 0)) {
            investors[msg.sender].balance = investors[msg.sender].initialBalance;
            investors[msg.sender].lastWithdrawTime = secondThreshold;
            investors[msg.sender].firstWithdraw = 1;
            amountToSend = tempBalance;
        }

        tempBalance = tempBalance.mul(2);

        if (uint(now) >= secondThreshold) {
            uint daysPassed = (uint(now).sub(investors[msg.sender].lastWithdrawTime)).div(1 days);
            amountToSend = amountToSend.add((tempBalance.div(180)).mul(daysPassed));
            investors[msg.sender].lastWithdrawTime = uint(now);
        }

        require(amountToSend != 0);
        amountToSend = amountToSend.div(1 ether);

        if (investors[msg.sender].balance < amountToSend) {
            amountToSend = investors[msg.sender].balance;
        }

        investors[msg.sender].balance = investors[msg.sender].balance.sub(amountToSend);

        uacToken.transfer(msg.sender, amountToSend);

        amountToSend = 0;
    }

    function getInitialBalance(address user)
    constant
    public
    returns (uint initialBalance)
    {
        initialBalance = investors[user].initialBalance;
        return initialBalance;
    }

    function getReclaimableTokens(address user)
    constant
    public
    returns (uint reclaimableTokens)
    {
        if(icoFinished == false)
        {
            return 0;
        }
        else
        {
            uint tempBalance = (investors[user].initialBalance.mul(1 ether)).div(3);
            reclaimableTokens = 0;

            if ((uint(now) >= firstThreshold) && (investors[user].firstWithdraw == 0)) {
                investors[user].balance = investors[user].initialBalance;
                investors[user].lastWithdrawTime = secondThreshold;
                reclaimableTokens = tempBalance;
            }

            tempBalance = tempBalance.mul(2);

            if (uint(now) >= secondThreshold) {
                uint daysPassed = (uint(now).sub(investors[user].lastWithdrawTime)).div(1 days);
                reclaimableTokens = reclaimableTokens.add((tempBalance.div(180)).mul(daysPassed));
            }

            reclaimableTokens = reclaimableTokens.div(1 ether);

            if (investors[user].balance < reclaimableTokens) {
                reclaimableTokens = investors[user].balance;
            }

            return reclaimableTokens;
        }
    }

    function getBalance(address user)
    constant
    public
    returns (uint balance)
    {
        return getReclaimableTokens(user).add(getLockedTokens(user));
    }

    function getLockedTokens(address user)
    constant
    public
    returns (uint lockedTokens)
    {
        if(icoFinished == false)
        {
            return investors[user].initialBalance;
        }
        else
        {
            uint reclaimableTokens = 0;
            uint tempBalance = (investors[user].initialBalance.mul(1 ether)).div(3);


            if ((uint(now) >= firstThreshold) && (investors[user].firstWithdraw == 0)) {
                investors[user].balance = investors[user].initialBalance;
                investors[user].lastWithdrawTime = secondThreshold;
                reclaimableTokens = tempBalance;
            }

            tempBalance = tempBalance.mul(2);

            if (uint(now) >= secondThreshold) {
                uint daysPassed = (uint(now).sub(investors[user].lastWithdrawTime)).div(1 days);
                reclaimableTokens = reclaimableTokens.add((tempBalance.div(180)).mul(daysPassed));
            }

            reclaimableTokens = reclaimableTokens.div(1 ether);

            if (investors[user].balance < reclaimableTokens) {
                reclaimableTokens = investors[user].balance;
            }

            lockedTokens = investors[user].balance - reclaimableTokens;
        }
    }

    function addNewInvestor(address _address, uint _initialBalance)
    onlyOwner
    {
        investors[_address].initialBalance = _initialBalance;
    }

    // Do not allow to send money directly to this contract
    function() payable {
        revert();
    }
}