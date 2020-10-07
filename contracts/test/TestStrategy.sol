// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {BaseStrategy, StrategyParams} from "../BaseStrategy.sol";

/*
 * This Strategy serves as both a mock Strategy for testing, and an example
 * for integrators on how to use BaseStrategy
 */

contract TestStrategy is BaseStrategy {
    constructor(address _vault, address _governance) public BaseStrategy(_vault, _governance) {}

    // When exiting the position, wait this many times to give everything back
    uint256 countdownTimer = 3;

    // NOTE: This is a test-only function
    function _takeFunds(uint256 amount) public {
        want.transfer(msg.sender, amount);
    }

    function tendTrigger(uint256 gasCost) public override view returns (bool) {
        StrategyParams memory params = vault.strategies(address(this));
        return (params.activation > 0 && want.balanceOf(address(this)) == reserve && gasCost < 0.1 ether);
    }

    function harvestTrigger(uint256 gasCost) public override view returns (bool) {
        StrategyParams memory params = vault.strategies(address(this));
        return (params.activation > 0 && want.balanceOf(address(this)) > reserve && gasCost < 0.1 ether);
    }

    function expectedReturn() public override view returns (uint256) {
        return vault.expectedReturn();
    }

    function estimatedTotalAssets() public override view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function prepareReturn() internal override {
        // During testing, send this contract some tokens to simulate "Rewards"
    }

    function adjustPosition() internal override {
        // Whatever we have "free", consider it "invested" now
        reserve = want.balanceOf(address(this)).sub(outstanding);
    }

    function exitPosition() internal override {
        // Dump 25% each time this is called, the first 3 times
        if (countdownTimer > 0) {
            reserve = want.balanceOf(address(this)).div(4);
            countdownTimer -= 1;
        } else {
            // NOTE: This is a testing-only invariant
            require(outstanding == want.balanceOf(address(this)), "!invariant");
            reserve = 0;
        }
    }

    function prepareMigration(address _newStrategy) internal override {
        want.transfer(_newStrategy, want.balanceOf(address(this)));
    }
}