pragma solidity ^0.4.22;

import "./SafeMath.sol";

/*
* Simple token contract, ERC20-style, but without possibility of transfer tokens
*
*/
contract SimpleToken {
    using SafeMath for uint;

    uint public totalSupply;

    /* Actual balances of token holders */
    mapping (address => uint) public balances;

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of. 
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) view public returns (uint balance) {
        return balances[_owner];
    }

}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner = msg.sender;

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}


/*
This token contract is used for tracking of parts without tracking individual serial numbers
*/

contract SimpleProductionToken is SimpleToken, Ownable {

    // Who can produce new parts
    mapping (address => bool) public producers;

    // Orders of parts. provider - customer - count
    mapping (address => mapping (address => uint256)) public orders;

    // Shipments of parts. provider - customer - count
    mapping (address => mapping (address => uint256)) public shipments;

    // Kanban thresholds
    struct kanbanStruct {
        address provider;
        uint256 threshold;
        uint256 autoOrderValue;
    }

    mapping (address => kanbanStruct) public thresholds;

    event Producer(address producer, bool value);
    event AutoOrderSet(address provider, address customer, uint256 threshold, uint256 autoOrderValue);
    event Create(address producer, uint256 value);
    event Order(address indexed provider, address indexed customer, uint256 value);
    event CancelOrder(address indexed provider, address indexed customer, uint256 value);
    event Shipment(address indexed provider, address indexed customer, uint256 value);
    event Receive(address indexed provider, address indexed customer, uint256 value);
    event Burn(address indexed provider, uint256 value);

    // Only procucer can create new parts
    modifier onlyProducer {
        require(producers[msg.sender]);
        _;
    }

    constructor() public {
        setProducer(msg.sender, true);
    }

    /// @notice Returns true if the contract is ProductionToken contract
    /// @return True
    function isProductionToken() pure public returns (bool) {
        return true;
    }

    /// @notice Sets a producer of parts
    /// @param _addr Address of a producer
    /// @param _value True or false
    function setProducer(address _addr, bool _value) public onlyOwner {
        require(_addr != address(0));
        producers[_addr] = _value;
        emit Producer(_addr, _value);
    }

    /// @notice Produces new amount of parts
    /// @param _value Amount of parts
    function create(uint256 _value) internal onlyProducer {
        balances[msg.sender] = balances[msg.sender].add(_value);
        totalSupply = totalSupply.add(_value);
        emit Create(msg.sender, _value);
    }

    /// @notice Sets amount of parts to order automatically
    /// @param _provider Address of part provider
    /// @param _threshold Minimum remaining amount of parts
    /// @param _autoOrderValue Amount of parts to order
    function setAutoOrder(address _provider, uint256 _threshold, uint256 _autoOrderValue) public {
        require(_provider != address(0) && _threshold > 0 && _autoOrderValue > 0);
        thresholds[msg.sender].provider = _provider;
        thresholds[msg.sender].threshold = _threshold;
        thresholds[msg.sender].autoOrderValue = _autoOrderValue;
        emit AutoOrderSet(_provider, msg.sender, _threshold, _autoOrderValue);
        checkThreshold(msg.sender);
    }

    /// @notice Checks if remaining amount of parts less than threshold and makes order
    /// @param _customer Customer address
    function checkThreshold(address _customer) public {
        if (thresholds[_customer].threshold > 0) {
            uint256 remaining = balances[_customer].add(orders[thresholds[_customer].provider][_customer]).add(shipments[thresholds[_customer].provider][_customer]);
            if (remaining <= thresholds[_customer].threshold) {
                orders[thresholds[_customer].provider][_customer] = orders[thresholds[_customer].provider][_customer].add(thresholds[_customer].autoOrderValue);
                emit Order(thresholds[_customer].provider, _customer, thresholds[_customer].autoOrderValue);
            }
        }
    }

    /// @notice Makes order of amount of parts from a provider
    /// @param _provider Address of a provider
    /// @param _value Amount of parts to order
    /// @return True
    function order(address _provider, uint256 _value) public returns (bool) {
        require(_value > 0);
        orders[_provider][msg.sender] = orders[_provider][msg.sender].add(_value);
        emit Order(_provider, msg.sender, _value);
        return true;
    }

    /// @notice Cancels order
    /// @param Address of a provider
    /// @param _value Amount of parts
    /// @return True
    function cancelOrder(address _provider, uint256 _value) public returns (bool) {
        require(_value > 0);
        require(_value <= orders[_provider][msg.sender]);
        orders[_provider][msg.sender] = orders[_provider][msg.sender].sub(_value);
        emit CancelOrder(_provider, msg.sender, _value);
        return true;
    }

    /// @notice Ships parts to a customer
    /// @param _customer Address of a customer
    /// @param _value Amount of parts
    /// @return True
    function ship(address _customer, uint256 _value) internal returns (bool) {
        require(_value <= balances[msg.sender]);
        shipments[msg.sender][_customer] = shipments[msg.sender][_customer].add(_value);
        orders[msg.sender][_customer] = _value < orders[msg.sender][_customer] ? orders[msg.sender][_customer].sub(_value) : 0;
        balances[msg.sender] = balances[msg.sender].sub(_value);
        emit Shipment(msg.sender, _customer, _value);
        return true;
    }

    /// @notice A customer applies receptioin of parts
    /// @param _provider Address of a provider
    /// @param _value Amount of parts to receive
    /// @return True
    function receive(address _provider, uint256 _value) internal returns (bool) {
        require(_value > 0);
        require(_value <= shipments[_provider][msg.sender]);
        shipments[_provider][msg.sender] = shipments[_provider][msg.sender].sub(_value);
        balances[msg.sender] = balances[msg.sender].add(_value);
        emit Receive(_provider, msg.sender, _value);
        return true;
    }

    /// @notice Burns parts
    /// @param _value Amount of parts
    function burn(uint256 _value) internal {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Burn(msg.sender, _value);
    }

// TODO
//    function cancelOrder()

}


