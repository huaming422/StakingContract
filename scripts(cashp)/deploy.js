const hre = require("hardhat");
// eth: 0xab1ea131FD1f9aF453A38fEA643c7e7946B5a144
// odon: 0x28D3d93f3223A2B80E32e37311D4cB7147DeC5Cd
// usdc: 0x7A38D14fA901B9962df16300579f86B640413841
// usdt: 0x8ED23c0c13980B552fEEB07d16B0A3F084917f63
// wbtc: 0x0888f978369185d44aa617F9a3FECc4192392B63
// loan:  0x6719c3d7d181688400F53aa312d01A6e9AD6CFA1
// npx hardhat verify --network rinkeby 0x6719c3d7d181688400F53aa312d01A6e9AD6CFA1 "0xab1ea131FD1f9aF453A38fEA643c7e7946B5a144" "0x28D3d93f3223A2B80E32e37311D4cB7147DeC5Cd" "0x7A38D14fA901B9962df16300579f86B640413841" "0x8ED23c0c13980B552fEEB07d16B0A3F084917f63" "0x0888f978369185d44aa617F9a3FECc4192392B63"
async function main() {
    const PriceConsumerV3 = await hre.ethers.getContractFactory("PriceConsumerV3");
    const priceconsumer = await PriceConsumerV3.deploy();
    await priceconsumer.deployed();
    const CashP = await hre.ethers.getContractFactory("CashP");
    const cashp = await CashP.deploy();
    await cashp.deployed();
    const Staking = await hre.ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(cashp.address, "0x4F499C43b8060FB794147B18cefec7D5Ad76107D");
    await staking.deployed();

    await loan.setPriceOracle(priceconsumer.address);
  
    console.log("PriceConsumerV3 deployed to:", priceconsumer.address);
    console.log("Cashp deployed to:", cashp.address);
    console.log("Staking deployed to:", staking.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });