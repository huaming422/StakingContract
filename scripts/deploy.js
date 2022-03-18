const hre = require("hardhat");
// token: 0x85d1b81281AEF63122D97b556682Cf9934200b7F
// loan:  0xaaE54151De7137E080538d84b7b8ab02F58A9768
// npx hardhat verify --network rinkeby 0xaaE54151De7137E080538d84b7b8ab02F58A9768 "0x85d1b81281AEF63122D97b556682Cf9934200b7F"
async function main() {
    //const BowToken = await hre.ethers.getContractFactory("BowToken");
    const Loan = await hre.ethers.getContractFactory("Loan");
    //const bowToken = await BowToken.deploy();
    //await bowToken.deployed();
    const loan = await Loan.deploy("0x85d1b81281AEF63122D97b556682Cf9934200b7F");
    await loan.deployed();

    // console.log("BowToken deployed to:", bowToken.address);
    console.log("Loan deployed to:", loan.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });