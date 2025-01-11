require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
        url: "https://sepolia.infura.io/v3/06ca41755b2d4f828f510835bcc3b6a5",
        accounts: ["8394f214fcbbad0c86b9a417e1155cfe69a7a5110782f2f66b0e9271010b8c58"],
    },
  },
};
