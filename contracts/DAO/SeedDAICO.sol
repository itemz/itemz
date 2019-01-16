pragma solidity ^0.4.24;

import "./WhitePapers.sol";
import "./ApprovedAccounts.sol";

contract SeedDAICO is Ownable {

    /// Mapping from share holders' address to amount of tokens they own. 1 wei = 1 token.
    mapping (address => uint256) public holders;

    /// WP token contract address
    address public wpTokenAddress;

    /// WP token ID
    uint256 public wpTokenID;

    /// ERC20 token
    SeedToken public seedToken;

    /// Seed campaign start time
    uint256 public campaignStartTime;

    /// Seed campaign end time. Typically a campaign lasts for 4 weeks.
    uint256 public campaignEndTime;

    /// DAICO working end time. Typically in 12 months after campaign ends.
    uint256 public workingEndTime;

    /// Number of installments
    uint8 public installments;

    /// Seed goal in wei. Goal is hard cap.
    uint256 public weiGoal;

    /// Amount of wei raised during seed campaign.
    uint256 public weiRaised;

    /// Seed DAICO cycle in seconds (e.g. 4 weeks)
    uint256 internal cycle = 4 weeks;

    /// Minimum goal in ether
    uint256 internal etherGoalMin = 100;

    /// Maximun goal in ether
    uint256 internal etherGoalMax = 1500;

    /// Maximun raise limit
    uint256 public maxRaise = 1520 ether;

    /// How many tokens you get for 1 wei
    uint256 internal rate;

    /// Voting threshold in percents
    uint8 public votingThresholdPercent = 30;

    /// Team wallet address
    address public teamWallet;

    /// Amount of wei to withdraw every 4 weeks
    uint256 public monthlyWeiToWithdraw;

    /// Amount of wei have been withdrawn
    uint256 public weiWithdrawn;

    /// Amount of votes for stop Seed DAICO in wei equivalent
    uint256 public votesForStop;

    /// Amount of votes for unlock token distribution in wei equivalent
    uint256 public votesForUnlock;    

    /// Accounts voted for stop Seed DAICO
    mapping (address => uint256) public votedForStop;

    /// Accounts voted for unlock token distribution
    mapping (address => uint256) public votedForUnlock;

    /// Status indicates that investors have voted for stop working and refund
    bool public isStopped = false;

    /// Amount of wei refunded
    uint256 public weiRefunded;

    /// Refunded accounts
    mapping (address => uint256) public refunded;

    /// ApprovedAccounts contract
    ApprovedAccounts public approvedAccounts;

    /// States
    enum States {Initialization, Seeding, Working, Refunding}


    event Participated(address investor, uint256 weiValue);
    event Withdraw(uint256 weiToWithdraw);
    event VotedForStop(address investor);
    event VotedForUnlock(address investor);
    event Stopped(uint256 votesPercent);
    event Refunded(address investor, uint256 weiValue);
    event Brake();

    modifier inState(States state) {
        require(getState() == state);
        _;
    }


    /// @notice Constructor
    /// @param _wpTokenAddress White Papers token contract address
    /// @param _wpTokenID Token ID
    /// @param _campaignStartTime Timestamp of a campaign start time
    /// @param _installments Number of installments
    /// @param _etherGoal Seed goal in Ether. Goal is hard cap
    /// @param _teamWallet Team wallet address
    /// @param _approvedAccounts ApprovedAccounts contract address
    constructor(address _wpTokenAddress, uint256 _wpTokenID, uint256 _campaignStartTime, uint8 _installments, uint256 _etherGoal, 
            address _teamWallet, address _approvedAccounts) public {
        require(_wpTokenAddress != address(0));
        require(_wpTokenID > 0);
        require(_campaignStartTime >= now);
        require(_installments > 0 && _installments <= 12);
        require(_etherGoal >= etherGoalMin && _etherGoal <= etherGoalMax);
        require(_teamWallet != address(0));
        require(_approvedAccounts != address(0));

        wpTokenAddress = _wpTokenAddress;
        wpTokenID = _wpTokenID;
        campaignStartTime = _campaignStartTime;
        campaignEndTime = _campaignStartTime + cycle;
        workingEndTime = campaignEndTime + _installments * cycle;
        installments = _installments;
        weiGoal = _etherGoal * 1 ether;
        teamWallet = _teamWallet;
        approvedAccounts = ApprovedAccounts(_approvedAccounts);
    }

    /// @notice Set an ERC20 token address
    /// @param _seedTokenAddress ERC20 token address
    function setTokenAddress(address _seedTokenAddress) public onlyOwner {
        require(address(seedToken) == address(0));
        require(_seedTokenAddress != address(0));
        seedToken = SeedToken(_seedTokenAddress);
        rate = seedToken.totalSupply() / weiGoal / 10;
    }

    /// @notice Fallback function receives ether from seed investors
    function() public inState(States.Seeding) payable {
        require(msg.value > 0);
        require(weiRaised + msg.value <= maxRaise);
        require(approvedAccounts.approvals(msg.sender));
        holders[msg.sender] += msg.value;
        weiRaised += msg.value;
        seedToken.distribute(msg.sender, rate * msg.value);
        emit Participated(msg.sender, msg.value);
    }

    /// @notice State machine
    /// @return State of a contract
    function getState() public view returns (States) {
        if (wpTokenAddress == address(0) || campaignStartTime == 0 || campaignEndTime == 0 || workingEndTime == 0 
            || now < campaignStartTime || address(seedToken) == address(0)) return States.Initialization;
        if (isStopped) return States.Refunding;
        if (now >= campaignStartTime && now < campaignEndTime) return States.Seeding;
        if (now >= campaignEndTime && now < workingEndTime && weiRaised >= weiGoal) return States.Working;
        return States.Refunding;
    }

    /// @notice Withdraw ether for a team
    function withdraw() public inState(States.Working) onlyOwner {
        if (monthlyWeiToWithdraw == 0) monthlyWeiToWithdraw = weiRaised / installments; /// set only once
        uint256 installmentsPassed = (now - campaignEndTime) / cycle + 1; /// how many installments can be passed before current time
        uint256 weiToWithdraw = monthlyWeiToWithdraw * installmentsPassed - weiWithdrawn;
        weiWithdrawn += weiToWithdraw;
        teamWallet.transfer(weiToWithdraw);
        emit Withdraw(weiToWithdraw);
    }

    /// @notice Voting of investors for stop DAICO and refund ether
    function voteForStop() public inState(States.Working) {
        require(holders[msg.sender] > 0);
        require(votedForStop[msg.sender] == 0);
        votesForStop += holders[msg.sender];
        votedForStop[msg.sender] = holders[msg.sender];
        emit VotedForStop(msg.sender);
        if (votesForStop * 100 / weiRaised >= votingThresholdPercent) {
            isStopped = true;
            emit Stopped(votesForStop * 100 / weiRaised);
        }
    }

    /// @notice Voting of investors for unlock token distribution
    function voteForUnlock() public {
        require(getState() == States.Working || getState() == States.Refunding);
        require(holders[msg.sender] > 0);
        require(votedForUnlock[msg.sender] == 0);
        votesForUnlock += holders[msg.sender];
        votedForUnlock[msg.sender] = holders[msg.sender];
        emit VotedForUnlock(msg.sender);
        if (votesForUnlock * 100 / weiRaised >= votingThresholdPercent) {
            seedToken.unlock();
        }        
    }

    /// @notice Emergency brake for Seed DAICO
    function brake() public onlyOwner {
        isStopped = true;
        emit Brake();
    }

    /// @notice Refunding ether to investors. An investor claims refund after successful voting for stop DAICO.
    function pullback() public inState(States.Refunding) {
        require(holders[msg.sender] > 0);
        require(refunded[msg.sender] == 0);
        uint256 weiToRefund = (weiRaised - weiWithdrawn) * holders[msg.sender] / weiRaised;
        weiRefunded += weiToRefund;
        refunded[msg.sender] = weiToRefund;
        msg.sender.transfer(weiToRefund);
        emit Refunded(msg.sender, weiToRefund);
    }

}