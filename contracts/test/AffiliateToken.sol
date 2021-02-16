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
        uint256 totalShares = totalSupply();

        if (totalShares > 0) {
            return totalBalance(address(this)).mul(numShares).div(totalShares);
        } else {
            return numShares;
        }
    }

    function _sharesForValue(uint256 amount) internal returns (uint256) {
        uint256 totalWrapperAssets = totalBalance(address(this));

        if (totalWrapperAssets > 0) {
            return totalSupply().mul(amount).div(totalWrapperAssets);
        } else {
            return amount;
        }
    }

    function deposit(uint256 amount) external returns (uint256 deposited) {
        uint256 shares = _sharesForValue(amount); // NOTE: Must be calculated before deposit is handled
        deposited = _deposit(msg.sender, address(this), amount, true); // `true` = pull from `msg.sender`
        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) external returns (uint256) {
        _burn(msg.sender, shares);
        return _withdraw(address(this), msg.sender, _shareValue(shares), true); // `true` = withdraw from `best`
    }

    function migrate() external onlyAffliate returns (uint256) {
        return _migrate(address(this));
    }
}
