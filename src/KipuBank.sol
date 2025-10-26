// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title KipuBankV2
/// @author Lucas Zunino
/// @notice decentralized bank contract with multi-token support and USD conversion
/// @notice this is a v2 version of KipuBank
/// @dev Manages ETH and ERC-20 tokens (USDC, DAI, BNB) with USD conversion via Chainlink
contract KipuBankV2 is Ownable {
    using SafeERC20 for IERC20;

    // °°°°°°°°°°°°°°°°°° STRUCTURES °°°°°°°°°°°°°°°°°°
    
    /// @notice structure to store user balances
    struct UserBalance {
        mapping(address => uint256) balances;
    }

    /// @notice structure to store information about tokens
    struct TokenInfo {
        address priceFeed;
        address tokenAddress;
        uint8 decimals;
        bool isActive;
    }

    // °°°°°°°°°°°°°°°°°° INMUTABLE VARIABLES °°°°°°°°°°°°°°°°°°
    
    /// @notice Adress to represent native ETH
    address public constant ETH_ADDRESS = address(0);

    /// @notice max bank capacity in USD
    uint256 public immutable BANK_CAPACITY_USD;

    /// @notice limit withdrawal
    uint256 public immutable WITHDRAWAL_LIMIT;
    

    // °°°°°°°°°°°°°°°°°° CONSTANT VARIABLES °°°°°°°°°°°°°°°°°°
    
    /// @notice Decimales estándar para contabilidad interna 
    uint8 public constant INTERNAL_DECIMALS = 6;
    
    /// @notice Escala para conversión de decimales
    uint256 public constant SCALE = 10 ** 18;


    // °°°°°°°°°°°°°°°°°° STATE VARIABLES °°°°°°°°°°°°°°°°°°
    
    /// @notice Mapeo anidado de balances por usuario y token
    mapping(address => UserBalance) private userBalances;
    
    /// @notice Mapping supported tokens
    mapping(address => TokenInfo) public supportedTokens;
    
    /// @notice deposit counter for user and token
    mapping(address => mapping(address => uint256)) public depositCount;
    
    /// @notice withdrawal counter for user and token
    mapping(address => mapping(address => uint256)) public withdrawalCount;
    
    /// @notice Total deposited in USD
    uint256 public totalDepositedUSD;
    
    /// @notice address price feed ETH/USD
    AggregatorV3Interface public ethPriceFeed;
    
    /// @notice List of active token addresses 
    address[] public activeTokens;
    
    /// @notice Mapping of admin roles
    mapping(address => bool) public admins;

    // °°°°°°°°°°°°°°°°°° EVENTS °°°°°°°°°°°°°°°°°°
    
    /// @notice emit when a new supported token is added
    /// @param token token address
    /// @param priceFeed Chainlink price feed address
    /// @param decimals token decimals
    event TokenAdded(address indexed token, address indexed priceFeed, uint8 decimals);

    /// @notice emit when a token is deactivated
    /// @param token token address
    event TokenRemoved(address indexed token);

    /// @notice emit when an admin role is assigned
    /// @param admin new admin address
    event AdminAdded(address indexed admin);

    /// @notice emit when an admin role is revoked
    /// @param admin admin address
    event AdminRemoved(address indexed admin);

    /// @notice emit with any user deposits
    /// @param user user address
    /// @param token token address (address(0) for ETH)
    /// @param amount amount in native tokens
    /// @param amountUSD equivalent in USD
    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUSD
    );

    /// @notice emit with any user withdrawals
    /// @param user user address
    /// @param token token address (address(0) for ETH)
    /// @param amount amount in native tokens
    /// @param amountUSD equivalent in USD
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUSD
    );



    // °°°°°°°°°°°°°°°°°° ERRORES °°°°°°°°°°°°°°°°°°
    error InvalidPriceFeed();
    error InvalidAmount();
    error InvalidDecimals();
    error UnauthorizedAccess();
    error WithdrawalLimitExceeded(uint256 requested, uint256 limit);
    error BankCapacityExceeded(uint256 totalUSD, uint256 capacity);
    error TokenNotSupported(address token);
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidTokenAddress();
    error TransferFailed();
    error TokenAlreadyAdded();
    error PriceFeedError();

    // °°°°°°°°°°°°°°°°°° MODIFIERS °°°°°°°°°°°°°°°°°°
    
    /// @notice only owner or admin call this function
    modifier onlyAuthorized() {
        if (msg.sender != owner() && !admins[msg.sender]) {
            revert UnauthorizedAccess();
        }
        _;
    }

    /// @notice amount must be greater than zero
    /// @param amount amount to validate
    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _;
    }

    /// @notice token must be supported
    /// @param token token address
    modifier tokenExists(address token) {
        if (!supportedTokens[token].isActive) {
            revert TokenNotSupported(token);
        }
        _;
    }

    // °°°°°°°°°°°°°°°°°° CONSTRUCTOR °°°°°°°°°°°°°°°°°°

    /// @notice Initializes the contract with base parameters
    /// @param _withdrawalLimitUSD Withdrawal limit in USD
    /// @param _bankCapacityUSD Bank capacity in USD
    /// @param _ethPriceFeed Chainlink ETH/USD price feed address
    /// @dev I use the constructor in your github repositories :)
    constructor(
        uint256 _withdrawalLimitUSD,
        uint256 _bankCapacityUSD,
        address _ethPriceFeed
    ) Ownable(msg.sender) {
        if (_ethPriceFeed == address(0)) revert InvalidPriceFeed();
        if (_withdrawalLimitUSD == 0 || _bankCapacityUSD == 0) revert InvalidAmount();
        if (_bankCapacityUSD < _withdrawalLimitUSD) revert BankCapacityExceeded(_withdrawalLimitUSD, _bankCapacityUSD);

        WITHDRAWAL_LIMIT = _withdrawalLimitUSD;
        BANK_CAPACITY_USD = _bankCapacityUSD;
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);

        // Add ETH as a supported token
        supportedTokens[ETH_ADDRESS] = TokenInfo({
            tokenAddress: ETH_ADDRESS,
            priceFeed: _ethPriceFeed,
            decimals: 18,
            isActive: true
        });

        activeTokens.push(ETH_ADDRESS);
        admins[msg.sender] = true;
    }

    // °°°°°°°°°°°°°°°°°° ADMIN FUNCTIONS °°°°°°°°°°°°°°°°°°
    
    /// @notice add a new supported token
    /// @param _token ERC-20 token address
    /// @param _priceFeed address Chainlink price feed address
    /// @param _decimals token decimals
    /// @dev only owner can call this function
    function addToken(
        address _token,
        address _priceFeed,
        uint8 _decimals
    ) external onlyOwner {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_priceFeed == address(0)) revert InvalidPriceFeed();
        if (_decimals == 0 || _decimals > 18) revert InvalidDecimals();
        if (supportedTokens[_token].isActive) revert TokenAlreadyAdded();

        supportedTokens[_token] = TokenInfo({
            tokenAddress: _token,
            priceFeed: _priceFeed,
            decimals: _decimals,
            isActive: true
        });

        activeTokens.push(_token);
        emit TokenAdded(_token, _priceFeed, _decimals);
    }

    /// @notice deactivate a supported token (NO ETH)
    /// @param _token token address
    function removeToken(address _token) external onlyOwner {
        if (_token == ETH_ADDRESS) revert InvalidTokenAddress();
        if (!supportedTokens[_token].isActive) revert TokenNotSupported(_token);

        supportedTokens[_token].isActive = false;
        emit TokenRemoved(_token);
    }

    /// @notice assign admin permissions
    /// @param _admin admin address to add
    function addAdmin(address _admin) external onlyOwner {
        if (_admin == address(0)) revert InvalidTokenAddress();
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    /// @notice revoke admin permissions
    /// @param _admin admin address to revoke permissions
    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    // °°°°°°°°°°°°°°°°°° DEPOSIT FUNCTIONS °°°°°°°°°°°°°°°°°°

    /// @notice deposit ETH in the bank
    /// @dev Funds are received through the fallback function
    function depositETH() external payable validAmount(msg.value) {
        _depositToken(msg.sender, ETH_ADDRESS, msg.value);
    }

    /// @notice deposit tokens ERC-20
    /// @param _token token address
    /// @param _amount amount to deposit
    function depositToken(address _token, uint256 _amount)
        external
        validAmount(_amount)
        tokenExists(_token)
    {
        require(_token != ETH_ADDRESS, "Use depositETH for native ETH");
        
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        
        uint256 actualAmount = balanceAfter - balanceBefore;
        _depositToken(msg.sender, _token, actualAmount);
    }

    /// @param _user user address
    /// @param _token token address
    /// @param _amount amount in native tokens
    function _depositToken(address _user, address _token, uint256 _amount) private tokenExists(_token) {
        uint256 amountUSD = _convertToUSD(_token, _amount);
        
        if (totalDepositedUSD + amountUSD > BANK_CAPACITY_USD) {
            revert BankCapacityExceeded(totalDepositedUSD + amountUSD, BANK_CAPACITY_USD);
        }

        unchecked {
            userBalances[_user].balances[_token] += _amount;
            depositCount[_user][_token]++;
            totalDepositedUSD += amountUSD;
        }

        emit Deposited(_user, _token, _amount, amountUSD);
    }

    // °°°°°°°°°°°°°°°°°° WITHDRAW FUNCTIONS °°°°°°°°°°°°°°°°°°
    
    /// @notice withdraw tokens from the bank
    /// @param _token token address
    /// @param _amount amount to withdraw in native tokens
    function withdraw(address _token, uint256 _amount)
        external
        validAmount(_amount)
        tokenExists(_token)
    {
        uint256 userBalance = userBalances[msg.sender].balances[_token];
        if (_amount > userBalance) {
            revert InsufficientBalance(_amount, userBalance);
        }

        uint256 amountUSD = _convertToUSD(_token, _amount);
        if (amountUSD > WITHDRAWAL_LIMIT) {
            revert WithdrawalLimitExceeded(amountUSD, WITHDRAWAL_LIMIT);
        }

        unchecked {
            userBalances[msg.sender].balances[_token] -= _amount;
            withdrawalCount[msg.sender][_token]++;
            totalDepositedUSD -= amountUSD;
        }

        emit Withdrawn(msg.sender, _token, _amount, amountUSD);

        if (_token == ETH_ADDRESS) {
            (bool success, ) = msg.sender.call{value: _amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    // °°°°°°°°°°°°°°°°°° ANSWER FUNCTIONS °°°°°°°°°°°°°°°°°°
    
    /// @notice balance in native tokens for a specific user and token
    /// @param _user user address
    /// @param _token token address
    /// @return amount in native tokens
    function getBalance(address _user, address _token)
        external
        view
        tokenExists(_token)
        returns (uint256)
    {
        return userBalances[_user].balances[_token];
    }

    /// @notice balance in usd for a specific user and token
    /// @param _user user address
    /// @param _token token address
    /// @return balance in usd
    function getBalanceUSD(address _user, address _token)
        external
        view
        tokenExists(_token)
        returns (uint256)
    {
        uint256 balance = userBalances[_user].balances[_token];
        return _convertToUSD(_token, balance);
    }

    /// @notice user balances for all supported tokens
    /// @param _user user address
    /// @return tokens Array token addresses
    /// @return balances Array of corresponding balances
    function getAllBalances(address _user)
        external
        view
        returns (address[] memory tokens, uint256[] memory balances)
    {
        tokens = activeTokens;
        balances = new uint256[](activeTokens.length);

        for (uint256 i = 0; i < activeTokens.length; ++i) {
            balances[i] = userBalances[_user].balances[activeTokens[i]];
        }
    }

    /// @notice capacity remaining in USD
    /// @return Max capacity remaining in USD
    function getRemainingCapacity() external view returns (uint256) {
        return BANK_CAPACITY_USD - totalDepositedUSD;
    }

    /// @notice token info
    /// @param _token token address
    /// @return structure TokenInfo
    function getTokenInfo(address _token) external view returns (TokenInfo memory) {
        return supportedTokens[_token];
    }

    /// @notice active tokens list
    /// @return address[] active tokens
    function getActiveTokens() external view returns (address[] memory) {
        return activeTokens;
    }

    // °°°°°°°°°°°°°°°°°° convert functions °°°°°°°°°°°°°°°°°°

    /// @notice Convert to USD amount from native token amount
    /// @param _token token address
    /// @param _amount amount in native tokens
    /// @return amount equivalent in USD (6 decimals)
    function _convertToUSD(address _token, uint256 _amount)
        private
        view
        tokenExists(_token)
        returns (uint256)
    {
        if (_amount == 0) return 0;

        TokenInfo memory info = supportedTokens[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(info.priceFeed);

        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price <= 0) revert PriceFeedError();

        uint256 uintPrice = uint256(price);
        
        // Only six decimals adjustment
        uint256 decimalsAdjustment = 18; // ETH/USD feed devuelve 8 decimales
        if (info.decimals != 18) {
            decimalsAdjustment = 18 - info.decimals + 8;
        }

        uint256 usdAmount = (_amount * uintPrice * SCALE) / (10 ** decimalsAdjustment);
        
        return usdAmount / 10 ** (18 - INTERNAL_DECIMALS);
    }

    /// @notice Converts from USD amount to native token amount
    /// @param _token Token address
    /// @param _usdAmount Amount in USD (6 decimals)
    /// @return Equivalent amount in native tokens
    function convertFromUSD(address _token, uint256 _usdAmount)
        external
        view
        tokenExists(_token)
        returns (uint256)
    {
        if (_usdAmount == 0) return 0;

        TokenInfo memory info = supportedTokens[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(info.priceFeed);

        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price <= 0) revert PriceFeedError();

        uint256 uintPrice = uint256(price);
        uint256 decimalsAdjustment = 18;
        if (info.decimals != 18) {
            decimalsAdjustment = 18 - info.decimals + 8;
        }

        return (_usdAmount * 10 ** decimalsAdjustment) / (uintPrice * SCALE);
    }

    // °°°°°°°°°°°°°°°°°° FUNCION FALLBACK °°°°°°°°°°°°°°°°°°
    
    /// @notice Recibe ETH y lo deposita automáticamente
    receive() external payable {
        if (msg.value > 0) {
            _depositToken(msg.sender, ETH_ADDRESS, msg.value);
        }
    }
}