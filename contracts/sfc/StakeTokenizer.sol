pragma solidity ^0.5.0;

import "./SFC.sol";
import "../erc20/base/ERC20Burnable.sol";
import "../erc20/base/ERC20Mintable.sol";
import "../common/Initializable.sol";

contract Spacer {
    address private _owner;
}

contract StakeTokenizer is Spacer, Initializable {
    SFC internal sfc;

    mapping(address => mapping(uint256 => uint256)) public outstandingSTXH;

    address public sTXHTokenAddress;

    function initialize(address _sfc, address _sTXHTokenAddress) public initializer {
        sfc = SFC(_sfc);
        sTXHTokenAddress = _sTXHTokenAddress;
    }

    function mintSTXH(uint256 toValidatorID) external {
        address delegator = msg.sender;
        uint256 lockedStake = sfc.getLockedStake(delegator, toValidatorID);
        require(lockedStake > 0, "delegation isn't locked up");
        require(lockedStake > outstandingSTXH[delegator][toValidatorID], "sTXH is already minted");

        uint256 diff = lockedStake - outstandingSTXH[delegator][toValidatorID];
        outstandingSTXH[delegator][toValidatorID] = lockedStake;

        // It's important that we mint after updating outstandingSTXH (protection against Re-Entrancy)
        require(ERC20Mintable(sTXHTokenAddress).mint(delegator, diff), "failed to mint sTXH");
    }

    function redeemSTXH(uint256 validatorID, uint256 amount) external {
        require(outstandingSTXH[msg.sender][validatorID] >= amount, "low outstanding sTXH balance");
        require(IERC20(sTXHTokenAddress).allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        outstandingSTXH[msg.sender][validatorID] -= amount;

        // It's important that we burn after updating outstandingSTXH (protection against Re-Entrancy)
        ERC20Burnable(sTXHTokenAddress).burnFrom(msg.sender, amount);
    }

    function allowedToWithdrawStake(address sender, uint256 validatorID) public view returns(bool) {
        return outstandingSTXH[sender][validatorID] == 0;
    }
}
