// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract GUSC is ERC20  {
    IERC20 usst;
    
    constructor() ERC20("GuessCoin", "GUSC") {
          usst=IERC20(0xD6C850aeBFDC46D7F4c207e445cC0d6B0919BDBe);
    }

    function mintByUsst(uint256 usstAmount) public {
        usst.transferFrom(msg.sender,address(this),usstAmount);
        _mint(msg.sender,usstAmount*100);
    }
}