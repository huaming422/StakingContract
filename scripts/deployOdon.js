const hre = require("hardhat");
// odon: 0xaD321937B4d36Da0ef1B53eDbCdEc02C33238fd9
// usdc: 0x4a5047b2651206E98CEbeAb1FA468Fa2287B405E
// usdt: 0x37c27383279Ab8f2E5a559d3B606C7F14862386C
// wbtc: 0x2c46F9d787e2c6650d63113d3d27b4640157410a
// eth:  0x8a93290aea095bdeceA93BD94Faee56E31b41720
async function main() {
    const OdonToken = await hre.ethers.getContractFactory("ODON");
   
    const odonToken = await OdonToken.deploy();
    await odonToken.deployed();

    console.log("OdonToken deployed to:", odonToken.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });