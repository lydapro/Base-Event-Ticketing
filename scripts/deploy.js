const hre = require("hardhat");
async function main() {
  const Hub = await hre.ethers.getContractFactory("NexusEventTicketingHub");
  const hub = await Hub.deploy();
  await hub.deployed();
  console.log("Ticketing Hub deployed to:", hub.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
