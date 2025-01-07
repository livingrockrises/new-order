// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract HoodieShopVault is ERC2771Context, ReentrancyGuard {

    IERC20 public immutable usdc; // Base USDC token address 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    address public admin;
    AggregatorV3Interface internal nativeOracle;
    uint32 constant PRICE_FACTOR = 10_00_000;

    // Mappings for eligibility
    mapping(bytes32 => bool) public userIdToEligibility;
    mapping(address => bool) public userAddressToEligibility;

    // Events
    event DepositConfirmed(address indexed userAddress, bytes32 indexed userId, HoodieSize indexed size);

    // Errors
    error CanNotWithdrawToZeroAddress();
    error OracleAddressCannotBeZero();
    error InvalidPriceFromRound();
    error PriceFeedStale();
    error LatestRoundIncomplete();

    // Enum for hoodie sizes
    enum HoodieSize {
        SMALL,
        MEDIUM,
        LARGE,
        EXTRA_LARGE
    }

    // Constructor
    constructor(address _token, address _admin, address _trustedForwarder, address _nativeOracle) ERC2771Context(_trustedForwarder) {
        usdc = IERC20(_token);
        admin = _admin;
        nativeOracle = AggregatorV3Interface(_nativeOracle);
    }

    // Receive Ether
    receive() external payable {}

        // Modifiers
    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    // Deposit and order a hoodie
    function depositAndOrder(bytes32 _userId, HoodieSize _size) external payable nonReentrant{
        // Check if ETH is received
        if (msg.value > 0) {
            uint256 _ethSent = msg.value;
            uint256 exchangeRate = uint256(getThePrice());
            uint8 oracleDecimals = nativeOracle.decimals();
            uint256 approxUSD = (_ethSent/1e18)*(exchangeRate/(10**oracleDecimals)) * PRICE_FACTOR;
            // Require ETH value to be equivalent to or above 30 USD
            require(approxUSD > 30e6, "Pay more ETH");
        } else {
            // Check USDC allowance and transfer 30 USDC to this contract
            require(usdc.allowance(_msgSender(), address(this)) >= 30e6, "Insufficient USDC allowance");
            SafeTransferLib.safeTransferFrom(address(usdc), _msgSender(), address(this), 30e6);
        }

        // Mark user as eligible
        userIdToEligibility[_userId] = true;
        userAddressToEligibility[_msgSender()] = true;

        // Emit deposit confirmation event
        emit DepositConfirmed(_msgSender(), _userId, _size);
    }

    // Check if a user is eligible
    function isEligibleUser(address _userAddress) public view returns (bool) {
        return userAddressToEligibility[_userAddress];
    }

    // Withdraw ERC20 tokens
    function withdrawERC20(IERC20 token, address target, uint256 amount) public onlyAdmin nonReentrant {
        _withdrawERC20(token, target, amount);
    }

    // Withdraw ETH
    function withdrawEth(address receiver, uint256 amount) public onlyAdmin nonReentrant {
        require(receiver != address(0), "Cannot withdraw to zero address");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = receiver.call{value: amount}("");
        require(success, "ETH withdrawal failed");
    }

    function getThePrice() public view returns (int256) {
        /**
         * Returns the latest price of price feed 1
         */

        (
            uint80 roundID,
            int256 price,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = nativeOracle.latestRoundData();

        // By default 2 days old price is considered stale BUT it may vary per price feed
        // comapred to stable coin feeds this may have different heartbeat
        validateRound(
            roundID,
            price,
            updatedAt,
            answeredInRound,
            60 * 60 * 24 * 2
        );
        return price;
    }


    function validateRound(
        uint80 roundId,
        int256 price,
        uint256 updatedAt,
        uint80 answeredInRound,
        uint256 staleFeedThreshold
    ) internal view {
        if (price <= 0) revert InvalidPriceFromRound();
        // 2 days old price is considered stale since the price is updated every 24 hours
        if (updatedAt < block.timestamp - staleFeedThreshold)
            revert PriceFeedStale();
        if (updatedAt == 0) revert LatestRoundIncomplete();
        if (answeredInRound < roundId) revert PriceFeedStale();
    }

    // Private function to handle ERC20 withdrawal
    function _withdrawERC20(IERC20 token, address target, uint256 amount) private {
        if (target == address(0)) revert CanNotWithdrawToZeroAddress();
        SafeTransferLib.safeTransfer(address(token), target, amount);
    }
}
