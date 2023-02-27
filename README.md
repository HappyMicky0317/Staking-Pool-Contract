# Staking Pool

## Approach

Users can stake their ETH into this pool to potentially receive rewards (currently not available). When users stake their ETH, the contract internally tracks the amount of ETH they staked and the shares they have in the pool. As ETH staking rewards are not available yet, users will basically get a 1:1 ratio of shares and staked ETH. However, if the contract were to receive ETH from elsewhere (rewards), the amount of shares received from any new staker will depend on how much ETH is in the contract. On the flip side, when users want to withdraw their staked ETH plus any rewards (not available), the amount of ETH they receive back will depend on their shares.

## Functions

The `stake` and `withdrawStake` functions only work when the contract is not paused and the pool is not full (< 32 ETH). The `stake` function allows the user to stake their ETH within the contract. The `withdrawStake` function allows the user to withdraw their staked ETH before the pool becomes full if they wish. The `unstake` function allows the user to unstake their ETH plus any rewards. However, this is currently turned off.
