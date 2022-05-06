// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {

    AggregatorV3Interface internal USDCpriceFeed;
    AggregatorV3Interface internal USDTpriceFeed;
    AggregatorV3Interface internal BTCpriceFeed;

    /**
     * Network: Moonriver
     * Aggregator: ETH/USD
     * USDC: 0x12870664a77Dd55bBdcDe32f91EB3244F511eF2e
     * USDT: 0xF80DAd54AF79257D41c30014160349896ca5370a
     * BTC: 0x1B5C6cF9Df1CBF30387C24CC7DB1787CCf65C797
     */
    constructor() {
        USDCpriceFeed = AggregatorV3Interface(0x12870664a77Dd55bBdcDe32f91EB3244F511eF2e);
        USDTpriceFeed = AggregatorV3Interface(0xF80DAd54AF79257D41c30014160349896ca5370a);
        BTCpriceFeed = AggregatorV3Interface(0x1B5C6cF9Df1CBF30387C24CC7DB1787CCf65C797);
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
