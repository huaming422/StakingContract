// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/WadMath.sol";
import "./PriceConsumerV3.sol";

/**
 * @title Staking contract
 * @notice Implements the core contract of staking.
 * this contract manages all states and handles user interaction.
 * @author dderabin
 **/
contract Staking is Ownable {
    using SafeMath for uint256;
    using WadMath for uint256;

    uint256 public lendCount;
    uint256 public cashpTotalLiquidity;
    uint256 public totalLiquidity;
    address public cashpAddress;
    address public marketWalletAddress;

    address public address_CashP;
    uint256 public stakingPeriod = 180 days;
    uint256 public withdrawPeriod = 1 days;
    uint256 public cashpPrice = 0.7 * 1e18;
    uint256 public ROI = 2 * 1e18; // 2 %
    uint256 public taxLend = 10 * 1e18;

    /**
     * @dev price oracle of the lending pool contract.
     */
    PriceConsumerV3 priceOracle;

    /**
     * @dev the struct for storing the Lend data
     */
    struct LendRequest {
        address lender;
        uint256 lendId;
        uint256 lendAmount;
        uint256 timeLend;
        uint256 timeLastClaim;
        uint256 timeNextClaim;
        uint256 timeLendDueDate;
        bool retrieved;
        bool isExpired;
    }

    /**
     * @dev the mapping from the user to the struct of that Lend request
     * user address => pool
     */
    mapping(address => uint256) public userLendsCount;

    /**
     * @dev the mapping from user address to LendRequest to the user data of
     * that lends
     */
    mapping(address => mapping(uint256 => LendRequest)) public lends;

    /**
     * @dev emitted on init
     * @param admin the address of admin
     * @param amount the amount to init
     */
    event InitBalance(address indexed admin, uint256 amount);

    /**
     * @dev emitted on lend
     * @param lender the address of lender
     * @param lendAmount the amount to lend
     * @param timeLend the time of Lend
     * @param timeLastClaim the time of you claim
     * @param timeNextClaim the time of next claim
     * @param timeLendDueDate the duedate of lend
     * @param retrieved the flag of the user get the all interest
     */
    event NewLend(
        address indexed lender,
        uint256 lendAmount,
        uint256 timeLend,
        uint256 timeLastClaim,
        uint256 timeNextClaim,
        uint256 timeLendDueDate,
        bool retrieved
    );

    /**
     * @dev emitted on claim
     * @param claimer the type of token that withdrow
     * @param expired the flag of earn interst
     * @param claimAmount the amount to withdraw
     */
    event Claim(address claimer, uint256 claimAmount, bool expired);

    /**
     * @dev emitted on update price of cashp
     * @param price the price of cashp
     */
    event PriceOfCashPUpdated(uint256 price);

    /**
     * @dev emitted on set price oracle
     * @param priceOracleAddress the address of the price oracle
     */
    event PriceOracleUpdated(address indexed priceOracleAddress);

    constructor(
        address _cashpAddress,
        address _marketWalletAddress
    ) {
        lendCount = 1;
        totalLiquidity = 0;
        cashpTotalLiquidity = 0;
        cashpAddress = _cashpAddress;
        marketWalletAddress = _marketWalletAddress;
    }

    function initCashp(uint256 _amount) external onlyOwner {
        require(
            ERC20(cashpAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        ERC20(cashpAddress).increaseAllowance(address(this), _amount);

        cashpTotalLiquidity = cashpTotalLiquidity.add(_amount);
        emit InitBalance(msg.sender, _amount);
    }

    function initFTM() external payable onlyOwner {
        totalLiquidity = totalLiquidity.add(msg.value);
        emit InitBalance(msg.sender, msg.value);
    }

    /**
     * @dev set price oracle of the lending pool. only owner can set the price oracle.
     * @param _oracle the price oracle which will get asset price to the lending pool contract
     */
    function setPriceOracle(PriceConsumerV3 _oracle) external onlyOwner {
        priceOracle = _oracle;
        emit PriceOracleUpdated(address(_oracle));
    }

    /**
     * @dev lend the specific amount of tokens
     * @param _amount the amount of tokens
     */
    function deposite(uint256 _amount) public {
        require(
            ERC20(cashpAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "lendToken: Transfer token from user to contract failed"
        );
        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmount = _amount;
        request.timeLend = block.timestamp;
        request.timeLendDueDate = block.timestamp + 180 days;
        request.timeLastClaim = block.timestamp;
        request.timeNextClaim = block.timestamp + 1 days;
        request.retrieved = false;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;

        ERC20(cashpAddress).increaseAllowance(address(this), _amount);
        cashpTotalLiquidity = cashpTotalLiquidity.add(_amount);
        emit NewLend(
            request.lender,
            request.lendAmount,
            request.timeLend,
            request.timeLastClaim,
            request.timeNextClaim,
            request.timeLendDueDate,
            request.retrieved
        );
    }

    /**
     * @dev compound the specific amount of tokens
     */
    function compound() public {
        uint256 totalClaimAmount;
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest storage req = lends[msg.sender][i];
            if (!req.retrieved) {
                if (req.lendId >= 0) {
                    if (req.retrieved == false) {
                        if (req.timeNextClaim < block.timestamp) {
                            if (req.lender == msg.sender) {
                                uint256 stakingDuration;

                                if (req.timeLendDueDate >= block.timestamp) {
                                    stakingDuration = (block.timestamp -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                } else {
                                    stakingDuration = (req.timeLendDueDate -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                }

                                uint256 interestAmount = req
                                    .lendAmount
                                    .wadMul(ROI)
                                    .div(100)
                                    .mul(stakingDuration);

                                totalClaimAmount.add(interestAmount);
                            }
                        }
                    }
                }
            }
        }
        require(
            checkEnoughLiquidity(totalClaimAmount, 1),
            "withDraw: not enough FTM liquidity"
        );

        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmount = totalClaimAmount;
        request.timeLend = block.timestamp;
        request.timeLendDueDate = block.timestamp + 180 days;
        request.timeLastClaim = block.timestamp;
        request.timeNextClaim = block.timestamp + 1 days;
        request.retrieved = false;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;

        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest storage req = lends[msg.sender][i];
            if (!req.retrieved) {
                if (req.lendId >= 0) {
                    if (req.retrieved == false) {
                        if (req.timeNextClaim < block.timestamp) {
                            if (req.lender == msg.sender) {
                                req.timeLastClaim = block.timestamp;
                                req.timeNextClaim = block.timestamp + 1 days;
                                if (req.timeNextClaim > req.timeLendDueDate) {
                                    req.retrieved = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        emit NewLend(
            request.lender,
            request.lendAmount,
            request.timeLend,
            request.timeLastClaim,
            request.timeNextClaim,
            request.timeLendDueDate,
            request.retrieved
        );
    }

    /**
     * @dev get the price of tokens from chainlink
     * @param mtype the type token to get price
     */
    function getTokenPriceInUSD(uint256 mtype) public view returns (uint256) {
        require(
            address(priceOracle) != address(0),
            "price oracle isn't initialized"
        );
        uint256 tokenPrice;
        if (mtype == 1) {
            tokenPrice = uint256(priceOracle.getLatestPrice());
        }
        require(tokenPrice > 0, "token price isn't correct");
        return tokenPrice;
    }

    /**
     * @dev get the ether amount as collateral for specific token
     * @param cashpAmount the amount token for loan
     */
    function claimAmount(uint256 cashpAmount) public view returns (uint256) {
        uint256 result;
        uint256 priceFTM = getTokenPriceInUSD(1);
        uint256 priceCashp = cashpPrice;
        result = cashpAmount.mul(priceCashp).div(priceFTM);
        return result;
    }

    /**
     * @dev check the liquidity
     * @param _amount the amount of tokens
     * @param mtype the type token for loan
     */
    function checkEnoughLiquidity(uint256 _amount, uint256 mtype)
        public
        view
        returns (bool)
    {
        uint256 total;
        if (mtype == 1) {
            total = totalLiquidity;
        } else if (mtype == 2) {
            total = cashpTotalLiquidity;
        }
        if (_amount > total) {
            return false;
        } else {
            return true;
        }
    }

    /**
     * @dev get the total liquidity in usd
     * @param mtype the type of liquidity
     */
    function getTotalLiquidityInUSD(uint256 mtype)
        public
        view
        returns (uint256)
    {
        uint256 totalPrice;
        require(
            address(priceOracle) != address(0),
            "price oracle isn't initialized"
        );

        if (mtype == 1) {
            totalPrice = totalLiquidity.wadMul(getTokenPriceInUSD(mtype));
        } else if (mtype == 2) {
            totalPrice = cashpTotalLiquidity.wadMul(cashpPrice);
        }
        return totalPrice;
    }

    /**
     * @dev emitted on withDrawReserve
     * @param _amount the amount of token to withdraw
     * @param mtype the type of the token
     */
    function withDrawReserve(uint256 _amount, uint256 mtype)
        external
        onlyOwner
    {
        require(
            checkEnoughLiquidity(_amount, mtype),
            "withDraw: not enough liquidity"
        );
        if (mtype == 1) {
            payable(msg.sender).transfer(_amount);
        } else {
            require(
                ERC20(cashpAddress).transferFrom(
                    address(this),
                    msg.sender,
                    _amount
                ),
                "Transaction failed on init function"
            );
        }

        if (mtype == 1) {
            totalLiquidity = totalLiquidity.sub(_amount);
        } else if (mtype == 2) {
            cashpTotalLiquidity = cashpTotalLiquidity.sub(_amount);
        }
    }

    /**
     * @dev claim the all interests
     */
    function getTotalClaimAmount() public view returns (uint256) {
        uint256 totalClaimAmount;
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest storage req = lends[msg.sender][i];
            if (!req.retrieved) {
                if (req.lendId >= 0) {
                    if (req.retrieved == false) {
                        if (req.timeNextClaim < block.timestamp) {
                            if (req.lender == msg.sender) {
                                uint256 stakingDuration;

                                if (req.timeLendDueDate >= block.timestamp) {
                                    stakingDuration = (block.timestamp -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                } else {
                                    stakingDuration = (req.timeLendDueDate -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                }

                                uint256 interestAmount = req
                                    .lendAmount
                                    .wadMul(ROI)
                                    .div(100)
                                    .mul(stakingDuration);

                                totalClaimAmount.add(interestAmount);
                            }
                        }
                    }
                }
            }
        }

        return totalClaimAmount;
    }

    /**
     * @dev claim the all interests
     */
    function claim() external {
        uint256 totalClaimAmount;
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest storage req = lends[msg.sender][i];
            if (!req.retrieved) {
                if (req.lendId >= 0) {
                    if (req.retrieved == false) {
                        if (req.timeNextClaim < block.timestamp) {
                            if (req.lender == msg.sender) {
                                uint256 stakingDuration;

                                if (req.timeLendDueDate >= block.timestamp) {
                                    stakingDuration = (block.timestamp -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                } else {
                                    stakingDuration = (req.timeLendDueDate -
                                        req.timeLastClaim).div(60).div(60).div(
                                            24
                                        );
                                }

                                uint256 interestAmount = req
                                    .lendAmount
                                    .wadMul(ROI)
                                    .div(100)
                                    .mul(stakingDuration);

                                totalClaimAmount.add(interestAmount);
                            }
                        }
                    }
                }
            }
        }
        require(
            checkEnoughLiquidity(totalClaimAmount, 1),
            "withDraw: not enough FTM liquidity"
        );

        uint256 percentage = totalClaimAmount.wadDiv(cashpTotalLiquidity).mul(
            100
        );

        uint256 whaleTax = 0;

        if (percentage >= 1 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(5).div(100);
        } else if (percentage >= 2 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(10).div(100);
        } else if (percentage >= 3 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(15).div(100);
        } else if (percentage >= 4 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(20).div(100);
        } else if (percentage >= 5 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(25).div(100);
        } else if (percentage >= 6 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(30).div(100);
        } else if (percentage >= 7 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(35).div(100);
        } else if (percentage >= 8 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(40).div(100);
        } else if (percentage >= 9 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(45).div(100);
        } else if (percentage >= 10 * 1e18) {
            whaleTax = totalClaimAmount.wadMul(50).div(100);
        }

        uint256 realClaimAmount = totalClaimAmount.sub(whaleTax);

        require(
            ERC20(cashpAddress).transferFrom(
                address(this),
                msg.sender,
                realClaimAmount
            ),
            "withDraw: fail transfer cashp from contract to user"
        );

        require(
            ERC20(cashpAddress).transferFrom(
                address(this),
                marketWalletAddress,
                whaleTax
            ),
            "withDraw: fail transfer cashp from contract to market wallet "
        );

        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest storage req = lends[msg.sender][i];
            if (!req.retrieved) {
                if (req.lendId >= 0) {
                    if (req.retrieved == false) {
                        if (req.timeNextClaim < block.timestamp) {
                            if (req.lender == msg.sender) {
                                req.timeLastClaim = block.timestamp;
                                req.timeNextClaim = block.timestamp + 1 days;
                                if (req.timeNextClaim > req.timeLendDueDate) {
                                    req.retrieved = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * @dev set the cashp price
     * @param price the price of token
     */
    function setCashpPrice(uint256 price) external onlyOwner {
        cashpPrice = price;
        emit PriceOfCashPUpdated(cashpPrice);
    }
}
