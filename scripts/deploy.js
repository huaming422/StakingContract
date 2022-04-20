const hre = require("hardhat");
// odon: 0xd9D905400b444732B6b47Df12735f9253e44DA06
// usdc: 0xd9D905400b444732B6b47Df12735f9253e44DA06
// usdt: 0xd9D905400b444732B6b47Df12735f9253e44DA06
// wbtc: 0xd9D905400b444732B6b47Df12735f9253e44DA06
// loan:  0x6DCaa48345deA866702eFbd084094449b6c83A40
// npx hardhat verify --network testnet 0x6DCaa48345deA866702eFbd084094449b6c83A40 "0xd9D905400b444732B6b47Df12735f9253e44DA06"
async function main() {
    const OdonToken = await hre.ethers.getContractFactory("OdonToken");
    const UsdcToken = await hre.ethers.getContractFactory("UsdcToken");
    const UsdtToken = await hre.ethers.getContractFactory("UsdtToken");
    const WbtcToken = await hre.ethers.getContractFactory("WbtcToken");
    const Loan = await hre.ethers.getContractFactory("Loan");
    const odonToken = await OdonToken.deploy();
    await odonToken.deployed();
    const usdcToken = await UsdcToken.deploy();
    await usdcToken.deployed();
    const usdtToken = await UsdtToken.deploy();
    await usdtToken.deployed();
    const wbtcToken = await WbtcToken.deploy();
    await wbtcToken.deployed();
    const loan = await Loan.deploy(odonToken.address, usdcToken.address, usdtToken.address, wbtcToken.address);
    await loan.deployed();

    console.log("OdonToken deployed to:", odonToken.address);
    console.log("UsdcToken deployed to:", usdcToken.address);
    console.log("UsdtToken deployed to:", usdtToken.address);
    console.log("WbtcToken deployed to:", wbtcToken.address);
    console.log("Loan deployed to:", loan.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });