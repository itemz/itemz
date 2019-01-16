pragma solidity ^0.4.24;

import './EIP20.sol';
import './Ownable.sol';

contract BasicToken is EIP20, Ownable {

/*
Partly used code from ConsenSys: https://github.com/ConsenSys/Tokens/blob/master/contracts/eip20/EIP20.sol
*/

	/// Maximum allowed number
    uint256 constant internal MAX_UINT256 = 2**256 - 1;

	/// Token amount of tokens
	uint256 public totalSupply;
	
	/// Token name
	string public name;

	/// Token symbol
	string public symbol;

	/// Token decimal units. Default is 18.
	uint8 public decimals = 18;

	/// Mapping from a holder's address to his balance
	mapping (address => uint256) public balances;

	/// Allowed amount for transferFrom operation
    mapping (address => mapping (address => uint256)) public allowed;

	/// Who can distribute tokens. Mapping from account or contract address to true or false.
	mapping (address => bool) public distributors;

  	modifier onlyDistributor() {
    	require(distributors[msg.sender] == true);
    	_;
  	}

	event Transfer(address indexed _from, address indexed _to, uint256 _value);
	event Approval(address indexed _owner, address indexed _spender, uint256 _value);
	event Distributor(address indexed _addr, bool _status);

    /// @notice Gets the balance of the specified address
    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
	function balanceOf(address _owner) public view returns (uint256 balance) {
		return balances[_owner];
	}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
	function transfer(address _to, uint256 _value) public returns (bool success) {
		require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
	}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
		uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
	}

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
	function approve(address _spender, uint256 _value) public returns (bool success) {
		allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
	}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
	function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
		return allowed[_owner][_spender];
	}

	/// @notice Sets a distributor of tokens
	/// @param _addr Address of a distributor
	/// @param _status True or false
	function setDistributor(address _addr, bool _status) public onlyOwner {
    	distributors[_addr] = _status;
    	emit Distributor(_addr, _status);
  	}

}