/*
* This token contract is used for tracking of parts with individual serial numbers
*/

contract ProductionToken is SimpleProductionToken {

    struct partsStruct {
        address holder;
        string metadata;
    }

    struct stickStruct {
        address masterToken;              // foreign master token address
        uint256 masterPartId;      // foreign master part id
    }

    mapping (uint256 => partsStruct) public parts;
    mapping (uint256 => address) public partShipments;

    uint256 public lastId;

    // Foreign parts sticked to the part of this token
    // (this part id => struct)
    mapping (uint256 => stickStruct) public sticked;
    /*
    // (foreign token address => foreign partId => this token partId)
    mapping (address => mapping (uint256 => uint256)) public reverseSticked;

    // Foreign master token of sticked part of this token
    // (partId => token address)
    mapping (uint256 => address) public masterToken;
    */

    event StickPart(address holder, uint256 partId, address addr, uint256 masterPartId);
    event UnstickPart(address holder, uint256 partId);
    event SyncHolders(address account, uint256 partId);
    event Operate(address who, address _contract, uint256 partId);

    modifier onlyHolder(uint256 _partId) {
        require(msg.sender == parts[_partId].holder);
        _;
    }

    modifier notSticked(uint256 _partId) {
        require(sticked[_partId].masterToken == address(0));
        require(sticked[_partId].masterPartId == 0);
        _;
    }

    /// @notice Produces a new part
    /// @param _metadata Metadata of a part, e. g. serial number
    function createPart(string _metadata) onlyProducer public {
        super.create(1);
        lastId++;
        parts[lastId].holder = msg.sender;
        parts[lastId].metadata = _metadata;
    }

    /// @notice Receives a holder of a part
    /// @param _partId Identifier of a part
    /// @return Address of a holder
    function getPartHolder(uint256 _partId) view public returns (address) {
        return parts[_partId].holder;
    }

    /// @notice Ships a part to a customer
    /// @param _customer Address of a customer
    /// @param _partId Identifier of a part
    function shipPart(uint256 _partId, address _customer) onlyHolder(_partId) notSticked(_partId) public {
        super.ship(_customer, 1);
        partShipments[_partId] = _customer;
    }

    /// @notice A customer applies receptioin of parts
    /// @param _partId Identifier of a part
    function receivePart(uint256 _partId) notSticked(_partId) public {
        require(partShipments[_partId] == msg.sender);
        super.receive(getPartHolder(_partId), 1);
        parts[_partId].holder = msg.sender;
        delete partShipments[_partId];
    }

    /// @notice Burns parts
    /// @param _partId Identifier of a part
    function burnPart(uint256 _partId) onlyHolder(_partId) notSticked(_partId) public {
        super.burn(1);
        delete parts[_partId];
    }

    /// @notice Sticks one part to another
    /// @param _partId Identifier of a part to stick
    /// @param _addr Master token address
    /// @param _masterPartId Master part identifier
    function stickPart(uint256 _partId, address _addr, uint256 _masterPartId) onlyHolder(_partId) notSticked(_partId) public {
        require(_addr != address(0));
        require(_partId != 0);
        require(_masterPartId != 0);
        ProductionToken masterToken;
        masterToken = ProductionToken(_addr);
        require(masterToken.isProductionToken());
        require(msg.sender == masterToken.getPartHolder(_masterPartId));
        sticked[_partId].masterToken = _addr;
        sticked[_partId].masterPartId = _masterPartId;
        emit StickPart(msg.sender, _partId, _addr, _masterPartId);
    }

    /// @notice Unsticks parts
    /// @param _partId Identifier of a part
    function unstickPart(uint256 _partId) onlyHolder(_partId) public {
        require(_partId != 0);
        syncHoldersInternal(_partId);
        delete sticked[_partId];
        emit UnstickPart(msg.sender, _partId);
    }

    function syncHolders(uint256 _partId) public {
        syncHoldersInternal(_partId);
    }

    function syncHoldersInternal(uint256 _partId) internal {
        require(_partId != 0);
        require(isSticked(_partId));
        address oldHolder = getPartHolder(_partId);
        ProductionToken masterToken;
        masterToken = ProductionToken(sticked[_partId].masterToken);
        require(masterToken.isProductionToken());
        address holder = masterToken.getPartHolder(sticked[_partId].masterPartId);
        if (oldHolder != holder) {
            parts[_partId].holder = holder;
            balances[holder] = balances[holder].add(1);
            balances[oldHolder] = balances[oldHolder].sub(1);
            emit SyncHolders(msg.sender, _partId);
        }
    }

    /// @notice Checks if a part is sticked
    /// @param _partId Token ID
    /// @return True if a part is sticked
    function isSticked(uint256 _partId) view public returns (bool) {
        if (sticked[_partId].masterToken == address(0))
            return false;
        else
            return true;
    }

    /// @notice Transfer token for operation to a contract
    /// @param _contract Contract address
    /// @param _partId Token id
    function operate(address _contract, uint256 _partId) notSticked(_partId) public {
        require(_partId != 0);
        require(address(_contract) != 0);
        balances[msg.sender] = balances[msg.sender].sub(1);
        balances[_contract] = balances[_contract].add(1);
        parts[_partId].holder = _contract;
        emit Operate(msg.sender, _contract, _partId);
        producers[_contract] = true;
        emit Producer(_contract, true);
    }

}

