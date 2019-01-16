pragma solidity ^0.4.24;

import './BasicToken.sol';

contract BigToken is BasicToken {

    /// Status of initialization
    bool internal initialized = false;

    event Initialized();
    event Mint(address indexed to, uint256 value);

	/// @notice Constructor
	/// @param _name Token name
	/// @param _symbol Token symbol
	constructor (string _name, string _symbol) public {
		if (bytes(_name).length > 0 && bytes(_symbol).length > 0)
			initialize(_name, _symbol);
	}

    /// @notice Sets basic values of the contract. Only contract owner can call this function.
	/// @param _name Token name
	/// @param _symbol Token symbol
    function initialize(string _name, string _symbol) public onlyOwner {
		require(!initialized);
		name = _name;
		symbol = _symbol;
		initialized = true;
		emit Initialized();
    }

	/// @notice Mints, or distributes tokens
	/// @param _to Receiver of tokens
	/// @param _value Number of tokens to mint (with decimal units)
    /// @return Whether the transfer was successful or not
	function mint(address _to, uint256 _value) public onlyDistributor returns (bool success) {
		require(totalSupply + _value < MAX_UINT256);
		balances[_to] += _value;
        totalSupply += _value;
		emit Mint(_to, _value);
		return true;
	}

}