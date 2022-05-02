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
     * BTC: 0xECe365B379E1dD183B20fc5f022230C044d51404
     */
    constructor() {
        USDCpriceFeed = AggregatorV3Interface(0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB);
        USDTpriceFeed = AggregatorV3Interface(0x7794ee502922e2b723432DDD852B3C30A911F021);
        BTCpriceFeed = AggregatorV3Interface(0xECe365B379E1dD183B20fc5f022230C044d51404);
    }

    /**
     * Returns the usdc latest price
     */
    function getUSDCLatestPrice() public view returns (uint256) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = USDCpriceFeed.latestRoundData();
        return uint256(price);
    }
    /**
     * Returns the usdc latest price
     */
    function getUSDTLatestPrice() public view returns (uint256) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = USDTpriceFeed.latestRoundData();
        return uint256(price);
    }
    /**
     * Returns the usdc latest price
     */
    function getBTCLatestPrice() public view returns (uint256) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = BTCpriceFeed.latestRoundData();
        return uint256(price);
    }
}
