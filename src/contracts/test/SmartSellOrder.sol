// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../interfaces/EIP1271.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Order.sol";
import "../libraries/SafeERC20.sol";
import "../libraries/SafeMath.sol";
import "../Settlement.sol";

/// @title Proof of Concept Smart Order
/// @author Gnosis Developers
contract SmartSellOrder is EIP1271Verifier {
    using Order for Order.Data;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant APPDATA = keccak256("SmartSellOrder");

    address public immutable owner;
    bytes32 public immutable domainSeparator;
    IERC20 public immutable sellToken;
    IERC20 public immutable buyToken;
    uint256 public immutable totalSellAmount;
    uint256 public immutable totalFeeAmount;
    uint32 public immutable validTo;

    constructor(
        Settlement settlement,
        IERC20 sellToken_,
        IERC20 buyToken_,
        uint32 validTo_,
        uint256 totalSellAmount_,
        uint256 totalFeeAmount_
    ) {
        owner = msg.sender;
        domainSeparator = settlement.domainSeparator();
        sellToken = sellToken_;
        buyToken = buyToken_;
        validTo = validTo_;
        totalSellAmount = totalSellAmount_;
        totalFeeAmount = totalFeeAmount_;

        sellToken_.approve(
            address(settlement.vaultRelayer()),
            type(uint256).max
        );
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function withdraw(uint256 amount) external onlyOwner {
        sellToken.safeTransfer(owner, amount);
    }

    function close() external onlyOwner {
        uint256 balance = sellToken.balanceOf(address(this));
        if (balance != 0) {
            sellToken.safeTransfer(owner, balance);
        }
        selfdestruct(payable(owner));
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        uint256 sellAmount = abi.decode(signature, (uint256));
        Order.Data memory order = orderForSellAmount(sellAmount);

        if (order.hash(domainSeparator) == hash) {
            magicValue = EIP1271.MAGICVALUE;
        }
    }

}
