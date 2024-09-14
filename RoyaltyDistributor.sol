// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract RoyaltyDistributor is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    IERC1155 public nftContract;
    uint256 public minTokenId;
    uint256 public maxTokenId;
    uint256 public distributionThreshold;
    uint256 public gasReserve = 2 ether;
    mapping(address => bool) public blacklistedAddresses;
    EnumerableSet.AddressSet private registeredAddresses;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    event RoyaltiesDistributed(uint256 amount);
    event AddressRegistered(address indexed account);
    event AddressDeregistered(address indexed account);
    event BlacklistedAddress(address indexed account, bool isBlacklisted);
    event DistributionTriggered(uint256 balance);
    event DistributionFailed(string reason);
    
    constructor(
        address _nftContractAddress,
        uint256 _minTokenId,
        uint256 _maxTokenId,
        uint256 _distributionThreshold
    ) Ownable(msg.sender) {
        nftContract = IERC1155(_nftContractAddress);
        minTokenId = _minTokenId;
        maxTokenId = _maxTokenId;
        distributionThreshold = _distributionThreshold;
    }
    
    receive() external payable {
        if (address(this).balance >= distributionThreshold) {
            emit DistributionTriggered(address(this).balance);
            _distributeRoyalties();
        }
    }
    
    function registerAddress() external {
        require(!blacklistedAddresses[msg.sender], "Blacklisted address");
        registeredAddresses.add(msg.sender);
        emit AddressRegistered(msg.sender);
    }
    
    function deregisterAddress() external {
        registeredAddresses.remove(msg.sender);
        emit AddressDeregistered(msg.sender);
    }
    
    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
    
    function getTotalBalance(address _holder) internal view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 tokenId = minTokenId; tokenId <= maxTokenId; tokenId++) {
            totalBalance += nftContract.balanceOf(_holder, tokenId);
        }
        return totalBalance;
    }
    
    function _distributeRoyalties() internal {
        require(address(this).balance > gasReserve, "Not enough balance to cover gas reserve");
        uint256 distributableAmount = address(this).balance - gasReserve;
        uint256 totalDistributed = 0;
        uint256 totalEligibleBalance = 0;
        
        // First pass: calculate total eligible balance
        for (uint256 i = 0; i < registeredAddresses.length(); i++) {
            address holder = registeredAddresses.at(i);
            if (isEligibleHolder(holder)) {
                uint256 balance = getTotalBalance(holder);
                totalEligibleBalance += balance;
            }
        }
        
        require(totalEligibleBalance > 0, "No eligible balance to distribute");
        
        // Second pass: distribute royalties to eligible holders
        for (uint256 i = 0; i < registeredAddresses.length(); i++) {
            address holder = registeredAddresses.at(i);
            if (isEligibleHolder(holder)) {
                uint256 balance = getTotalBalance(holder);
                if (balance > 0) {
                    uint256 share = (distributableAmount * balance) / totalEligibleBalance;
                    totalDistributed += share;
                    (bool success, ) = payable(holder).call{value: share}("");
                    if (!success) {
                        emit DistributionFailed(string(abi.encodePacked("Failed to send ", share, " to ", holder)));
                    }
                }
            }
        }
        
        emit RoyaltiesDistributed(totalDistributed);
    }
    
    function isEligibleHolder(address holder) internal view returns (bool) {
        return !blacklistedAddresses[holder] && holder != BURN_ADDRESS && !isContract(holder);
    }
    
    function manualDistributeRoyalties() external onlyOwner {
        _distributeRoyalties();
    }
    
    function blacklistAddress(address _address, bool _blacklist) external onlyOwner {
        blacklistedAddresses[_address] = _blacklist;
        emit BlacklistedAddress(_address, _blacklist);
    }
    
    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > gasReserve, "Cannot withdraw below gas reserve");
        payable(owner()).transfer(balance - gasReserve);
    }
    
    function withdrawERC20(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No token balance");
        token.transfer(owner(), balance);
    }
    
    function withdrawERC1155(IERC1155 token, uint256 id, uint256 amount) external onlyOwner {
        token.safeTransferFrom(address(this), owner(), id, amount, "");
    }
    
    function withdrawERC721(IERC721 token, uint256 tokenId) external onlyOwner {
        token.safeTransferFrom(address(this), owner(), tokenId);
    }
} 
