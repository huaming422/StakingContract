// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PriceConsumerV3.sol";
import "./libraries/WadMath.sol";
import "./libraries/Math.sol";

/**
 * @title Loan contract
 * @notice Implements the core contract of lending.
 * this contract manages all states and handles user interaction.
 * @author dderabin
 **/
contract Loan is Ownable {
    using SafeMath for uint256;
    using WadMath for uint256;
    using Math for uint256;
    uint256 public loanCount;
    uint256 public lendCount;
    uint256 public odonTotalLiquidity;
    uint256 public usdcTotalLiquidity;
    uint256 public usdtTotalLiquidity;
    uint256 public btcTotalLiquidity;
    uint256 public totalLiquidity;
    uint256 public odonPrice = 0.05 * 1e8;
    address public movrAddress;
    address public odonAddress;
    address public usdcAddress;
    address public usdtAddress;
    address public btcAddress;
    uint256 public usdtLTV = 65 * 1e18;
    uint256 public usdcLTV = 68 * 1e18;
    uint256 public btcLTV = 54 * 1e18;
    uint256 public dangerousLTV = 85 * 1e18;
    uint256 public firstAddAPY = 3 * 1e18;
    uint256 public secondAddAPY = 5 * 1e18;
    uint256 public usdcBorrowAPY = 10 * 1e18;
    uint256 public usdtBorrowAPY = 11 * 1e18;
    uint256 public btcBorrowAPY = 12 * 1e18;
    uint256 public usdcLendAPY = 5 * 1e18;
    uint256 public usdtLendAPY = 6 * 1e18;
    uint256 public btcLendAPY = 8 * 1e18;
    uint256 public loanMode = 1;

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
        uint256 paybackAmount;
        uint256 timeLend;
        uint256 timeCanGetInterest; // lend more than 30 days can get interest
        bool retrieved;
        uint256 mtype;
    }

    /**
     * @dev the struct for storing the Loan data
     */
    struct LoanRequest {
        address borrower;
        uint256 loanAmount;
        uint256 collateralAmount;
        uint256 paybackAmount;
        uint256 loanDueDate;
        uint256 duration;
        uint256 loanId;
        bool isPayback;
        bool isLiquidate;
        uint256 mtype;
        uint256 ctype;
    }

    /**
     * @dev the mapping from the user to the struct of that Loan request
     * user address => pool
     */
    mapping(address => uint256) public userLoansCount;

    /**
     * @dev the mapping from the user to the struct of that Lend request
     * user address => pool
     */
    mapping(address => uint256) public userLendsCount;

    /**
     * @dev the mapping from user address to LoanRequest to the user data of
     * that loans
     */
    mapping(address => mapping(uint256 => LoanRequest)) public loans;

    /**
     * @dev the mapping from user address to LendRequest to the user data of
     * that lends
     */
    mapping(address => mapping(uint256 => LendRequest)) public lends;

    /**
     * @dev list of all users who loan on the loan contract.
     */
    address[] public LoanUserList;

    /**
     * @dev list of all users who lend on the lend contract.
     */
    address[] public LendUserList;

    /**
     * @dev emitted on borrow
     * @param borrower the address of borrower
     * @param loanAmount the amount to borrow
     * @param collateralAmount the amount of collateral
     * @param paybackAmount the amount of payback
     * @param loanDueDate the duadate of borrow
     * @param duration the duration of borrow
     * @param mtype the type of borrow token
     * @param ctype the type of collater token
     */
    event NewLoan(
        address indexed borrower,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 paybackAmount,
        uint256 loanDueDate,
        uint256 duration,
        uint256 mtype,
        uint256 ctype
    );

    /**
     * @dev emitted on init
     * @param admin the address of admin
     * @param amount the amount to init
     * @param mtype the type of init token
     */
    event InitBalance(address indexed admin, uint256 amount, uint256 mtype);

    /**
     * @dev emitted on lend
     * @param lender the address of lender
     * @param lendAmount the amount to lend
     * @param paybackAmount the amount of payback
     * @param timeLend the time of Lend
     * @param timeCanGetInterest the flag of can get interest
     * @param retrieved the flag of retrieved
     * @param mtype the type of lend token
     */
    event NewLend(
        address indexed lender,
        uint256 lendAmount,
        uint256 paybackAmount,
        uint256 timeLend,
        uint256 timeCanGetInterest,
        bool retrieved,
        uint256 mtype
    );

    /**
     * @dev emitted on withdraw
     * @param isEarnInterest the flag of earn interst
     * @param withdrawAmount the amount to withdraw
     * @param mtype the type of token that withdrow
     */
    event Withdraw(bool isEarnInterest, uint256 withdrawAmount, uint256 mtype);

    /**
     * @dev emitted on withdraw
     * @param withdrawAmount the amount to withdraw
     * @param mtype the type of token that withdrow
     */
    event WithDrawReserve(uint256 withdrawAmount, uint256 mtype);

    /**
     * @dev emitted on payback
     * @param borrower the address of borrower
     * @param paybackSuccess the flag of payback success
     * @param paybackTime the time of payback
     * @param paybackAmount the amount to payback
     * @param returnCollateralAmount the amount to collateral
     * @param mtype the type of payback token
     * @param ctype the type of collateral token
     */
    event PayBack(
        address borrower,
        bool paybackSuccess,
        uint256 paybackTime,
        uint256 paybackAmount,
        uint256 returnCollateralAmount,
        uint256 mtype,
        uint256 ctype
    );

    /**
     * @dev emitted on payback
     * @param liquidator the address of liquidator
     * @param liquidateTime the time to payback
     */
    event Liquidate(address liquidator, uint256 liquidateTime);

    /**
     * @dev emitted on update lend apy
     * @param _usdcAPY the previous apy
     * @param _usdtAPY the new apy
     * @param _btcAPY the type of token
     */
    event BorrowAPYUpdated(uint256 _usdcAPY, uint256 _usdtAPY, uint256 _btcAPY);

    /**
     * @dev emitted on update lend apy
     * @param _usdcAPY the previous apy
     * @param _usdtAPY the new apy
     * @param _btcAPY the type of token
     */
    event LendAPYUpdated(uint256 _usdcAPY, uint256 _usdtAPY, uint256 _btcAPY);

    /**
     * @dev emitted on update lend apy
     * @param _usdcLTV the previous apy
     * @param _usdtLTV the new apy
     * @param _btcLTV the type of token
     */
    event StandardLTVUpdated(
        uint256 _usdcLTV,
        uint256 _usdtLTV,
        uint256 _btcLTV
    );

    /**
     * @dev emitted on set price oracle
     * @param priceOracleAddress the address of the price oracle
     */
    event PriceOracleUpdated(address indexed priceOracleAddress);

    /**
     * @dev emitted on set price of odon
     * @param _price the price of the odon
     */
    event OdonPriceUpdated(uint256 _price);

    /**
     * @dev emitted on set duration mode of loan
     * @param mtype the type of mode
     */
    event LoanDurationModeUpdated(uint256 mtype);

    constructor(
        address _odonAddress,
        address _usdcAddress,
        address _usdtAddress,
        address _btcAddress
    ) {
        loanCount = 0;
        lendCount = 0;
        totalLiquidity = 0;
        usdcTotalLiquidity = 0;
        odonTotalLiquidity = 0;
        usdtTotalLiquidity = 0;
        btcTotalLiquidity = 0;
        odonAddress = _odonAddress;
        usdcAddress = _usdcAddress;
        usdtAddress = _usdtAddress;
        btcAddress = _btcAddress;
    }

    function init(uint256 _amount, uint256 mtype) external onlyOwner {
        // require(totalLiquidity == 0);
        address tokenAddress;
        if (mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (mtype == 4) {
            tokenAddress = btcAddress;
        }
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        totalLiquidity = address(this).balance;
        if (mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.add(_amount);
        } else if (mtype == 3) {
            usdcTotalLiquidity = usdtTotalLiquidity.add(_amount);
        } else if (mtype == 4) {
            usdcTotalLiquidity = btcTotalLiquidity.add(_amount);
        }

        emit InitBalance(msg.sender, _amount, mtype);
    }

    /**
     * @dev add user to Lend user list
     * @param _user the address of specific user
     */
    function addUserToLendUserList(address _user) public {
        bool alreadyIn = false;
        for (uint256 i = 0; i < LendUserList.length; i++) {
            if (LendUserList[i] == _user) {
                alreadyIn = true;
            }
        }
        if (alreadyIn == false) {
            LendUserList.push(_user);
        }
    }

    /**
     * @dev add user to Loan user list
     * @param _user the address of specific user
     */
    function addUserToLoanUserList(address _user) public {
        bool alreadyIn = false;
        for (uint256 i = 0; i < LoanUserList.length; i++) {
            if (LoanUserList[i] == _user) {
                alreadyIn = true;
            }
        }

        if (alreadyIn == false) {
            LoanUserList.push(_user);
        }
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
     * @dev get the ether amount as collateral for specific token
     * @param lnAmount the amount token for loan
     * @param mtype the type token for loan
     * @param ctype the type token for loan
     */
    function collateralAmount(
        uint256 lnAmount,
        uint256 mtype,
        uint256 ctype
    ) public view returns (uint256) {
        // collateral amount = loan amount / LTV * 100
        uint256 result;
        uint256 priceCollateralToken = getTokenPriceInUSD(ctype);
        uint256 priceLoanToken = getTokenPriceInUSD(mtype);
        if (mtype == 2) {
            result = lnAmount.wadDiv(usdcLTV).mul(100);
        } else if (mtype == 3) {
            result = lnAmount.wadDiv(usdtLTV).mul(100);
        } else if (mtype == 4) {
            result = lnAmount.wadDiv(btcLTV).mul(100);
        }
        result = result.mul(priceLoanToken).div(priceCollateralToken);
        return result;
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
        if (mtype == 2) {
            tokenPrice = priceOracle.getUSDCLatestPrice();
        } else if (mtype == 3) {
            tokenPrice = priceOracle.getUSDTLatestPrice();
        } else if (mtype == 4) {
            tokenPrice = priceOracle.getBTCLatestPrice();
        } else if (mtype == 5) {
            tokenPrice = odonPrice;
        }
        require(tokenPrice > 0, "token price isn't correct");
        return tokenPrice;
    }

    /**
     * @dev get the token amount from collateral for loan
     * @param colAmount the amount of ether as collatera
     * @param mtype the type token for loan
     * @param ctype the type token for loan
     */
    function loanAmount(
        uint256 colAmount,
        uint256 mtype,
        uint256 ctype
    ) public view returns (uint256) {
        // loan amount = collateral amount * LTV / 100
        uint256 result;
        uint256 priceCollateralToken = getTokenPriceInUSD(ctype);
        uint256 priceLoanToken = getTokenPriceInUSD(mtype);
        if (mtype == 2) {
            result = colAmount.wadMul(usdcLTV).div(100);
        } else if (mtype == 3) {
            result = colAmount.wadMul(usdtLTV).div(100);
        } else if (mtype == 4) {
            result = colAmount.wadMul(btcLTV).div(100);
        }
        result = result.mul(priceCollateralToken).div(priceLoanToken);
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
            total = usdcTotalLiquidity;
        } else if (mtype == 3) {
            total = usdtTotalLiquidity;
        } else if (mtype == 4) {
            total = btcTotalLiquidity;
        } else if (mtype == 5) {
            total = odonTotalLiquidity;
        }
        if (_amount > total) {
            return false;
        } else {
            return true;
        }
    }

    /**
     * @dev loan the specific amount of tokens
     * @param _amount the amount of tokens
     * @param _duration the timeline
     * @param mtype the type of token to loan
     * @param ctype the type of token as collateral
     */
    function loan(
        uint256 _amount,
        uint256 _colAmount,
        uint256 _duration,
        uint256 mtype,
        uint256 ctype
    ) public {
        uint256 lnamount;
        if (mtype == 2) {
            lnamount = _amount.div(1000000000000);
        } else if (mtype == 3) {
            lnamount = _amount.div(1000000000000);
        } else if (mtype == 4) {
            lnamount = _amount.div(10000000000);
        }
        require(
            checkEnoughLiquidity(lnamount, mtype),
            "loanEther: not enough liquidity"
        );
        LoanRequest memory newLoan;
        newLoan.borrower = msg.sender;

        newLoan.loanAmount = lnamount;
        newLoan.collateralAmount = _colAmount;
        newLoan.loanId = userLoansCount[msg.sender];
        newLoan.isPayback = false;
        newLoan.isLiquidate = false;
        newLoan.mtype = mtype;
        newLoan.ctype = ctype;
        uint256 borrowAPY;
        if (mtype == 2) {
            borrowAPY = usdcBorrowAPY;
        } else if (mtype == 3) {
            borrowAPY = usdtBorrowAPY;
        } else if (mtype == 4) {
            borrowAPY = btcBorrowAPY;
        }
        if (loanMode == 1) {
            if (_duration == 7) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 7 days;
                newLoan.duration = 7 days;
            } else if (_duration == 14) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(firstAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 14 days;
                newLoan.duration = 14 days;
            } else if (_duration == 30) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(secondAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 30 days;
                newLoan.duration = 30 days;
            } else {
                revert("loanToken: no valid duration!");
            }
        } else if (loanMode == 2) {
            if (_duration == 30) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 30 days;
                newLoan.duration = 30 days;
            } else if (_duration == 60) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(firstAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 60 days;
                newLoan.duration = 60 days;
            } else if (_duration == 90) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(secondAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 90 days;
                newLoan.duration = 90 days;
            } else {
                revert("loanToken: no valid duration!");
            }
        } else if (loanMode == 3) {
            if (_duration == 90) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 90 days;
                newLoan.duration = 90 days;
            } else if (_duration == 180) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(firstAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 180 days;
                newLoan.duration = 180 days;
            } else if (_duration == 360) {
                newLoan.paybackAmount = lnamount.add(
                    lnamount.wadMul(secondAddAPY + borrowAPY).div(100)
                );
                newLoan.loanDueDate = block.timestamp + 360 days;
                newLoan.duration = 360 days;
            } else {
                revert("loanToken: no valid duration!");
            }
        }
        address collateralAddress;
        if (ctype != 1) {
            collateralAddress = odonAddress;
            require(
                IERC20(collateralAddress).transferFrom(
                    msg.sender,
                    address(this),
                    newLoan.collateralAmount
                ),
                "loanToken: Transfer token from contract to user failed"
            );
            // ERC20(collateralAddress).increaseAllowance(
            //     address(this),
            //     newLoan.collateralAmount
            // );
        }
        if (ctype == 1) {
            // totalLiquidity = totalLiquidity.add(msg.value);
        } else {
            odonTotalLiquidity = odonTotalLiquidity.add(
                newLoan.collateralAmount
            );
        }
        address tokenAddress;
        if (mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (mtype == 4) {
            tokenAddress = btcAddress;
        }
        require(
            IERC20(tokenAddress).transferFrom(
                address(this),
                msg.sender,
                lnamount
            ),
            "loanToken: Transfer token from contract to user failed"
        );
        if (mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.sub(lnamount);
        } else if (mtype == 3) {
            usdtTotalLiquidity = usdtTotalLiquidity.sub(lnamount);
        } else if (mtype == 4) {
            btcTotalLiquidity = btcTotalLiquidity.sub(lnamount);
        }
        loans[msg.sender][userLoansCount[msg.sender]] = newLoan;
        loanCount++;
        userLoansCount[msg.sender]++;
        emit NewLoan(
            msg.sender,
            newLoan.loanAmount,
            newLoan.collateralAmount,
            newLoan.paybackAmount,
            newLoan.loanDueDate,
            newLoan.duration,
            newLoan.mtype,
            newLoan.ctype
        );
    }

    /**
     * @dev lend the specific amount of tokens
     * @param _amount the amount of tokens
     * @param mtype the type token for loan
     */
    function lendToken(uint256 _amount, uint256 mtype) public {
        address tokenAddress;
        if (mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (mtype == 4) {
            tokenAddress = btcAddress;
        }
        require(
            IERC20(tokenAddress).transferFrom(
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
        // 5% interest
        if (mtype == 2) {
            request.paybackAmount = _amount.add(
                _amount.wadMul(usdcLendAPY).div(100)
            );
        } else if (mtype == 3) {
            request.paybackAmount = _amount.add(
                _amount.wadMul(usdtLendAPY).div(100)
            );
        } else if (mtype == 4) {
            request.paybackAmount = _amount.add(
                _amount.wadMul(btcLendAPY).div(100)
            );
        }
        request.timeLend = block.timestamp;
        request.timeCanGetInterest = block.timestamp + 30 days;
        request.retrieved = false;
        request.mtype = mtype;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;

        // ERC20(tokenAddress).increaseAllowance(address(this), _amount);
        if (mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.add(_amount);
        } else if (mtype == 3) {
            usdtTotalLiquidity = usdtTotalLiquidity.add(_amount);
        }
        if (mtype == 4) {
            btcTotalLiquidity = btcTotalLiquidity.add(_amount);
        }
        addUserToLendUserList(msg.sender);
        emit NewLend(
            request.lender,
            request.lendAmount,
            request.paybackAmount,
            request.timeLend,
            request.timeCanGetInterest,
            request.retrieved,
            request.mtype
        );
    }

    /**
     * @dev lend the specific amount of tokens
     * @param _amount the amount of tokens
     * @param mtype the type token for loan
     */
    function depositToken(uint256 _amount, uint256 mtype) public {
        address tokenAddress;
        if (mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (mtype == 4) {
            tokenAddress = btcAddress;
        }
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "lendToken: Transfer token from user to contract failed"
        );

        // ERC20(tokenAddress).increaseAllowance(address(this), _amount);
        if (mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.add(_amount);
        } else if (mtype == 3) {
            usdtTotalLiquidity = usdtTotalLiquidity.add(_amount);
        }
        if (mtype == 4) {
            btcTotalLiquidity = btcTotalLiquidity.add(_amount);
        }
        addUserToLendUserList(msg.sender);
        emit InitBalance(msg.sender, _amount, mtype);
    }

    /**
     * @dev get the LTV of specific loan
     * @param _borrower the id of loan
     * @param _id the id of loan
     */
    function getLoansLTV(address _borrower, uint256 _id)
        public
        view
        returns (uint256)
    {
        LoanRequest storage loanReq = loans[_borrower][_id];
        uint256 loanLTV;
        require(
            address(priceOracle) != address(0),
            "price oracle isn't initialized"
        );
        uint256 priceCollateralToken = getTokenPriceInUSD(loanReq.ctype);
        require(priceCollateralToken > 0, "ether price isn't correct");
        uint256 priceLoanToken = getTokenPriceInUSD(loanReq.mtype);
        require(priceLoanToken > 0, "token price isn't correct");
        uint256 totalLoanPrice = loanReq.paybackAmount.mul(priceLoanToken);
        uint256 totalCollateralPrice = loanReq.collateralAmount.mul(
            priceCollateralToken
        );
        if (loanReq.mtype == 2) {
            loanLTV = totalLoanPrice.wadDiv(totalCollateralPrice).mul(100).mul(
                1000000000000
            );
        } else if (loanReq.mtype == 3) {
            loanLTV = totalLoanPrice.wadDiv(totalCollateralPrice).mul(100).mul(
                1000000000000
            );
        } else if (loanReq.mtype == 4) {
            loanLTV = totalLoanPrice.wadDiv(totalCollateralPrice).mul(100).mul(
                10000000000
            );
        }
        return loanLTV;
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
            totalPrice = totalLiquidity.mul(getTokenPriceInUSD(mtype)).div(
                100000000
            );
        } else if (mtype == 2) {
            totalPrice = usdcTotalLiquidity.mul(getTokenPriceInUSD(mtype)).div(
                100000000
            );
        } else if (mtype == 3) {
            totalPrice = usdtTotalLiquidity.mul(getTokenPriceInUSD(mtype)).div(
                100000000
            );
        } else if (mtype == 4) {
            totalPrice = btcTotalLiquidity.mul(getTokenPriceInUSD(mtype)).div(
                100000000
            );
        } else if (mtype == 5) {
            totalPrice = odonTotalLiquidity.mul(odonPrice).div(100000000);
        }
        return totalPrice;
    }

    /**
     * @dev check the health of loan
     * @param _borrower the id of loan
     * @param _id the id of loan
     */
    function checkLoanHealth(address _borrower, uint256 _id)
        public
        view
        returns (bool)
    {
        bool isheath = true;

        if (getLoansLTV(_borrower, _id) >= dangerousLTV) {
            isheath = false;
        }

        return isheath;
    }

    /**
     * @dev check the expire of loan
     * @param _id the id of loan
     */
    function checkLoanExpire(address borrower, uint256 _id)
        public
        view
        returns (bool)
    {
        LoanRequest storage loanReq = loans[borrower][_id];
        bool expired = false;

        if (block.timestamp > loanReq.loanDueDate) {
            expired = true;
        }

        return expired;
    }

    /**
     * @dev Liquidate unhealthed loans and expired loans
     */

    function AutoLiquidate() external onlyOwner {
        for (uint256 i = 0; i < LoanUserList.length; i++) {
            address borrower = LoanUserList[i];
            for (uint256 j = 0; j < userLoansCount[borrower]; j++) {
                LoanRequest storage loanReq = loans[borrower][j];
                if (!loanReq.isPayback && !loanReq.isLiquidate) {
                    if (loanReq.loanDueDate < block.timestamp) {
                        loanReq.isPayback = false;
                        loanReq.isLiquidate = true;
                    } else {
                        if (checkLoanHealth(borrower, j) == false) {
                            loanReq.isPayback = false;
                            loanReq.isLiquidate = true;
                        }
                    }
                }
            }
        }

        emit Liquidate(msg.sender, block.timestamp);
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
            "withDrawEther: not enough liquidity"
        );
        address tokenAddress;
        if (mtype == 1) {
            tokenAddress = movrAddress;
        }
        if (mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (mtype == 4) {
            tokenAddress = btcAddress;
        } else if (mtype == 5) {
            tokenAddress = odonAddress;
        }

        require(
            IERC20(tokenAddress).transferFrom(
                address(this),
                msg.sender,
                _amount
            ),
            "Transaction failed on init function"
        );

        // ERC20(tokenAddress).increaseAllowance(address(this), _amount);

        if (mtype == 1) {
            totalLiquidity = totalLiquidity.sub(_amount);
        } else if (mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.sub(_amount);
        } else if (mtype == 3) {
            usdtTotalLiquidity = usdtTotalLiquidity.sub(_amount);
        } else if (mtype == 4) {
            btcTotalLiquidity = btcTotalLiquidity.sub(_amount);
        } else if (mtype == 5) {
            odonTotalLiquidity = odonTotalLiquidity.sub(_amount);
        }

        emit WithDrawReserve(_amount, mtype);
    }

    /**
     * @dev withdraw the loans
     * @param _id the id of loan
     */
    function withdraw(uint256 _id) external {
        // LendRequest memory
        LendRequest storage req = lends[msg.sender][_id];
        require(req.lendId >= 0, "withdraw: Lend request not valid");
        require(req.retrieved == false, "withdraw: Lend request retrieved");
        require(req.lender == msg.sender, "withdraw: Only lender can withdraw");
        require(
            checkEnoughLiquidity(req.lendAmount, req.mtype),
            "withdraw: not enough liquidity"
        );
        req.retrieved = true;
        if (block.timestamp > req.timeCanGetInterest) {
            address tokenAddress;
            if (req.mtype == 2) {
                tokenAddress = usdcAddress;
            } else if (req.mtype == 3) {
                tokenAddress = usdtAddress;
            } else if (req.mtype == 4) {
                tokenAddress = btcAddress;
            }
            IERC20(tokenAddress).transferFrom(
                address(this),
                req.lender,
                req.paybackAmount
            );
            if (req.mtype == 2) {
                usdcTotalLiquidity = usdcTotalLiquidity.sub(req.paybackAmount);
            } else if (req.mtype == 3) {
                usdtTotalLiquidity = usdtTotalLiquidity.sub(req.paybackAmount);
            }
            if (req.mtype == 4) {
                btcTotalLiquidity = btcTotalLiquidity.sub(req.paybackAmount);
            }
            // transfer token to lender
            emit Withdraw(true, req.paybackAmount, req.mtype);
        } else {
            address tokenAddress;
            if (req.mtype == 2) {
                tokenAddress = usdcAddress;
            } else if (req.mtype == 3) {
                tokenAddress = usdtAddress;
            } else if (req.mtype == 4) {
                tokenAddress = btcAddress;
            }
            IERC20(tokenAddress).transferFrom(
                address(this),
                req.lender,
                req.lendAmount
            );
            if (req.mtype == 2) {
                usdcTotalLiquidity = usdcTotalLiquidity.sub(req.lendAmount);
            } else if (req.mtype == 3) {
                usdtTotalLiquidity = usdtTotalLiquidity.sub(req.lendAmount);
            }
            if (req.mtype == 4) {
                btcTotalLiquidity = btcTotalLiquidity.sub(req.lendAmount);
            }
            // transfer token to lender
            emit Withdraw(false, req.lendAmount, req.mtype);
        }
    }

    /**
     * @dev paybakc the loans
     * @param _id the id of loan
     * @param _amount the amount of token
     */
    function payback(uint256 _id, uint256 _amount) external {
        LoanRequest storage loanReq = loans[msg.sender][_id];
        require(
            loanReq.borrower == msg.sender,
            "payback: Only borrower can payback"
        );
        require(!loanReq.isPayback, "payback: payback already");
        require(
            block.timestamp <= loanReq.loanDueDate,
            "payback: exceed due date"
        );
        require(
            getLoansLTV(msg.sender, _id) < dangerousLTV,
            "payback: LTV exceed dangerous LTV"
        );
        require(_amount >= loanReq.paybackAmount, "payback: Not enough token");

        require(
            checkEnoughLiquidity(loanReq.collateralAmount, loanReq.ctype),
            "payback: not enough liquidity on contract"
        );
        address tokenAddress;
        if (loanReq.mtype == 2) {
            tokenAddress = usdcAddress;
        } else if (loanReq.mtype == 3) {
            tokenAddress = usdtAddress;
        } else if (loanReq.mtype == 4) {
            tokenAddress = btcAddress;
        }
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "payback: Transfer collateral from contract to user failed"
        );
        // ERC20(tokenAddress).increaseAllowance(address(this), _amount);

        if (loanReq.mtype == 2) {
            usdcTotalLiquidity = usdcTotalLiquidity.add(_amount);
        } else if (loanReq.mtype == 3) {
            usdtTotalLiquidity = usdtTotalLiquidity.add(_amount);
        } else if (loanReq.mtype == 4) {
            btcTotalLiquidity = btcTotalLiquidity.add(_amount);
        }
        address collateralAddress;
        if (loanReq.ctype == 1) {
            collateralAddress = movrAddress;
        } else {
            collateralAddress = odonAddress;
        }
        require(
            IERC20(collateralAddress).transferFrom(
                address(this),
                msg.sender,
                loanReq.collateralAmount
            ),
            "payback: Transfer collateral from contract to user failed"
        );
        if (loanReq.ctype == 1) {
            totalLiquidity = totalLiquidity.sub(loanReq.collateralAmount);
        } else {
            odonTotalLiquidity = odonTotalLiquidity.sub(
                loanReq.collateralAmount
            );
        }

        loanReq.isPayback = true;
        loanReq.isLiquidate = false;
        emit PayBack(
            msg.sender,
            loanReq.isPayback,
            block.timestamp,
            loanReq.paybackAmount,
            loanReq.collateralAmount,
            loanReq.mtype,
            loanReq.ctype
        );
    }

    /**
     * @dev get the all loans of user
     */
    function getAllUserLoans() public view returns (LoanRequest[] memory) {
        LoanRequest[] memory requests = new LoanRequest[](
            userLoansCount[msg.sender]
        );
        for (uint256 i = 0; i < userLoansCount[msg.sender]; i++) {
            requests[i] = loans[msg.sender][i];
        }
        return requests;
    }

    /**
     * @dev get the ongoing loans of user
     */
    function getUserOngoingLoans() public view returns (LoanRequest[] memory) {
        LoanRequest[] memory ongoing = new LoanRequest[](
            userLoansCount[msg.sender]
        );
        for (uint256 i = 0; i < userLoansCount[msg.sender]; i++) {
            LoanRequest memory req = loans[msg.sender][i];
            if (
                !req.isPayback &&
                !req.isLiquidate &&
                req.loanDueDate >= block.timestamp
            ) {
                if (checkLoanHealth(msg.sender, i) == true) {
                    ongoing[i] = req;
                }
            }
        }
        return ongoing;
    }

    /**
     * @dev get the overdue loans of user
     */
    function getUserOverdueLoans(address borrower)
        public
        view
        returns (LoanRequest[] memory)
    {
        LoanRequest[] memory overdue = new LoanRequest[](
            userLoansCount[borrower]
        );
        for (uint256 i = 0; i < userLoansCount[borrower]; i++) {
            LoanRequest memory req = loans[borrower][i];
            if (!req.isPayback && req.loanDueDate < block.timestamp) {
                overdue[i] = req;
            }
        }
        return overdue;
    }

    /**
     * @dev get the unhealth loans of user
     */
    function getUserUnHealthLoans(address borrower)
        public
        view
        returns (LoanRequest[] memory)
    {
        LoanRequest[] memory unhealth = new LoanRequest[](
            userLoansCount[borrower]
        );
        for (uint256 i = 0; i < userLoansCount[borrower]; i++) {
            LoanRequest memory req = loans[borrower][i];
            if (
                !req.isPayback &&
                !req.isLiquidate &&
                req.loanDueDate >= block.timestamp
            ) {
                if (checkLoanHealth(borrower, i) == false) {
                    unhealth[i] = req;
                }
            }
        }
        return unhealth;
    }

    /**
     * @dev get the all lends of user
     */
    function getUserAllLends() public view returns (LendRequest[] memory) {
        LendRequest[] memory requests = new LendRequest[](
            userLendsCount[msg.sender]
        );
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            requests[i] = lends[msg.sender][i];
        }
        return requests;
    }

    /**
     * @dev get the lends of user that not retrieved
     */
    function getUserNotRetrieveLend()
        public
        view
        returns (LendRequest[] memory)
    {
        LendRequest[] memory notRetrieved = new LendRequest[](
            userLendsCount[msg.sender]
        );
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            LendRequest memory req = lends[msg.sender][i];
            if (!req.retrieved) {
                notRetrieved[i] = req;
            }
        }
        return notRetrieved;
    }

    /**
     * @dev set the lend apy of specific token
     * @param _usdcapy the apy of usdctoken
     * @param _usdtapy the apy of usdttoken
     * @param _btcapy the apy of btctoken
     */
    function setBorrowAPY(
        uint256 _usdcapy,
        uint256 _usdtapy,
        uint256 _btcapy
    ) external onlyOwner {
        usdcBorrowAPY = _usdcapy;
        usdtBorrowAPY = _usdtapy;
        btcBorrowAPY = _btcapy;
        emit BorrowAPYUpdated(usdcBorrowAPY, usdtBorrowAPY, btcBorrowAPY);
    }

    /**
     * @dev set the lend apy of specific token
     * @param _usdcapy the apy of usdctoken
     * @param _usdtapy the apy of usdttoken
     * @param _btcapy the apy of btctoken
     */
    function setLendAPY(
        uint256 _usdcapy,
        uint256 _usdtapy,
        uint256 _btcapy
    ) external onlyOwner {
        usdcLendAPY = _usdcapy;
        usdtLendAPY = _usdtapy;
        btcLendAPY = _btcapy;
        emit LendAPYUpdated(usdcLendAPY, usdtLendAPY, btcLendAPY);
    }

    /**
     * @dev set the lend apy of specific token
     * @param _usdcltv the ltv of usdctoken
     * @param _usdtltv the ltv of usdttoken
     * @param _btcltv the ltv of btctoken
     */
    function setStandardLTV(
        uint256 _usdcltv,
        uint256 _usdtltv,
        uint256 _btcltv
    ) external onlyOwner {
        usdcLTV = _usdcltv;
        usdtLTV = _usdtltv;
        btcLTV = _btcltv;
        emit StandardLTVUpdated(_usdcltv, _usdtltv, _btcltv);
    }

    /**
     * @dev set the price of odon
     * @param _price the price of odon
     */
    function setPriceOdon(uint256 _price) external onlyOwner {
        odonPrice = _price;
        emit OdonPriceUpdated(_price);
    }

    /**
     * @dev set the duration of loan
     * @param mtype the type of duration mode
     */
    function setLoanDurationMode(uint256 mtype) external onlyOwner {
        loanMode = mtype;
        emit LoanDurationModeUpdated(mtype);
    }
}
