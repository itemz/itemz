pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./BasicToken.sol";
import "./BigToken.sol";


contract Exchanger is Ownable {

    /// BigToken contract
    BigToken public bigToken;

    /// Array of SeedToken addresses
    address[] public stAddresses;

    /// Array of token values to exchange
    uint256[] public stValues;

    /// Status of initialization
    bool internal initialized = false;

    event Initialized();

    /// @notice Constructor
    /// @param _bigToken Address of a BigToken contract
    /// @param _stAddresses Array of SeedToken addresses
    /// @param _stValuesNoDecimals Array of token values to exchange without extra zeros
    constructor(BigToken _bigToken, address[] _stAddresses, uint256[] _stValuesNoDecimals) public {
        if (address(_bigToken) != address(0) && _stAddresses.length > 0 && _stValuesNoDecimals.length > 0)
            initialize(_bigToken, _stAddresses, _stValuesNoDecimals);
    }

    /// @notice Sets basic values of the contract. Only contract owner can call this function.
    /// @param _bigToken Address of a BigToken contract
    /// @param _stAddresses Array of SeedToken addresses
    /// @param _stValues Array of token values to exchange (1 big token = _stValues small tokens)
    function initialize(BigToken _bigToken, address[] _stAddresses, uint256[] _stValues) public onlyOwner {
        require(!initialized);
        require(address(_bigToken) != address(0) && _stAddresses.length == _stValues.length && _stAddresses.length > 0);
        uint256 decimals;
        BasicToken token;
        for (uint256 i = 0; i < stAddresses.length; i ++) {
            token = BasicToken(_stAddresses[i]);
            decimals = uint256(token.decimals());
            require(decimals > 0);
        }
        bigToken = _bigToken;
        stAddresses = _stAddresses;
        stValues = _stValues;
        initialized = true;
        emit Initialized();
    }

    /// @notice Exchanges small tokens to big tokens
    /// @param _tokenValueNoDecimals How many big tokens a user will receive (without decimal units)
    function exchange(uint256 _tokenValueNoDecimals) public {
        require(initialized);
        uint256 tokensToTransfer;
        BasicToken token;
        uint256 decimals;
        for (uint256 i = 0; i < stAddresses.length; i ++) {
            token = BasicToken(stAddresses[i]);
            decimals = uint256(token.decimals());
            tokensToTransfer = _tokenValueNoDecimals * stValues[i] * 10 ** decimals;
            require(token.balanceOf(msg.sender) >= tokensToTransfer);
            require(token.allowance(msg.sender, address(this)) >= tokensToTransfer);
            token.transferFrom(msg.sender, address(this), tokensToTransfer);
        }
        bigToken.mint(msg.sender, _tokenValueNoDecimals * 10 ** uint256(bigToken.decimals()));
    }


    /// @notice Exchanges big tokens to small tokens
    /// @param _tokenValueNoDecimals How many big tokens a user will send (without decimal units)
    function giveBack(uint256 _tokenValueNoDecimals) public {
        require(initialized);
        uint256 decimals;
        require(bigToken.balanceOf(msg.sender) >= _tokenValueNoDecimals * 10 ** uint256(bigToken.decimals()));
        uint256 tokensToTransfer;
        for (uint256 i = 0; i < stAddresses.length; i ++) {
            BasicToken token = BasicToken(stAddresses[i]);
            decimals = uint256(token.decimals());
            tokensToTransfer = _tokenValueNoDecimals * stValues[i] * 10 ** decimals;
            require(token.balanceOf(this) >= tokensToTransfer);
            token.transfer(msg.sender, tokensToTransfer);
        }
        require(bigToken.allowance(msg.sender, address(this)) >= _tokenValueNoDecimals * 10 ** uint256(bigToken.decimals()));
        bigToken.transferFrom(msg.sender, address(this), _tokenValueNoDecimals * 10 ** uint256(bigToken.decimals()));
    }

}