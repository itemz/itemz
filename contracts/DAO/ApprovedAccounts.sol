pragma solidity ^0.4.24;

import './Ownable.sol';

contract ApprovedAccounts is Ownable {

/*
A contract that stores list of KYC/AML-approved accounts
*/

	/// List of KYC/AML providers. Mapping from a provider's address to its status.
	mapping (address => bool) public providers;

    /// Mapping from an account to ins approval status.
    mapping (address => bool) public approvals;

    modifier onlyProvider {
        require(providers[msg.sender]);
        _;
    }

    event ProviderSet(address provider, bool status);
    event Approved(address provider, address account);
    event RemovedApproval(address provider, address account);

    /// @notice Set KYC/AML provider
    /// @param _provider Provider's address
    /// @param _status True or false
	function setProvider(address _provider, bool _status) public onlyOwner {
		require(_provider != address(0));
		providers[_provider] = _status;
        emit ProviderSet(_provider, _status);
	}

    /// @notice Approve an account
    /// @param _addr An account
    function approve(address _addr) public onlyProvider {
        require(_addr != address(0));
        approvals[_addr] = true;
        emit Approved(msg.sender, _addr);
    }

    /// @notice Remove approval of an account
    /// @param _addr An account
    function removeApproval(address _addr) public onlyProvider {
        require(_addr != address(0));
        approvals[_addr] = false;
        emit RemovedApproval(msg.sender, _addr);
    }
    
}