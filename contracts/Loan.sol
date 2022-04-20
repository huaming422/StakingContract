// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IERC20.sol";

contract Loan {
    using SafeMath for uint256;
    address public owner;
    uint256 public loanCount;
    uint256 public lendCount;
    uint256 public totalLiquidity;
    uint256 public usdcTotalLiquidity;
    uint256 public usdtTotalLiquidity;
    uint256 public wbtcTotalLiquidity;
    address public odonAddress;
    address public usdcAddress;
    address public usdtAddress;
    address public wbtcAddress;
    uint256 public ethPerOdon = 0.0001 ether; // 0.0001 ether = 1 ODON
    uint256 public usdcPerOdon = 0.01 ether; // 0.01 usdc = 1 ODON
    uint256 public usdtPerOdon = 0.01 ether; // 0.01 usdt = 1 ODON
    uint256 public wbtcPerOdon = 0.001 ether; // 0.001 wbtc = 1 ODON

    struct LoanRequest {
        address borrower;
        uint256 loanAmountEther;
        uint256 loanAmountUsdc;
        uint256 loanAmountUsdt;
        uint256 loanAmountWbtc;
        uint256 collateralAmount;
        uint256 paybackAmountEther;
        uint256 paybackAmountUsdc;
        uint256 paybackAmountUsdt;
        uint256 paybackAmountWbtc;
        uint256 loanDueDate;
        uint256 duration;
        uint256 loanId;
        bool isPayback;
        bool isLoanEther;
        bool isLoanUsdc;
        bool isLoanUsdt;
        bool isLoanWbtc;
    }

    struct LendRequest {
        address lender;
        uint256 lendId;
        uint256 lendAmountEther;
        uint256 lendAmountUsdc;
        uint256 lendAmountUsdt;
        uint256 lendAmountWbtc;
        uint256 paybackAmountEther;
        uint256 paybackAmountUsdc;
        uint256 paybackAmountUsdt;
        uint256 paybackAmountWbtc;
        uint256 timeLend;
        uint256 timeCanGetInterest; // lend more than 30 days can get interest
        bool retrieved;
        bool isLendEther;
        bool isLendUsdc;
        bool isLendUsdt;
        bool isLendWbtc;
    }

    mapping(address => uint256) public userLoansCount;
    mapping(address => uint256) public userLendsCount;
    mapping(address => mapping(uint256 => LoanRequest)) public loans;
    mapping(address => mapping(uint256 => LendRequest)) public lends;

    event NewLoan(
        address indexed borrower,
        uint256 loanAmountEther,
        uint256 loanAmountUsdc,
        uint256 loanAmountUsdt,
        uint256 loanAmountWbtc,
        uint256 collateralAmount,
        uint256 paybackAmountEther,
        uint256 paybackAmountUsdc,
        uint256 paybackAmountUsdt,
        uint256 paybackAmountWbtc,
        uint256 loanDueDate,
        uint256 duration,
        bool isLoanEther,
        bool isLoanUsdc,
        bool isLoanUsdt,
        bool isLoanWbtc
    );

    event NewLend(
        address indexed lender,
        uint256 lendAmountEther,
        uint256 lendAmountUsdc,
        uint256 lendAmountUsdt,
        uint256 lendAmountWbtc,
        uint256 paybackAmountEther,
        uint256 paybackAmountUsdc,
        uint256 paybackAmountUsdt,
        uint256 paybackAmountWbtc,
        uint256 timeLend,
        uint256 timeCanGetInterest,
        bool retrieved,
        bool isLendEther,
        bool isLendUsdc,
        bool isLendUsdt,
        bool isLendWbtc
    );

    event Withdraw(
        bool isEarnInterest,
        bool isWithdrawEther,
        bool isWithdrawUsdc,
        bool isWithdrawUsdt,
        bool isWithdrawWbtc,
        uint256 withdrawAmount
    );

    event PayBack(
        address borrower,
        bool paybackSuccess,
        bool isPayBackEther,
        bool isPayBackUsdc,
        bool isPayBackUsdt,
        bool isPayBackWbtc,
        uint256 paybackTime,
        uint256 paybackAmount,
        uint256 returnCollateralAmount
    );

    constructor(
        address _odonAddress,
        address _usdcAddress,
        address _usdtAddress,
        address _wbtcAddress
    ) {
        owner = msg.sender;
        loanCount = 1;
        lendCount = 1;
        totalLiquidity = 0;
        usdcTotalLiquidity = 0;
        usdtTotalLiquidity = 0;
        wbtcTotalLiquidity = 0;
        odonAddress = _odonAddress;
        usdcAddress = _usdcAddress;
        usdtAddress = _usdtAddress;
        wbtcAddress = _wbtcAddress;
    }

    function init(uint256 _amount) public payable {
        require(totalLiquidity == 0);
        require(usdcTotalLiquidity == 0);
        require(usdtTotalLiquidity == 0);
        require(wbtcTotalLiquidity == 0);
        require(
            IERC20(odonAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        require(
            IERC20(usdcAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        require(
            IERC20(usdtAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        require(
            IERC20(wbtcAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transaction failed on init function"
        );
        IERC20(odonAddress).increaseAllowance(address(this), _amount);
        IERC20(usdcAddress).increaseAllowance(address(this), _amount);
        IERC20(usdtAddress).increaseAllowance(address(this), _amount);
        IERC20(wbtcAddress).increaseAllowance(address(this), _amount);
        totalLiquidity = address(this).balance;
    }

    // count require odon amount by passing ether amount
    function etherCollateralAmount(uint256 _amount)
        public
        view
        returns (uint256)
    {
        // collateral amount = loan amount * 115%
        uint256 result = _amount.mul(115).div(100);
        result = result.div(ethPerOdon);
        return result;
    }

    // count require odon amount by passing usdc amount
    function usdcCollateralAmount(uint256 _amount)
        public
        view
        returns (uint256)
    {
        // collateral amount = loan amount * 115%
        uint256 result = _amount.mul(115).div(100);
        result = result.div(usdcPerOdon);
        return result;
    }

    // count require odon amount by passing wbtc amount
    function wbtcCollateralAmount(uint256 _amount)
        public
        view
        returns (uint256)
    {
        // collateral amount = loan amount * 115%
        uint256 result = _amount.mul(115).div(100);
        result = result.div(wbtcPerOdon);
        return result;
    }

    // count require odon amount by passing usdt amount
    function usdtCollateralAmount(uint256 _amount)
        public
        view
        returns (uint256)
    {
        // collateral amount = loan amount * 115%
        uint256 result = _amount.mul(115).div(100);
        result = result.div(usdtPerOdon);
        return result;
    }

    // count ether amount by passing collateral amount
    function countEtherFromCollateral(uint256 _tokenAmount)
        public
        view
        returns (uint256)
    {
        // collateral amount / 115 % = loan amount
        uint256 result = (_tokenAmount.mul(ethPerOdon)).div(115).mul(100);
        return result;
    }

    // count usdc amount by passing collateral amount
    function countUsdcFromCollateral(uint256 _tokenAmount)
        public
        view
        returns (uint256)
    {
        // collateral amount / 115 % = loan amount
        uint256 result = (_tokenAmount.mul(usdcPerOdon)).div(115).mul(100);
        return result;
    }

    // count usdt amount by passing collateral amount
    function countUsdtFromCollateral(uint256 _tokenAmount)
        public
        view
        returns (uint256)
    {
        // collateral amount / 115 % = loan amount
        uint256 result = (_tokenAmount.mul(usdtPerOdon)).div(115).mul(100);
        return result;
    }

    // count wbtc amount by passing collateral amount
    function countWbtcFromCollateral(uint256 _tokenAmount)
        public
        view
        returns (uint256)
    {
        // collateral amount / 115 % = loan amount
        uint256 result = (_tokenAmount.mul(wbtcPerOdon)).div(115).mul(100);
        return result;
    }

    function checkEtherEnoughLiquidity(uint256 _amount)
        public
        view
        returns (bool)
    {
        if (_amount > totalLiquidity) {
            return false;
        } else {
            return true;
        }
    }

    function checkUsdcEnoughLiquidity(uint256 _amount)
        public
        view
        returns (bool)
    {
        if (_amount > usdcTotalLiquidity) {
            return false;
        } else {
            return true;
        }
    }

    function checkUsdtEnoughLiquidity(uint256 _amount)
        public
        view
        returns (bool)
    {
        if (_amount > usdtTotalLiquidity) {
            return false;
        } else {
            return true;
        }
    }

    function checkWbtcEnoughLiquidity(uint256 _amount)
        public
        view
        returns (bool)
    {
        if (_amount > wbtcTotalLiquidity) {
            return false;
        } else {
            return true;
        }
    }

    function loanEther(uint256 _amount, uint256 _duration) public {
        require(
            _amount >= ethPerOdon,
            "loanEther: Not enough fund in order to loan"
        );
        require(
            checkEtherEnoughLiquidity(_amount),
            "loanEther: not enough liquidity"
        );
        LoanRequest memory newLoan;
        newLoan.borrower = msg.sender;
        newLoan.loanAmountEther = _amount;
        newLoan.loanAmountUsdc = 0;
        newLoan.loanAmountUsdt = 0;
        newLoan.loanAmountWbtc = 0;
        newLoan.collateralAmount = etherCollateralAmount(_amount) * (10**18);
        newLoan.loanId = userLoansCount[msg.sender];
        newLoan.isPayback = false;
        newLoan.isLoanEther = true;
        newLoan.isLoanUsdc = false;
        newLoan.isLoanUsdt = false;
        newLoan.isLoanWbtc = false;

        if (_duration == 7) {
            // 6% interest
            newLoan.paybackAmountEther = _amount.mul(106).div(100);
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 7 days;
            newLoan.duration = 7 days;
        } else if (_duration == 14) {
            // 7% interest
            newLoan.paybackAmountEther = _amount.mul(107).div(100);
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 14 days;
            newLoan.duration = 14 days;
        } else if (_duration == 30) {
            // 8% interest
            newLoan.paybackAmountEther = _amount.mul(108).div(100);
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 30 days;
            newLoan.duration = 30 days;
        } else {
            revert("loanEther: no valid duration!");
        }
        require(
            IERC20(odonAddress).transferFrom(
                msg.sender,
                address(this),
                newLoan.collateralAmount
            ),
            "loanEther: Transfer token from user to contract failed"
        );
        payable(msg.sender).transfer(_amount);
        IERC20(odonAddress).increaseAllowance(
            address(this),
            newLoan.collateralAmount
        );
        loans[msg.sender][userLoansCount[msg.sender]] = newLoan;
        loanCount++;
        userLoansCount[msg.sender]++;
        totalLiquidity = totalLiquidity.sub(_amount);
        emit NewLoan(
            msg.sender,
            newLoan.loanAmountEther,
            newLoan.loanAmountUsdc,
            newLoan.loanAmountUsdt,
            newLoan.loanAmountWbtc,
            newLoan.collateralAmount,
            newLoan.paybackAmountEther,
            newLoan.paybackAmountUsdc,
            newLoan.paybackAmountUsdt,
            newLoan.paybackAmountWbtc,
            newLoan.loanDueDate,
            newLoan.duration,
            newLoan.isLoanEther,
            newLoan.isLoanUsdc,
            newLoan.isLoanUsdt,
            newLoan.isLoanWbtc
        );
    }

    function loanUsdc(uint256 _amount, uint256 _duration) public {
        require(
            _amount >= usdcPerOdon,
            "loanUsdc: Not enough fund in order to loan"
        );
        require(
            checkUsdcEnoughLiquidity(_amount),
            "loanUsdc: not enough liquidity"
        );
        LoanRequest memory newLoan;
        newLoan.borrower = msg.sender;
        newLoan.loanAmountEther = 0;
        newLoan.loanAmountUsdc = _amount;
        newLoan.loanAmountUsdt = 0;
        newLoan.loanAmountWbtc = 0;
        newLoan.collateralAmount = usdcCollateralAmount(_amount) * (10**18);
        newLoan.loanId = userLoansCount[msg.sender];
        newLoan.isPayback = false;
        newLoan.isLoanEther = false;
        newLoan.isLoanUsdc = true;
        newLoan.isLoanUsdt = false;
        newLoan.isLoanWbtc = false;

        if (_duration == 7) {
            // 6% interest
            newLoan.paybackAmountUsdc = _amount.mul(106).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 7 days;
            newLoan.duration = 7 days;
        } else if (_duration == 14) {
            // 7% interest
            newLoan.paybackAmountUsdc = _amount.mul(107).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 14 days;
            newLoan.duration = 14 days;
        } else if (_duration == 30) {
            // 8% interest
            newLoan.paybackAmountUsdc = _amount.mul(108).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 30 days;
            newLoan.duration = 30 days;
        } else {
            revert("loanUsdc: no valid duration!");
        }
        require(
            IERC20(odonAddress).transferFrom(
                msg.sender,
                address(this),
                newLoan.collateralAmount
            ),
            "loanUsdc: Transfer token from user to contract failed"
        );
        require(
            IERC20(usdcAddress).transferFrom(
                address(this),
                msg.sender,
                _amount
            ),
            "loanUsdc: Transfer token from contract to user failed"
        );
        IERC20(usdcAddress).increaseAllowance(msg.sender, _amount);
        IERC20(odonAddress).increaseAllowance(
            address(this),
            newLoan.collateralAmount
        );
        loans[msg.sender][userLoansCount[msg.sender]] = newLoan;
        loanCount++;
        userLoansCount[msg.sender]++;
        totalLiquidity = totalLiquidity.sub(_amount);
        emit NewLoan(
            msg.sender,
            newLoan.loanAmountEther,
            newLoan.loanAmountUsdc,
            newLoan.loanAmountUsdt,
            newLoan.loanAmountWbtc,
            newLoan.collateralAmount,
            newLoan.paybackAmountEther,
            newLoan.paybackAmountUsdc,
            newLoan.paybackAmountUsdt,
            newLoan.paybackAmountWbtc,
            newLoan.loanDueDate,
            newLoan.duration,
            newLoan.isLoanEther,
            newLoan.isLoanUsdc,
            newLoan.isLoanUsdt,
            newLoan.isLoanWbtc
        );
    }

    function loanUsdt(uint256 _amount, uint256 _duration) public {
        require(
            _amount >= usdtPerOdon,
            "loanUsdt: Not enough fund in order to loan"
        );
        require(
            checkUsdtEnoughLiquidity(_amount),
            "loanUsdt: not enough liquidity"
        );
        LoanRequest memory newLoan;
        newLoan.borrower = msg.sender;
        newLoan.loanAmountEther = 0;
        newLoan.loanAmountUsdt = _amount;
        newLoan.loanAmountUsdc = 0;
        newLoan.loanAmountWbtc = 0;
        newLoan.collateralAmount = usdcCollateralAmount(_amount) * (10**18);
        newLoan.loanId = userLoansCount[msg.sender];
        newLoan.isPayback = false;
        newLoan.isLoanEther = false;
        newLoan.isLoanUsdt = true;
        newLoan.isLoanUsdc = false;
        newLoan.isLoanWbtc = false;

        if (_duration == 7) {
            // 6% interest
            newLoan.paybackAmountUsdt = _amount.mul(106).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 7 days;
            newLoan.duration = 7 days;
        } else if (_duration == 14) {
            // 7% interest
            newLoan.paybackAmountUsdt = _amount.mul(107).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 14 days;
            newLoan.duration = 14 days;
        } else if (_duration == 30) {
            // 8% interest
            newLoan.paybackAmountUsdt = _amount.mul(108).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountWbtc = 0;
            newLoan.loanDueDate = block.timestamp + 30 days;
            newLoan.duration = 30 days;
        } else {
            revert("loanUsdt: no valid duration!");
        }
        require(
            IERC20(odonAddress).transferFrom(
                msg.sender,
                address(this),
                newLoan.collateralAmount
            ),
            "loanUsdc: Transfer token from user to contract failed"
        );
        require(
            IERC20(usdtAddress).transferFrom(
                address(this),
                msg.sender,
                _amount
            ),
            "loanUsdt: Transfer token from contract to user failed"
        );
        IERC20(usdtAddress).increaseAllowance(msg.sender, _amount);
        IERC20(odonAddress).increaseAllowance(
            address(this),
            newLoan.collateralAmount
        );
        loans[msg.sender][userLoansCount[msg.sender]] = newLoan;
        loanCount++;
        userLoansCount[msg.sender]++;
        totalLiquidity = totalLiquidity.sub(_amount);
        emit NewLoan(
            msg.sender,
            newLoan.loanAmountEther,
            newLoan.loanAmountUsdc,
            newLoan.loanAmountUsdt,
            newLoan.loanAmountWbtc,
            newLoan.collateralAmount,
            newLoan.paybackAmountEther,
            newLoan.paybackAmountUsdc,
            newLoan.paybackAmountUsdt,
            newLoan.paybackAmountWbtc,
            newLoan.loanDueDate,
            newLoan.duration,
            newLoan.isLoanEther,
            newLoan.isLoanUsdc,
            newLoan.isLoanUsdt,
            newLoan.isLoanWbtc
        );
    }

    function loanWbtc(uint256 _amount, uint256 _duration) public {
        require(
            _amount >= wbtcPerOdon,
            "loanWbtc: Not enough fund in order to loan"
        );
        require(
            checkUsdtEnoughLiquidity(_amount),
            "loanWbtc: not enough liquidity"
        );
        LoanRequest memory newLoan;
        newLoan.borrower = msg.sender;
        newLoan.loanAmountEther = 0;
        newLoan.loanAmountUsdt = 0;
        newLoan.loanAmountUsdc = 0;
        newLoan.loanAmountWbtc = _amount;
        newLoan.collateralAmount = usdcCollateralAmount(_amount) * (10**18);
        newLoan.loanId = userLoansCount[msg.sender];
        newLoan.isPayback = false;
        newLoan.isLoanEther = false;
        newLoan.isLoanUsdt = false;
        newLoan.isLoanUsdc = false;
        newLoan.isLoanWbtc = true;

        if (_duration == 7) {
            // 6% interest
            newLoan.paybackAmountWbtc = _amount.mul(106).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.loanDueDate = block.timestamp + 7 days;
            newLoan.duration = 7 days;
        } else if (_duration == 14) {
            // 7% interest
            newLoan.paybackAmountWbtc = _amount.mul(107).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.loanDueDate = block.timestamp + 14 days;
            newLoan.duration = 14 days;
        } else if (_duration == 30) {
            // 8% interest
            newLoan.paybackAmountWbtc = _amount.mul(108).div(100);
            newLoan.paybackAmountEther = 0;
            newLoan.paybackAmountUsdc = 0;
            newLoan.paybackAmountUsdt = 0;
            newLoan.loanDueDate = block.timestamp + 30 days;
            newLoan.duration = 30 days;
        } else {
            revert("loanWbtc: no valid duration!");
        }
        require(
            IERC20(odonAddress).transferFrom(
                msg.sender,
                address(this),
                newLoan.collateralAmount
            ),
            "loanWbtc: Transfer token from user to contract failed"
        );
        require(
            IERC20(usdtAddress).transferFrom(
                address(this),
                msg.sender,
                _amount
            ),
            "loanWbtc: Transfer token from contract to user failed"
        );
        IERC20(wbtcAddress).increaseAllowance(msg.sender, _amount);
        IERC20(odonAddress).increaseAllowance(
            address(this),
            newLoan.collateralAmount
        );
        loans[msg.sender][userLoansCount[msg.sender]] = newLoan;
        loanCount++;
        userLoansCount[msg.sender]++;
        totalLiquidity = totalLiquidity.sub(_amount);
        emit NewLoan(
            msg.sender,
            newLoan.loanAmountEther,
            newLoan.loanAmountUsdc,
            newLoan.loanAmountUsdt,
            newLoan.loanAmountWbtc,
            newLoan.collateralAmount,
            newLoan.paybackAmountEther,
            newLoan.paybackAmountUsdc,
            newLoan.paybackAmountUsdt,
            newLoan.paybackAmountWbtc,
            newLoan.loanDueDate,
            newLoan.duration,
            newLoan.isLoanEther,
            newLoan.isLoanUsdc,
            newLoan.isLoanUsdt,
            newLoan.isLoanWbtc
        );
    }

    function lendEther() public payable {
        require(msg.value >= 0.0001 ether);
        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmountEther = msg.value;
        request.lendAmountUsdc = 0;
        request.lendAmountUsdt = 0;
        request.lendAmountWbtc = 0;
        // 5% interest
        request.paybackAmountEther = msg.value.mul(105).div(100);
        request.paybackAmountUsdc = 0;
        request.paybackAmountUsdt = 0;
        request.paybackAmountWbtc = 0;
        request.timeLend = block.timestamp;
        request.timeCanGetInterest = block.timestamp + 30 days;
        request.retrieved = false;
        request.isLendEther = true;
        request.isLendUsdc = false;
        request.isLendUsdt = false;
        request.isLendWbtc = false;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;
        totalLiquidity = totalLiquidity.add(msg.value);
        emit NewLend(
            request.lender,
            request.lendAmountEther,
            request.lendAmountUsdc,
            request.lendAmountUsdt,
            request.lendAmountWbtc,
            request.paybackAmountEther,
            request.paybackAmountUsdc,
            request.paybackAmountUsdt,
            request.paybackAmountWbtc,
            request.timeLend,
            request.timeCanGetInterest,
            request.retrieved,
            request.isLendEther,
            request.isLendUsdc,
            request.isLendUsdt,
            request.isLendWbtc
        );
    }

    function lendUsdc(uint256 _amount) public {
        require(
            IERC20(usdcAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "lendUsdc: Transfer token from user to contract failed"
        );
        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmountEther = 0;
        request.lendAmountUsdc = _amount;
        request.lendAmountUsdt = 0;
        request.lendAmountWbtc = 0;
        // 5% interest
        request.paybackAmountEther = 0;
        request.paybackAmountWbtc = 0;
        request.paybackAmountUsdt = 0;
        request.paybackAmountUsdc = _amount.mul(105).div(100);
        request.timeLend = block.timestamp;
        request.timeCanGetInterest = block.timestamp + 30 days;
        request.retrieved = false;
        request.isLendEther = false;
        request.isLendUsdc = true;
        request.isLendUsdt = false;
        request.isLendWbtc = false;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;
        IERC20(usdcAddress).increaseAllowance(
            address(this),
            request.paybackAmountUsdc
        );
        emit NewLend(
            request.lender,
            request.lendAmountEther,
            request.lendAmountUsdc,
            request.lendAmountUsdt,
            request.lendAmountWbtc,
            request.paybackAmountEther,
            request.paybackAmountUsdc,
            request.paybackAmountUsdt,
            request.paybackAmountWbtc,
            request.timeLend,
            request.timeCanGetInterest,
            request.retrieved,
            request.isLendEther,
            request.isLendUsdc,
            request.isLendUsdt,
            request.isLendWbtc
        );
    }

    function lendUsdt(uint256 _amount) public {
        require(
            IERC20(usdtAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "lendUsdc: Transfer token from user to contract failed"
        );
        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmountEther = 0;
        request.lendAmountUsdt = _amount;
        request.lendAmountUsdc = 0;
        request.lendAmountWbtc = 0;
        // 5% interest
        request.paybackAmountEther = 0;
        request.paybackAmountWbtc = 0;
        request.paybackAmountUsdc = 0;
        request.paybackAmountUsdt = _amount.mul(105).div(100);
        request.timeLend = block.timestamp;
        request.timeCanGetInterest = block.timestamp + 30 days;
        request.retrieved = false;
        request.isLendEther = false;
        request.isLendUsdc = false;
        request.isLendUsdt = true;
        request.isLendWbtc = false;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;
        IERC20(usdtAddress).increaseAllowance(
            address(this),
            request.paybackAmountUsdt
        );
        emit NewLend(
            request.lender,
            request.lendAmountEther,
            request.lendAmountUsdc,
            request.lendAmountUsdt,
            request.lendAmountWbtc,
            request.paybackAmountEther,
            request.paybackAmountUsdc,
            request.paybackAmountUsdt,
            request.paybackAmountWbtc,
            request.timeLend,
            request.timeCanGetInterest,
            request.retrieved,
            request.isLendEther,
            request.isLendUsdc,
            request.isLendUsdt,
            request.isLendWbtc
        );
    }

    function lendWbtc(uint256 _amount) public {
        require(
            IERC20(wbtcAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "lendUsdc: Transfer token from user to contract failed"
        );
        LendRequest memory request;
        request.lender = msg.sender;
        request.lendId = userLendsCount[msg.sender];
        request.lendAmountEther = 0;
        request.lendAmountWbtc = _amount;
        request.lendAmountUsdt = 0;
        request.lendAmountUsdc = 0;
        // 5% interest
        request.paybackAmountEther = 0;
        request.paybackAmountUsdc = 0;
        request.paybackAmountUsdt = 0;
        request.paybackAmountWbtc = _amount.mul(105).div(100);
        request.timeLend = block.timestamp;
        request.timeCanGetInterest = block.timestamp + 30 days;
        request.retrieved = false;
        request.isLendEther = false;
        request.isLendUsdc = false;
        request.isLendUsdt = false;
        request.isLendWbtc = true;
        lends[msg.sender][userLendsCount[msg.sender]] = request;
        lendCount++;
        userLendsCount[msg.sender]++;
        IERC20(wbtcAddress).increaseAllowance(
            address(this),
            request.paybackAmountWbtc
        );
        emit NewLend(
            request.lender,
            request.lendAmountEther,
            request.lendAmountUsdc,
            request.lendAmountUsdt,
            request.lendAmountWbtc,
            request.paybackAmountEther,
            request.paybackAmountUsdc,
            request.paybackAmountUsdt,
            request.paybackAmountWbtc,
            request.timeLend,
            request.timeCanGetInterest,
            request.retrieved,
            request.isLendEther,
            request.isLendUsdc,
            request.isLendUsdt,
            request.isLendWbtc
        );
    }

    function withdraw(uint256 _id) public {
        // LendRequest memory
        LendRequest storage req = lends[msg.sender][_id];
        require(req.lendId >= 0, "withdrawEther: Lend request not valid");
        require(
            req.retrieved == false,
            "withdrawEther: Lend request retrieved"
        );
        require(
            req.lender == msg.sender,
            "withdrawEther: Only lender can withdraw"
        );
        req.retrieved = true;
        if (block.timestamp > req.timeCanGetInterest) {
            // can get interest
            if (req.isLendEther) {
                // transfer ether to lender
                payable(req.lender).transfer(req.paybackAmountEther);
                emit Withdraw(
                    true,
                    true,
                    false,
                    false,
                    false,
                    req.paybackAmountEther
                );
            } else if (req.isLendUsdc) {
                // transfer token to lender
                IERC20(usdcAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.paybackAmountUsdc
                );
                emit Withdraw(
                    true,
                    false,
                    true,
                    false,
                    false,
                    req.paybackAmountUsdc
                );
            } else if (req.isLendUsdt) {
                // transfer token to lender
                IERC20(usdtAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.paybackAmountUsdt
                );
                emit Withdraw(
                    true,
                    false,
                    false,
                    true,
                    false,
                    req.paybackAmountUsdt
                );
            } else if (req.isLendWbtc) {
                // transfer token to lender
                IERC20(wbtcAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.paybackAmountWbtc
                );
                emit Withdraw(
                    true,
                    false,
                    false,
                    false,
                    true,
                    req.paybackAmountWbtc
                );
            }
        } else {
            // transfer the original amount
            if (req.isLendEther) {
                // transfer ether to lender
                payable(req.lender).transfer(req.lendAmountEther);
                emit Withdraw(
                    false,
                    true,
                    false,
                    false,
                    false,
                    req.lendAmountEther
                );
            } else if (req.isLendUsdc) {
                // transfer token to lender
                IERC20(usdcAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.lendAmountUsdc
                );
                emit Withdraw(
                    false,
                    false,
                    true,
                    false,
                    false,
                    req.lendAmountUsdc
                );
            } else if (req.isLendUsdt) {
                // transfer token to lender
                IERC20(usdtAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.lendAmountUsdt
                );
                emit Withdraw(
                    false,
                    false,
                    false,
                    true,
                    false,
                    req.lendAmountUsdt
                );
            } else if (req.isLendWbtc) {
                // transfer token to lender
                IERC20(wbtcAddress).transferFrom(
                    address(this),
                    req.lender,
                    req.lendAmountWbtc
                );
                emit Withdraw(
                    false,
                    false,
                    false,
                    false,
                    true,
                    req.lendAmountUsdt
                );
            }
        }
    }

    function payback(uint256 _id) public payable {
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
        if (loanReq.isLoanEther) {
            require(
                msg.value >= loanReq.paybackAmountEther,
                "payback: Not enough ether"
            );
            require(
                IERC20(odonAddress).transferFrom(
                    address(this),
                    msg.sender,
                    loanReq.collateralAmount
                ),
                "payback: Transfer collateral from contract to user failed"
            );

            payable(address(this)).transfer(msg.value);
            loanReq.isPayback = true;
            emit PayBack(
                msg.sender,
                loanReq.isPayback,
                true,
                false,
                false,
                false,
                block.timestamp,
                loanReq.paybackAmountEther,
                loanReq.collateralAmount
            );
        }
        else if (loanReq.isLoanUsdc) {
            require(
                msg.value >= loanReq.paybackAmountUsdc,
                "payback: Not enough usdc"
            );
            require(
                IERC20(odonAddress).transferFrom(
                    address(this),
                    msg.sender,
                    loanReq.collateralAmount
                ),
                "payback: Transfer collateral from contract to user failed"
            );

            payable(address(this)).transfer(msg.value);
            loanReq.isPayback = true;
            emit PayBack(
                msg.sender,
                loanReq.isPayback,
                false,
                true,
                false,
                false,
                block.timestamp,
                loanReq.paybackAmountEther,
                loanReq.collateralAmount
            );
        }
        else if (loanReq.isLoanUsdt) {
            require(
                msg.value >= loanReq.paybackAmountUsdt,
                "payback: Not enough usdt"
            );
            require(
                IERC20(odonAddress).transferFrom(
                    address(this),
                    msg.sender,
                    loanReq.collateralAmount
                ),
                "payback: Transfer collateral from contract to user failed"
            );

            payable(address(this)).transfer(msg.value);
            loanReq.isPayback = true;
            emit PayBack(
                msg.sender,
                loanReq.isPayback,
                false,
                false,
                true,
                false,
                block.timestamp,
                loanReq.paybackAmountEther,
                loanReq.collateralAmount
            );
        }
        else if (loanReq.isLoanWbtc) {
            require(
                msg.value >= loanReq.paybackAmountUsdt,
                "payback: Not enough wbtc"
            );
            require(
                IERC20(odonAddress).transferFrom(
                    address(this),
                    msg.sender,
                    loanReq.collateralAmount
                ),
                "payback: Transfer collateral from contract to user failed"
            );

            payable(address(this)).transfer(msg.value);
            loanReq.isPayback = true;
            emit PayBack(
                msg.sender,
                loanReq.isPayback,
                false,
                false,
                false,
                true,
                block.timestamp,
                loanReq.paybackAmountEther,
                loanReq.collateralAmount
            );
        }
    }

    function getAllUserLoans() public view returns (LoanRequest[] memory) {
        LoanRequest[] memory requests = new LoanRequest[](
            userLoansCount[msg.sender]
        );
        for (uint256 i = 0; i < userLoansCount[msg.sender]; i++) {
            requests[i] = loans[msg.sender][i];
        }
        return requests;
    }

    function getUserOngoingLoans() public view returns (LoanRequest[] memory) {
        LoanRequest[] memory ongoing = new LoanRequest[](
            userLoansCount[msg.sender]
        );
        for (uint256 i = 0; i < userLoansCount[msg.sender]; i++) {
            LoanRequest memory req = loans[msg.sender][i];
            if (!req.isPayback && req.loanDueDate > block.timestamp) {
                ongoing[i] = req;
            }
        }
        return ongoing;
    }

    function getUserOverdueLoans() public view returns (LoanRequest[] memory) {
        LoanRequest[] memory overdue = new LoanRequest[](
            userLoansCount[msg.sender]
        );
        for (uint256 i = 0; i < userLoansCount[msg.sender]; i++) {
            LoanRequest memory req = loans[msg.sender][i];
            if (!req.isPayback && req.loanDueDate < block.timestamp) {
                overdue[i] = req;
            }
        }
        return overdue;
    }

    function getUserAllLends() public view returns (LendRequest[] memory) {
        LendRequest[] memory requests = new LendRequest[](
            userLendsCount[msg.sender]
        );
        for (uint256 i = 0; i < userLendsCount[msg.sender]; i++) {
            requests[i] = lends[msg.sender][i];
        }
        return requests;
    }

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
}
