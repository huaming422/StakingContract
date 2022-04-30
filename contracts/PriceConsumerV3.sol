// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {

    AggregatorV3Interface internal USDCpriceFeed;
    AggregatorV3Interface internal USDTpriceFeed;
    AggregatorV3Interface internal BTCpriceFeed;

    /**
     * Network: Rinkeby
     * Aggregator: ETH/USD
     * USDC: 0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB
     * MATIC: 0x7794ee502922e2b723432DDD852B3C30A911F021
     * BTC: 0x2431452A0010a43878bF198e170F6319Af6d27F4
     */
    constructor() {
        USDCpriceFeed = AggregatorV3Interface(0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB);
        USDTpriceFeed = AggregatorV3Interface(0x7794ee502922e2b723432DDD852B3C30A911F021);
        BTCpriceFeed = AggregatorV3Interface(	0x2431452A0010a43878bF198e170F6319Af6d27F4);
    }

    /**
     * Returns the usdc latest price
     */
    function getUSDCLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = USDCpriceFeed.latestRoundData();
        return price;
    }
    /**
     * Returns the usdc latest price
     */
    function getUSDTLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = USDTpriceFeed.latestRoundData();
        return price;
    }
    /**
     * Returns the usdc latest price
     */
    function getBTCLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = BTCpriceFeed.latestRoundData();
        return price;
    }
}
