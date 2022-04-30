const hre = require("hardhat");
// odon: 0x28D3d93f3223A2B80E32e37311D4cB7147DeC5Cd
// usdc: 0x7A38D14fA901B9962df16300579f86B640413841
// usdt: 0x8ED23c0c13980B552fEEB07d16B0A3F084917f63
// btc: 0x0888f978369185d44aa617F9a3FECc4192392B63
// loan:  0x6719c3d7d181688400F53aa312d01A6e9AD6CFA1
// npx hardhat verify --network rinkeby 0x6719c3d7d181688400F53aa312d01A6e9AD6CFA1 "0x28D3d93f3223A2B80E32e37311D4cB7147DeC5Cd" "0x7A38D14fA901B9962df16300579f86B640413841" "0x8ED23c0c13980B552fEEB07d16B0A3F084917f63" "0x0888f978369185d44aa617F9a3FECc4192392B63"
async function main() {
    const PriceConsumerV3 = await hre.ethers.getContractFactory("PriceConsumerV3");
    const priceconsumer = await PriceConsumerV3.deploy();
    await priceconsumer.deployed();
    const Loan = await hre.ethers.getContractFactory("Loan");
    const loan = await Loan.deploy( "0x28D3d93f3223A2B80E32e37311D4cB7147DeC5Cd", "0x7A38D14fA901B9962df16300579f86B640413841", "0x8ED23c0c13980B552fEEB07d16B0A3F084917f63", "0x0888f978369185d44aa617F9a3FECc4192392B63");
    await loan.deployed();

    await loan.setPriceOracle(priceconsumer.address);
  
    console.log("PriceOracle deployed to:", priceconsumer.address);
    console.log("Loan deployed to:", loan.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });