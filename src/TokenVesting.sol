// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
1. The contract should allow an admin to create vesting schedules for different beneficiaries
2. Each vesting schedule should have:
   - A cliff period (time before any tokens can be claimed)
   - A vesting duration (total time until fully vested)
   - A total amount of tokens to be vested
3. Beneficiaries should be able to claim their vested tokens at any time after the cliff
4. The contract should be able to handle multiple beneficiaries with different schedules
5. Implement appropriate security measures and access controls
Base contract and interface provided below. Implement the missing functionality.
*/

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenVesting {
    IERC20 public immutable token;
    address public admin;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 startTime;
        uint256 amountClaimed;
        bool initialized;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "only admin can perform");
        _;
    }

    // more params
    event VestingCreated(address beneficiary);

    // Mapping from beneficiary address to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // TODO: Implement events for important state changes

    constructor(address _token, address _admin) {
        require(_token != address(0), "can not be zero address");
        require(_admin != address(0), "can not be zero address");
        token = IERC20(_token);
        admin = _admin;
    }

    // Assumption: after startTime + cliffDuration : can start claiming until startTime + cliffDuration + vestingDuration

    function createVestingSchedule(
        address beneficiary,
        // Could also pass startTime here
        uint256 totalAmount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external payable onlyAdmin {
        // Make checks..
        require(beneficiary != address(0), "beneficiary can not be zero address");
        // check if already initiased
        // check amounts > 0
        // check time durations
        // TODO: Implement vesting schedule creation
        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: totalAmount,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            startTime: block.timestamp, // assuming cliff starts at start time
            amountClaimed: 0,
            initialized: true // review
        });
        vestingSchedules[beneficiary] = schedule;
        // emit an event
        // can check an allowance
        IERC20(token).transferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
    }

    function calculateVestedAmount(address beneficiary) public view returns (uint256) {
        // TODO: Implement vesting calculation logic
        // At any point of time how much a person can claim
        VestingSchedule memory _schedule = vestingSchedules[beneficiary];
        require(_schedule.initialized == true, "Unauthorized");
        if(block.timestamp < _schedule.startTime) return 0;
        if(_schedule.amountClaimed == _schedule.totalAmount) return 0;
        uint256 currentTimestamp = block.timestamp > (_schedule.startTime + _schedule.cliffDuration + _schedule.vestingDuration)
            ? (_schedule.startTime + _schedule.cliffDuration + _schedule.vestingDuration)
            : block.timestamp;
        uint256 claimPercent;
        uint256 claimAmount;
        uint256 unclaimedAmount;
        if(block.timestamp >= _schedule.startTime + _schedule.cliffDuration) {
           claimPercent = (currentTimestamp - _schedule.startTime + _schedule.cliffDuration) * 1e18 / _schedule.vestingDuration;
        } else {
            return 0;
        } 
        claimAmount = _schedule.totalAmount * claimPercent / 1e18;
        unclaimedAmount = claimAmount - _schedule.amountClaimed;
        return unclaimedAmount;
    }

    function claimVestedTokens() external {
        // TODO: Implement token claiming logic
        address beneficiary = msg.sender;
        VestingSchedule memory _schedule = vestingSchedules[beneficiary];
        require(_schedule.initialized, "CLAIM_INACTIVE");
        uint256 unclaimedAmount = calculateVestedAmount(beneficiary);
        _schedule.amountClaimed = _schedule.amountClaimed + unclaimedAmount;
        if (_schedule.amountClaimed == _schedule.totalAmount) _schedule.initialized = false;
        vestingSchedules[beneficiary] = _schedule;
        IERC20(token).transfer(beneficiary, unclaimedAmount);
        // emit claimed event
    }

    // TODO: Implement any additional functions needed for security or management
}