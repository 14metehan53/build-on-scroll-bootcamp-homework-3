// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PayPool is ReentrancyGuard {

    struct DepositRecord {
        address depositor;
        uint256 amount;
        uint256 timestamp;
        DepositStatus depositStatus;
        uint8 approveCount;
        uint8 rejectCount;
    }

    enum DepositStatus {
        Pending,
        Approved,
        Rejected
    }

    uint256 public totalBalance;
    address public owner;

    address[] public depositAddresses;
    mapping(address => uint256) public allowances;
    DepositRecord[] public depositHistory;


    // @@@ EVENTS
    event Deposit(address indexed depositer, uint256 amount);
    event AddressAdded(address indexed depositer);
    event AddressRemoved(address indexed depositer);
    event AllowanceGranted(address indexed user, uint amount);
    event AllowanceRemoved(address indexed user);
    event FundsRetrieved(address indexed recepient, uint amount);

    // MODIFIERS
    modifier isOwner() {
        require(owner == msg.sender, "Not Owner!");
        _;
    }

    modifier gotAllowance(address user) {
        require(hasAllowance(user), "This address has no allowance");
        _;
    }

    modifier canDepositTokens(address depositer) {
        require(canDeposit(depositer), "This address is not allowed to deposit tokens");
        _;
    }

    constructor() payable {
        owner = msg.sender;
        totalBalance = msg.value;
    }

    function hasAllowance(address user) internal view returns(bool) {
        return allowances[user] > 0;
    }

    function canDeposit(address depositer) internal view returns(bool) {
        for (uint i = 0; i <= depositAddresses.length; i++) {
            if (depositAddresses[i] == depositer) {
                return true;
            }
        }
        return false;
    }

    function addDepositAddress(address depositer) external isOwner {
        depositAddresses.push(depositer);
        emit AddressAdded(depositer);
    }

    function removeDepositAddress(uint index) external isOwner canDepositTokens(depositAddresses[index]) {
        depositAddresses[index] = address(0);
        emit AddressRemoved(depositAddresses[index]);
    }

    function deposit() external canDepositTokens(msg.sender) payable {
        //totalBalance += msg.value;
        depositHistory.push(DepositRecord(msg.sender, msg.value, block.timestamp, DepositStatus.Pending, 0, 0));
        emit Deposit(msg.sender, msg.value);
    }

    function approveDeposit(uint256 index) external isOwner {
        require(depositHistory[index].depositStatus != DepositStatus.Rejected, "You already rejected!");
        require(depositHistory[index].approveCount < 1, "You cannot approve a second time!");
        depositHistory[index].depositStatus = DepositStatus.Approved;
        totalBalance += depositHistory[index].amount;
        depositHistory[index].approveCount++;
    }

    function rejectDeposit(uint256 index, address to) external isOwner {
        require(depositHistory[index].depositStatus != DepositStatus.Approved, "You already approved!");
        require(depositHistory[index].rejectCount < 1, "You cannot reject a second time!");
        depositHistory[index].depositStatus = DepositStatus.Rejected;
        payable(to).transfer(depositHistory[index].amount);
        depositHistory[index].rejectCount++;
    }

    function getDepositHistory() public view returns(DepositRecord[] memory) {
        return depositHistory;
    }

    function viewApproveDeposit(uint256 index) external view returns(address, uint256, PayPool.DepositStatus) {
        return (depositHistory[index].depositor, depositHistory[index].amount, depositHistory[index].depositStatus);
    }

    function retrieveBalance() external isOwner nonReentrant {
        uint balance = totalBalance;
        (bool success,) = owner.call{value: balance}("");
        require(success, "Transfer Failed");
        totalBalance = 0;
        emit FundsRetrieved(owner, balance);
    }

    function giveAllowance(address user, uint amount) external isOwner {
        require(totalBalance > amount, "");
        allowances[user] = amount;

        unchecked {
            totalBalance -= amount;
        }

        emit AllowanceGranted(user, amount);
    }

    function removeAllowance(address user) external isOwner gotAllowance(user) {
        allowances[user] = 0;
        emit AllowanceRemoved(user);
    }

    function allowRetrieval() external gotAllowance(msg.sender) nonReentrant {
        uint amount = allowances[msg.sender];
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Retrieval failed");
        allowances[msg.sender] = 0;
        emit FundsRetrieved(msg.sender, amount);
    }

}
