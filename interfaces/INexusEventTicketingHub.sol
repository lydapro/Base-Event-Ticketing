// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface INexusEventTicketingHub {
    function buyEventTicket(uint256 eventId) external payable;
    function listNewEvent(uint256 ticketPriceWei, uint256 capacity, bytes32 eventHash) external returns (uint256);
}
