// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {VaultAPI, BaseWrapper} from "../BaseWrapper.sol";

contract AffiliateToken is ERC20, BaseWrapper {
    address public affliate;

    modifier onlyAffliate() {
        require(msg.sender == affliate);
        _;
    }

    constructor(
        address _token,
        string memory name,
        string memory symbol
    ) public BaseWrapper(_token) ERC20(name, symbol) {
        _setupDecimals(uint8(token.decimals()));
    }

    function _shareValue(uint256 numShares) internal returns (uint256) {
        uint256 totalTokenBalance = totalAssets();

        if (totalTokenBalance > 0) {
            return totalTokenBalance.mul(numShares).div(totalSupply());
        } else {
            return 0;
        }
    }

    function _sharesForValue(uint256 amount) internal returns (uint256) {
        uint256 totalTokenBalance = totalAssets();

        if (totalTokenBalance > 0) {
            return totalSupply().mul(amount).div(totalTokenBalance);
        } else {
            return 0;
        }
    }

    function deposit(uint256 amount) external returns (uint256 deposited) {
        deposited = _sharesForValue(_deposit(msg.sender, amount, true)); // `true` = pull from `msg.sender`
        _mint(msg.sender, deposited);
    }

    function withdraw(uint256 shares) external returns (uint256 amount) {
        _burn(msg.sender, shares);
        amount = _withdraw(address(this), _shareValue(shares), true); // `true` = withdraw from `best`
        token.transfer(msg.sender, amount);
    }

    function migrate() external onlyAffliate returns (uint256) {
        _migrate(address(this));
    }
}
