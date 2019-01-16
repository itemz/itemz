pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./SeedDAICO.sol";
import "./SeedToken.sol";
import "./ApprovedAccounts.sol";


contract WhitePapers is Ownable {

    /// Name of WP list
    string public name;

    /// Symbol of WP list
    string public symbol;

    /// Total amount of WPs
    uint256 public totalProjects;

    /// Last id of WP
    uint256 internal lastId;

    /// Mapping from WP ID to owner
    mapping (uint256 => address) public projectOwner;

    /// Mapping from owner to owned WP ID
    mapping (address => uint256) public ownedProject;

    /// Mapping from WP ID to its Seed DAICO contract address
    mapping (uint256 => address) public seedDAICOAddress;

    /// Mapping from WP ID to project name
    mapping (uint256 => string) public projectName;

    /// Mapping from WP ID to project description
    mapping (uint256 => string) public projectDescription;

    /// Mapping from WP ID to project team
    mapping (uint256 => string) public projectTeam;

    /// Mapping from WP ID to link to web site or other resource
    mapping (uint256 => string) public projectLink;

    /// Mapping from WP ID to URL to PNG logo
    mapping (uint256 => string) public projectLogoURI;

    /// Mapping from WP ID to a hashsum
    mapping (uint256 => string) public hashsum;

    /// ApprovedAccounts contract address
    address public approvedAccountsAddress;

    event Created(address indexed to, uint256 indexed tokenId);


    /// @dev Guarantees msg.sender is owner of the given token
    /// @param _tokenId uint256 ID of the token to validate its ownership belongs to msg.sender
    modifier onlyOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender);
        _;
    }

    /// @notice Constructor
    /// @param _name Name of WP list
    /// @param _symbol Symbol of WP list
    constructor(string _name, string _symbol) public {
        if (bytes(_name).length > 0 && bytes(_symbol).length > 0) initialize(_name, _symbol);
        ApprovedAccounts aa = new ApprovedAccounts();
        aa.transferOwnership(msg.sender);
        approvedAccountsAddress = address(aa);
    }

    /// @notice Sets name and symbol of the collection of NFTs. Only contract owner can call this function.
    /// @param _name The name of the collection
    /// @param _symbol The name of the collection
    function initialize(string _name, string _symbol) public onlyOwner {
        require(bytes(_name).length > 0);
        require(bytes(_symbol).length > 0);
        name = _name;
        symbol = _symbol;
    }

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0));
        // In this implementation an owner can have only one WP.
        return ownedProject[_owner] != 0 ? 1 : 0;
    }

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address _owner = projectOwner[_tokenId];
        require(_owner != address(0));
        return _owner;
    }

    /// @notice Creating a new project, deployment SeedDAICO and ERC20 token contracts for it
    /// @param _projectName Name of a project and ERC20 token name
    /// @param _tokenSymbol ERC20 token symbol
    /// @param _projectDescription Description of a project
    /// @param _projectTeam Team of a project
    /// @param _projectLink Link to a project's site or other resource
    /// @param _projectLogoURI URI of token logo image
    /// @param _campaignStartTime Timestamp of a campaign start time
    /// @param _installments Number of installments
    /// @param _etherGoal Seed goal in Ether. Goal is hard cap
    /// @return ID of a new project
    function createProject(string _projectName, string _tokenSymbol, string _projectDescription, string _projectTeam, string _projectLink, string _projectLogoURI, 
            uint256 _campaignStartTime, uint8 _installments, uint256 _etherGoal, uint256 _totalSupplyNoDecimals) public returns (uint256) {
        require(balanceOf(msg.sender) == 0);
        require(bytes(_projectName).length > 0);
        require(bytes(_tokenSymbol).length > 0);
        require(bytes(_projectDescription).length > 0);
        require(bytes(_projectTeam).length > 0);
        require(bytes(_projectLink).length > 0);
        require(bytes(_projectLogoURI).length > 0);
        lastId++;
        totalProjects++;
        projectOwner[lastId] = msg.sender;
        ownedProject[msg.sender] = lastId;
        projectName[lastId] = _projectName;
        projectDescription[lastId] = _projectDescription;
        projectTeam[lastId] = _projectTeam;
        projectLink[lastId] = _projectLink;
        projectLogoURI[lastId] = _projectLogoURI;
        /// deployment of a new Seed DAICO smart contract
        SeedDAICO sd = new SeedDAICO(address(this), lastId, _campaignStartTime, _installments, _etherGoal, msg.sender, approvedAccountsAddress);
        seedDAICOAddress[lastId] = address(sd);
        /// deployment of a new Seed Token smart contract
        SeedToken st = new SeedToken(_projectName, _tokenSymbol, _totalSupplyNoDecimals, address(sd));
        sd.setTokenAddress(address(st));
        st.transferOwnership(msg.sender);
        sd.transferOwnership(msg.sender);
        emit Created(msg.sender, lastId);
        return lastId;
    }

    /// @notice Set JSON hashsum
    /// @param _tokenId Identifier of a project
    function setHashsum(uint256 _tokenId, string _hashsum) public onlyOwnerOf(_tokenId) {
        require(bytes(hashsum[_tokenId]).length == 0);
        require(projectOwner[_tokenId] != address(0));
        require(bytes(_hashsum).length > 0);
        hashsum[_tokenId] = _hashsum;
    }

}