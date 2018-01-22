pragma solidity ^0.4.18;

import "./Owned.sol";
import "./SafeMath.sol";
import "./ERC20Interface.sol";

contract UbiatarCoin is Owned, ERC20Interface{

     using SafeMath for uint;

     string public symbol;
     string public  name;
     uint8 public decimals;
     uint public _totalSupply;

     mapping(address => uint) balances;
     mapping(address => mapping(address => uint)) allowed;


     // ------------------------------------------------------------------------
     // Constructor
     // ------------------------------------------------------------------------
     function UbiatarCoin()
     public
     {
         symbol = "UAC";
         name = "Ubiatar Coin";
         decimals = 18;
         _totalSupply = 15000000 * 10**uint(decimals);
         balances[owner] = _totalSupply;
         Transfer(address(0), owner, _totalSupply);
     }


     // ------------------------------------------------------------------------
     // Total supply
     // ------------------------------------------------------------------------
     function totalSupply()
     public
     constant
     returns (uint)
     {
         return _totalSupply  - balances[address(0)];
     }


     // ------------------------------------------------------------------------
     // Get the token balance for account `tokenOwner`
     // ------------------------------------------------------------------------
     function balanceOf(address tokenOwner)
     public
     constant
     returns (uint balance)
     {
         return balances[tokenOwner];
     }


     // ------------------------------------------------------------------------
     // Transfer the balance from token owner's account to `to` account
     // - Owner's account must have sufficient balance to transfer
     // - 0 value transfers are allowed
     // ------------------------------------------------------------------------
     function transfer(address to, uint tokens)
     public
     returns (bool success)
     {
         require(to != 0x0);
         require(balances[msg.sender] >= tokens);
         balances[msg.sender] = balances[msg.sender].sub(tokens);
         balances[to] = balances[to].add(tokens);
         Transfer(msg.sender, to, tokens);
         return true;
     }


     // ------------------------------------------------------------------------
     // Token owner can approve for `spender` to transferFrom(...) `tokens`
     // from the token owner's account
     //
     // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
     // recommends that there are no checks for the approval double-spend attack
     // as this should be implemented in user interfaces
     // ------------------------------------------------------------------------
     function approve(address spender, uint tokens)
     public
     returns (bool success)
     {
         require(spender != 0x0);
         allowed[msg.sender][spender] = tokens;
         Approval(msg.sender, spender, tokens);
         return true;
     }


     // ------------------------------------------------------------------------
     // Transfer `tokens` from the `from` account to the `to` account
     //
     // The calling account must already have sufficient tokens approve(...)-d
     // for spending from the `from` account and
     // - From account must have sufficient balance to transfer
     // - Spender must have sufficient allowance to transfer
     // - 0 value transfers are allowed
     // ------------------------------------------------------------------------
     function transferFrom(address from, address to, uint tokens)
     public
     returns (bool success)
     {
         require(balances[from] >= tokens);
         require(allowed[from][msg.sender] >= tokens);
         balances[from] = balances[from].sub(tokens);
         allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
         balances[to] = balances[to].add(tokens);
         Transfer(from, to, tokens);
         return true;
     }


     // ------------------------------------------------------------------------
     // Returns the amount of tokens approved by the owner that can be
     // transferred to the spender's account
     // ------------------------------------------------------------------------
     function allowance(address tokenOwner, address spender)
     public
     constant
     returns (uint remaining)
     {
         require(tokenOwner != 0x0);
         require(spender != 0x0);
         return allowed[tokenOwner][spender];
     }
}
