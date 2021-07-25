// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@nomiclabs/buidler/console.sol";


contract USST is ERC20  {
    constructor() ERC20("USSToken", "USST") {
        _mint(0xfcdBda4dD88b2102F891D60E7BEF5E5c48dbB184, 1000000000000000);
        // _mint(block.coinbase, 1000000000000000000);
    }
    function mintMinerReward(uint256 value) public {
        // console.log("value:", value);
        _mint(block.coinbase, value);
    }
}
