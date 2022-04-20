// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OdonToken is ERC20 {
  constructor() ERC20("ODON TOKEN", "ODON") {
    _mint(msg.sender, 1000000000000000 * 10**uint256(decimals()));
  }

  function mint(uint256 _amount) public {
    _mint(msg.sender, _amount * 10**uint256(decimals()));
  }
}