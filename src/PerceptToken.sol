pragma solidity 0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract PerceptToken is ERC20("PerceptToken", "PCT", 18) {
  constructor(uint256 _totalSupply) {
    _mint(tx.origin, _totalSupply);
  }
}