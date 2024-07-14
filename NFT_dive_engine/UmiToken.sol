
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UmiToken is ERC20 {
    constructor() ERC20("Umi", "UMI") {
        _mint(msg.sender, 20000000000000 * 10 ** 6);
    }

    function decimals() public pure override  returns (uint8) {
        return 6;
    }
}