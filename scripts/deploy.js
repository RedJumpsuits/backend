async function main() {
  // Get the signer's account (deployer)
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Get the contract factory for CampusBooking
  const CampusBooking = await ethers.getContractFactory("CampusBooking");

  // Deploy the contract
  const campusBooking = await CampusBooking.deploy();
  console.log(campusBooking)
  console.log("CampusBooking contract deployed to:", await campusBooking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
