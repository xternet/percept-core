pragma solidity 0.8.17;

//import ERC20 library from solmate
import {ERC20} from "solmate/tokens/ERC20.sol";

contract PerceptToken is ERC20("PerceptToken", "PCT", 18) {
  constructor() {
  	_mint(msg.sender, 1000000 ether);
  }
}