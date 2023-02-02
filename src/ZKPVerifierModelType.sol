pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";

contract ZKPVerifierModelType is Owned(msg.sender) {
	function verify(bool legit) public pure returns (bool) {
		return legit;
	}
}