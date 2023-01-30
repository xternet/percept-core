// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;

import "./Verifier.sol";
import {Owned} from "solmate/auth/Owned.sol";


contract PerceptRegister is Owned {

	struct Model {
		string name;
		address verifier;
	}

	//array of bytes32
	bytes32[] public modelTypes;

	//constructor with initial model types as input
	constructor(bytes32[] memory _modelTypes) {
		modelTypes = _modelTypes;
	}

	// constructor() {
	// 	// modelTypes[0] = bytes32(keccak256("Liquidity Aggregation"));
	// 	// modelTypes[1] = bytes32(keccak256("AMM Optimization"));
	// 	// modelTypes[2] = bytes32(keccak256("DOV Strike Selection"));
	// }

	//create function that will add model types to the array only owner


	function proposeModel() public {
	}
}