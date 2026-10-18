// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract NexusEventTicketingHub {
    struct EventListing {
        address payable promoter;
        uint256 ticketPriceWei;
        uint256 totalTickets;
        uint256 soldTickets;
        bool isActive;
        bytes32 eventHash;
    }

    address payable public immutable hubAdmin;
    string public hubDescriptor;
    uint256 public platformFeeBps; // 250 = 2.5%
    uint256 public eventCounter;
    uint256 public accumulatedFees;
    bool public isHubPaused;

    mapping(address => bool) public approvedPromoters;
    mapping(uint256 => EventListing) public events;
    mapping(uint256 => mapping(address => bool)) public hasTicket;

    event PromoterAdded(address indexed promoter);
    event TicketPurchased(uint256 indexed eventId, address indexed buyer, uint256 price);
    event EventCanceled(uint256 indexed eventId);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesDrained(address indexed admin, uint256 amount);
    event FeesHarvested(address indexed admin, uint256 amount);
    event EventListed(uint256 indexed eventId, address indexed promoter, uint256 price, uint256 capacity);
    event HubPauseToggled(bool isPaused);
    event DescriptorUpdated(string newDescriptor);

    modifier onlyAdmin() {
        require(msg.sender == hubAdmin, "NexusTicket: Access denied");
        _;
    }

    modifier whenNotPaused() {
        require(!isHubPaused, "NexusTicket: Hub is paused");
        _;
    }

    constructor() {
        hubAdmin = payable(msg.sender);
        hubDescriptor = "Nexus Base Event Ticketing Core v1";
        platformFeeBps = 250; // 2.5%
        isHubPaused = false;
        approvedPromoters[msg.sender] = true;
    }

    // 1. addEventPromoter
    function addEventPromoter(address promoter) external onlyAdmin {
        require(!approvedPromoters[promoter], "NexusTicket: Already approved");
        approvedPromoters[promoter] = true;
        emit PromoterAdded(promoter);
    }

    // 2. buyEventTicket
    function buyEventTicket(uint256 eventId) external payable whenNotPaused {
        EventListing storage e = events[eventId];
        require(eventId > 0 && eventId <= eventCounter, "NexusTicket: Invalid ID");
        require(e.isActive, "NexusTicket: Event inactive");
        require(e.soldTickets < e.totalTickets, "NexusTicket: Sold out");
        require(!hasTicket[eventId][msg.sender], "NexusTicket: Already have a ticket");
        require(msg.value >= e.ticketPriceWei, "NexusTicket: Insufficient payment");

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 promoterShare = msg.value - fee;

        accumulatedFees += fee;
        e.soldTickets++;
        hasTicket[eventId][msg.sender] = true;

        if (promoterShare > 0) {
            (bool sent, ) = e.promoter.call{value: promoterShare}("");
            require(sent, "NexusTicket: Payout failed");
        }

        emit TicketPurchased(eventId, msg.sender, msg.value);
    }

    // 3. cancelEventListing
    function cancelEventListing(uint256 eventId) external {
        EventListing storage e = events[eventId];
        require(eventId > 0 && eventId <= eventCounter, "NexusTicket: Invalid ID");
        require(msg.sender == e.promoter || msg.sender == hubAdmin, "NexusTicket: Unauthorized");
        require(e.isActive, "NexusTicket: Already inactive");

        e.isActive = false;
        emit EventCanceled(eventId);
    }

    // 4. depositPlatformTreasury
    function depositPlatformTreasury() external payable whenNotPaused {
        require(msg.value > 0, "NexusTicket: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 5. drainTicketReserves
    function drainTicketReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "NexusTicket: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: balance}("");
        require(sent, "NexusTicket: Sweep failed");

        emit ReservesDrained(hubAdmin, balance);
    }

    // 6. harvestPlatformFees
    function harvestPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "NexusTicket: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: amount}("");
        require(sent, "NexusTicket: Harvest failed");

        emit FeesHarvested(hubAdmin, amount);
    }

    // 7. listNewEvent
    function listNewEvent(uint256 ticketPriceWei, uint256 capacity, bytes32 eventHash) external whenNotPaused returns (uint256) {
        require(approvedPromoters[msg.sender], "NexusTicket: Not an approved promoter");
        require(capacity > 0, "NexusTicket: Zero capacity");

        eventCounter++;
        events[eventCounter] = EventListing({
            promoter: payable(msg.sender),
            ticketPriceWei: ticketPriceWei,
            totalTickets: capacity,
            soldTickets: 0,
            isActive: true,
            eventHash: eventHash
        });

        emit EventListed(eventCounter, msg.sender, ticketPriceWei, capacity);
        return eventCounter;
    }

    // 8. pauseTicketingHub
    function pauseTicketingHub(bool isPaused) external onlyAdmin {
        isHubPaused = isPaused;
        emit HubPauseToggled(isPaused);
    }

    // 9. updateHubDescriptor
    function updateHubDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "NexusTicket: Empty string");
        hubDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }

    // Read-метод
    function getEventInfo(uint256 eventId) external view returns (
        address promoter, uint256 price, uint256 total, uint256 sold, bool isActive
    ) {
        EventListing memory e = events[eventId];
        return (e.promoter, e.ticketPriceWei, e.totalTickets, e.soldTickets, e.isActive);
    }
}