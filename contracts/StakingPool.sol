// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IDepositContract {
    /// @notice A processed deposit event.
    // https://github.com/ethereum/consensus-specs/blob/dev/solidity_deposit_contract/deposit_contract.sol
    event DepositEvent(
        bytes pubkey,
        bytes withdrawal_credentials,
        bytes amount,
        bytes signature,
        bytes index
    );

    /// @notice Submit a Phase 0 DepositData object.
    /// @param pubkey A BLS12-381 public key.
    /// @param withdrawal_credentials Commitment to a public key for withdrawals.
    /// @param signature A BLS12-381 signature.
    /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count.
    /// @return The deposit count encoded as a little endian 64-bit number.
    function get_deposit_count() external view returns (bytes memory);
}

contract StakingPool is Pausable, Ownable {
    // Total amount of ETH staked
    uint256 public totalEthStaked;

    // Total amount of rewards received by the contract
    uint256 public totalRewardsReceived;

    // To check if pool is full or not
    bool public poolFull;

    // To check if rewards are turned on
    bool public rewardsOn;

    // Address of mainnet staking contract
    address public mainnetStakingAddress;

    // Address of goerli staking contract
    address public goerliStakingAddress;

    // User's staked amount
    mapping(address => uint256) private stakedAmount;

    // --- Events ---
    event Stake(address indexed staker, uint256 stakedAmount);

    event WithdrawStake(address indexed staker, uint256 amountWithdrawn);

    event ClaimRewards(
        address indexed staker,
        uint256 amountClaimed,
        uint256 rewardsClaimed
    );

    // Allow contract to receive ETH
    receive() external payable {
        totalRewardsReceived += msg.value;
    }

    constructor() {
        poolFull = false;
        rewardsOn = false;
        mainnetStakingAddress = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
        goerliStakingAddress = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;
    }

    // Check if pool is full
    modifier isPoolFull() {
        require(!poolFull, "Pool is full");
        _;
    }

    // --- Admin functions ---
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function turnOnRewards() external onlyOwner {
        rewardsOn = true;
    }

    function turnOffPoolFull() external onlyOwner {
        poolFull = false;
    }


    // Need to complete function with required parameters
    function depositStake(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external onlyOwner {
        poolFull = true;

        // Deposit 32 ETH into deposit contract
        require(address(this).balance >= 32 ether, "depositStake: insufficient pool balance");
        // we need to figure out how to hash the contract address properly to match the withdrawal credentials
        // should be able to reverse engineer from staking deposit cli
        //require(keccak256(abi.encodePacked(withdrawal_credentials)) == keccak256(abi.encodePacked(address(this))), "depositStake: withdrawal_credentials address must match this contract address");

        IDepositContract(goerliStakingAddress).deposit{value: 32 ether}(
            pubkey,
            abi.encodePacked(withdrawal_credentials),
            signature,
            deposit_data_root
        );
    }

    // Allow users to stake ETH if pool is not full
    function stakeIntoPool() external payable whenNotPaused isPoolFull {
        // ETH sent from user needs to be greater than 0
        require(msg.value > 0, "Invalid amount");

        // Check if staked ETH balance is over 32 ETH after user deposits stake
        require(
            totalEthStaked + msg.value <= 32.01 ether,
            "Pool max capacitiy"
        );

        // Update state
        stakedAmount[msg.sender] += msg.value;
        totalEthStaked += msg.value;

        emit Stake(msg.sender, msg.value);
    }

    // Allow users to withdraw their stake if pool is not full
    function withdrawStakeFromPool(
        uint256 amount
    ) external whenNotPaused isPoolFull {
        // Check if user has enough to withdraw
        require(stakedAmount[msg.sender] >= amount, "Insufficient amount");

        // Update state
        stakedAmount[msg.sender] -= amount;
        totalEthStaked -= amount;

        // Send user withdrawal amount
        (bool withdrawal, ) = payable(msg.sender).call{value: amount}("");
        require(withdrawal, "Failed to withdraw");

        emit WithdrawStake(msg.sender, amount);
    }

    // Allow users to unstake a certain amount of ETH + rewards (currently off)
    function unstakeFromPool(uint256 amount) external whenNotPaused {
        require(rewardsOn, "Currently cannot claim rewards");

        uint256 userStakedAmount = stakedAmount[msg.sender];

        // Check if user has enough to claim
        require(userStakedAmount >= amount, "Insufficient amount");

        // Calculate rewards
        uint256 totalStakePortion = (userStakedAmount * 10 ** 18) /
            totalEthStaked;
        uint256 totalUserRewards = (totalStakePortion * totalRewardsReceived) /
            10 ** 18;
        uint256 rewards = (totalUserRewards *
            ((amount * 10 ** 18) / userStakedAmount)) / 10 ** 18;

        // Update state
        stakedAmount[msg.sender] -= amount;

        // Send user amount staked + rewards
        (bool claim, ) = payable(msg.sender).call{value: amount + rewards}("");
        require(claim, "Failed to unstake");

        emit ClaimRewards(msg.sender, amount, rewards);
    }

    // Retrieve user's amount of staked ETH
    function stakeOf(address staker) public view returns (uint256) {
        return stakedAmount[staker];
    }

    // Calculate total staker's rewards
    function rewardOf(address staker) public view returns (uint256) {
        uint256 userStakedAmount = stakedAmount[staker];

        if (userStakedAmount == 0) {
            return 0;
        }

        // Calculate rewards
        uint256 totalStakePortion = (userStakedAmount * 10 ** 18) /
            totalEthStaked;
        uint256 totalUserRewards = (totalStakePortion * totalRewardsReceived) /
            10 ** 18;

        return totalUserRewards;
    }
}
