// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./Bamboo.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BambooUpgrader is Ownable {

    Bamboo bamboo;
    uint256 public constant CONVERSION_RATIO = 4510000; // 451 Trillion : 100 Million
    address public constant PINKPANDA = 0x631E1e455019c359b939fE214EDC761d36bF6aD6; // BSC token contract address

    uint256 public deadlineTime;

    mapping(address => uint256) public balancePinkPanda;

    event Deployed(address sender, uint256 deadlineTime, address bambooToken, uint256 bambooBalance);
    event Deposited(address sender, uint256 amountPinkPanda);
    event Withdrawal(address sender, uint256 amountBamboo);
    event RecoverPinkPanda(address sender, uint256 amountPinkPanda);
    event RecoverBamboo(address sender, uint256 amountBamboo);

    modifier beforeDeadline {
        require(block.timestamp < deadlineTime, "BambooUpgrader::beforeDeadline: current time is after deadline");
        _;
    }

    modifier afterDeadline {
        require(block.timestamp >= deadlineTime, "BambooUpgrader:afterDeadline: current time is before deadline");
        _;
    }

    constructor(uint256 durationDays) {
        bamboo = new Bamboo();
        bamboo.transferOwnership(msg.sender);
        deadlineTime = block.timestamp + durationDays * 1 days;
        emit Deployed(msg.sender, deadlineTime, address(bamboo), bamboo.balanceOf(address(this)));
    }

    /**
     @notice Transfer PinkPanda to this contract. User receives full credit for gross amount, regardless of fees subtracted. Tokens are locked. 
     */
    function depositPinkPanda(uint256 amountPinkPanda) external beforeDeadline {
        balancePinkPanda[msg.sender] += amountPinkPanda;
        emit Deposited(msg.sender, amountPinkPanda);
        IERC20(PINKPANDA).transferFrom(msg.sender, address(this), amountPinkPanda);
    }

    function withdrawBamboo() external afterDeadline {
        uint256 amountBamboo = bambooForPinkPanda(balancePinkPanda[msg.sender]);
        delete balancePinkPanda[msg.sender];
        emit Withdrawal(msg.sender, amountBamboo);
        bamboo.transfer(msg.sender, amountBamboo);
    }

    /**
     @notice Enables recovery of PinkPanda liquidity to convert to Bamboo liquidity
     */
    function recoverPinkPanda() external onlyOwner afterDeadline {
        uint amountPinkPanda = IERC20(PINKPANDA).balanceOf(address(this));
        emit RecoverPinkPanda(msg.sender, amountPinkPanda);
        IERC20(PINKPANDA).transfer(msg.sender, amountPinkPanda);
    }

    /**
     @notice After the deadline, balance of Bamboo is otherwise unrecoverable. Needed for new liquidity pool. 
     */
    function recoverBamboo() external onlyOwner afterDeadline {
        uint256 amountBamboo = unclaimedBamboo();
        emit RecoverBamboo(msg.sender, amountBamboo);
        bamboo.transfer(msg.sender, amountBamboo);
    }

    function bambooToken() external view returns(address) {
        return address(bamboo);
    }

    function bambooForPinkPanda(uint256 amountPinkPanda) public pure returns(uint256 amountBamboo) {
        amountBamboo = amountPinkPanda / CONVERSION_RATIO;
    }

    function unclaimedBamboo() public view returns(uint256 amountBamboo) {
        uint256 claimable = bambooForPinkPanda(IERC20(PINKPANDA).balanceOf(address(this)));
        amountBamboo = bamboo.balanceOf(address(this)) - claimable;
    }
    
}