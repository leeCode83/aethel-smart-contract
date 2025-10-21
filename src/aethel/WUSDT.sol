// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WUSDT is ERC20 {
    constructor() ERC20("Wrapped USDT", "WUSDT") {
        // _mint(msg.sender, 1000 * 10**6);
        // Mint 1000 MYUSDT ke deployer (1 MYUSDT = 1.000.000 unit)
    }

    function mint(address recipient, uint256 ammount) public {
        _mint(recipient, ammount);
    }
}
