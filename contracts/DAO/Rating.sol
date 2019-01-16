pragma solidity ^0.4.24;

import "./SeedDAICO.sol";

contract Rating is Ownable {

    // Mapping from wp ID to amount of wei paid for listing
    mapping (uint256 => uint256) internal weiPaid;

    // Mapping from token ID to timestamp
    mapping (uint256 => uint256) internal listBefore;

    // Total mount of wei paid
    uint256 internal weiPaidTotal;

    // Wallet #1 address
    address internal wallet1;

    // Wallet #2 address
    address internal wallet2;

    // WP contract
    WhitePapers internal whitePapers;

    // WPs to list at site
    uint256[] internal tokensToList;

    /// Count of tokens to list
    uint256 public tokensCount;

    /// Charge - percent of Seed DAICO goal
    uint8 public percentGoal;

    /// Listing time in seconds (e.g. 4 weeks)
    uint256 internal cycle = 4 weeks;

    /// Status of initialization
    bool internal initialized = false;

    event Initialized();
    event Paid(address payer, uint256 value, uint256 tokenID, uint256 listBefore);

    /// @notice Constructor
    /// @param _whitePapers White Papers contract address
    /// @param _wallet1 Wallet #1 to withdraw Ether
    /// @param _wallet2 Wallet #2 to withdraw Ether
    /// @param _percentGoal Percent of Seed DAICO goal
    constructor(WhitePapers _whitePapers, address _wallet1, address _wallet2, uint8 _percentGoal) public {
        if (address(_whitePapers) != address(0) && _wallet1 != address(0) && _wallet2 != address(0) && _percentGoal > 0 && _percentGoal < 100) 
            initialize(_whitePapers, _wallet1, _wallet2, _percentGoal);
    }


    /// @notice Sets initial parameters of Rating contract. Only contract owner can set them. Initialization can be performed only once.
    /// @param _whitePapers White Papers contract address
    /// @param _wallet1 Wallet #1 to withdraw Ether
    /// @param _wallet2 Wallet #2 to withdraw Ether
    /// @param _percentGoal Percent of Seed DAICO goal
    function initialize(WhitePapers _whitePapers, address _wallet1, address _wallet2, uint8 _percentGoal) public onlyOwner {
        require(!initialized);
        require(address(_whitePapers) != address(0));
        require(_wallet1 != address(0));
        require(_wallet2 != address(0));
        require(_percentGoal > 0 && _percentGoal < 100);
        whitePapers = _whitePapers;
        wallet1 = _wallet1;
        wallet2 = _wallet2;
        percentGoal = _percentGoal;
        initialized = true;
        emit Initialized();
    }
    
    /// @notice Fallback function receives ether for listing in a rating
    function () public payable {
        require(initialized);
        require(whitePapers.balanceOf(msg.sender) > 0);
        uint256 tokenID = whitePapers.ownedProject(msg.sender);
        address seedDAICOAddress = whitePapers.seedDAICOAddress(tokenID);
        SeedDAICO seedDAICO = SeedDAICO(seedDAICOAddress);
        uint256 goal = seedDAICO.weiGoal();
        uint256 start = seedDAICO.campaignStartTime();
        uint256 weiToPay = percentGoal * goal / 100;
        require(msg.value == weiToPay);
        listBefore[tokenID] = start + cycle;
        weiPaid[tokenID] = msg.value;
        weiPaidTotal += msg.value;
        tokensCount = tokensToList.push(whitePapers.ownedProject(msg.sender));
        uint256 half = msg.value / 2;
        wallet1.transfer(half);
        wallet2.transfer(msg.value - half);
        emit Paid(msg.sender, msg.value, tokenID, listBefore[tokenID]);
    }

    /// @notice Returns paid time for a given token
    /// @param _tokenID Token ID
    /// @return Timestamp of last time to list
    function getListingTime(uint256 _tokenID) public view returns (uint256) {
        return listBefore[_tokenID];
    }

    /// @notice Returns token ID by index in listing
    /// @param _index Index of token in listing
    /// @return Token ID in WhitePapers contract
    function getIdByIndex(uint256 _index) public view returns (uint256) {
        return tokensToList[_index];
    }

}