pragma solidity ^0.4.24;

import './BasicToken.sol';

contract SeedToken is BasicToken {

	/// Seed DAICO contract address
	address public seedDAICOAddress;

	/// Locking status of distribution of 90% of tokens and changing token distributor
	bool public locked  = true;

  	modifier onlySeedDAICO() {
  		require(msg.sender == seedDAICOAddress);
  		_;
  	}

	event Unlock();


	/// @notice Constructor
	/// @param _name Token name
	/// @param _symbol Token symbol
	/// @param _totalSupplyNoDecimals Total supply (without extra zeros)
    /// @param _seedDAICOAddress Seed DAICO contract address
	constructor (string _name, string _symbol, uint256 _totalSupplyNoDecimals, address _seedDAICOAddress) public {
        require(_seedDAICOAddress != address(0));
        require(_totalSupplyNoDecimals >= 1000000 && _totalSupplyNoDecimals <= 100000000000);
		name = _name;
		symbol = _symbol;
		totalSupply = _totalSupplyNoDecimals * (10**uint256(decimals));
		balances[address(this)] = totalSupply;
		seedDAICOAddress = _seedDAICOAddress;
		distributors[seedDAICOAddress] = true;
	}
    
	/// @notice Sets a distributor of tokens
	/// @param _addr Address of a distributor
	/// @param _status True or false
	function setDistributor(address _addr, bool _status) public onlyOwner {
		require(!locked);
    	distributors[_addr] = _status;
    	emit Distributor(_addr, _status);
  	}

	/// @notice Distributes tokens
	/// @param _to Receiver of tokens
	/// @param _value Number of tokens to mint
    /// @return Whether the transfer was successful or not
	function distribute(address _to, uint256 _value) public onlyDistributor returns (bool success) {
		require(balances[address(this)] >= _value);
		if (locked && balances[address(this)] - _value < totalSupply / 10) 
			revert();
		balances[_to] += _value;
		balances[address(this)] -= _value;
		emit Transfer(address(this), _to, _value);
		return true;
	}

	/// @notice One-way function for unlocking distribution of 90% tokens
	function unlock() public onlySeedDAICO {
		locked = false;
		emit Unlock();
	}
}
