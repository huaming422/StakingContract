const hre = require("hardhat");
// token: 0xd9D905400b444732B6b47Df12735f9253e44DA06
// loan:  0x6DCaa48345deA866702eFbd084094449b6c83A40
// npx hardhat verify --network testnet 0x6DCaa48345deA866702eFbd084094449b6c83A40 "0xd9D905400b444732B6b47Df12735f9253e44DA06"
async function main() {
    const OdonToken = await hre.ethers.getContractFactory("Token");
    const Loan = await hre.ethers.getContractFactory("Loan");
    const odonToken = await OdonToken.deploy();
    await odonToken.deployed();
    const loan = await Loan.deploy(odonToken.address);
    await loan.deployed();

    console.log("OdonToken deployed to:", odonToken.address);
    console.log("Loan deployed to:", loan.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });