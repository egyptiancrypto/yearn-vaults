// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {VaultAPI, BaseWrapper} from "../BaseWrapper.sol";

contract AffiliateToken is ERC20, BaseWrapper {
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @notice The EIP-712 typehash for the permit struct used by the contract
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    address public affiliate;

    address public pendingAffiliate;

    modifier onlyAffiliate() {
        require(msg.sender == affiliate);
        _;
    }

    constructor(
        address _token,
        string memory name,
        string memory symbol
    ) public BaseWrapper(_token) ERC20(name, symbol) {
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes("1")), _getChainId(), address(this)));
        affiliate = msg.sender;
        _setupDecimals(uint8(token.decimals()));
    }

    function _getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function setAffiliate(address _affiliate) external onlyAffiliate {
        pendingAffiliate = _affiliate;
    }

    function acceptAffiliate() external {
        require(msg.sender == pendingAffiliate);
        affiliate = msg.sender;
    }

    function setRegistry(address _registry) external onlyAffiliate {
        _setRegistry(_registry);
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

    function migrate() external onlyAffiliate returns (uint256) {
        return _migrate(address(this));
    }

    /**
     * @notice Triggers an approval from owner to spends
     * @param owner The address to approve from
     * @param spender The address to be approved
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @param deadline The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(owner != address(0), "permit: signature");
        require(block.timestamp <= deadline, "permit: expired");

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, amount, nonces[owner]++, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        address signatory = ecrecover(digest, v, r, s);
        require(signatory == owner, "permit: unauthorized");

        _approve(owner, spender, amount);
    }
}
