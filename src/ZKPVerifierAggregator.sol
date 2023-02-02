pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
//import Percept Library
import {PerceptLibrary} from "./PerceptLibrary.sol";

contract ZKPVerifierAggregator is Owned(msg.sender){ //aka provider
	mapping(bytes32=>address) internal modelVerifier;

	event ModelVerifierDeployed(string _modelType, address _newModelVerifier);

	function getVerifierAddr(string memory _modelType) public view returns (address) {
		return modelVerifier[keccak256(abi.encodePacked(_modelType))];
	}

	//allows to update existing verifier
	function deployNewModelVerifier(string memory _modelType, bytes memory _bytecode)	external onlyOwner returns (address __newModelVerifier) {
		require(validateDeployNewModelVerifier(_modelType, _bytecode), "PerceptZKPVerifierAggregator: invalid deploy call");
		//consider using CREATE2 to avoid collisions
		assembly {
			__newModelVerifier := create(0, add(_bytecode, 0x20), mload(_bytecode))
			if iszero(extcodesize(__newModelVerifier)) {
				revert(0, 0)
			}
		}

		require(__newModelVerifier != address(0), "PerceptZKPVerifierAggregator: failed to deploy new model verifier"); //not2safe?
		modelVerifier[keccak256(abi.encodePacked(_modelType))] = __newModelVerifier;

		emit ModelVerifierDeployed(_modelType, __newModelVerifier);
		return __newModelVerifier;
	}

	function verify(string memory _modelType, bytes calldata _data) external onlyOwner view returns (bool) {
		address addrVerifier = getVerifierAddr(_modelType);
		require(validateverify(addrVerifier, _data), "PerceptZKPVerifierAggregator: invalid verify call");
		(bool success, bytes memory data) = addrVerifier.staticcall(_data); //if action will modify verifier's state, use "call".
		(bool legit) = abi.decode(data, (bool));
		return success && legit;
	}

	function validateDeployNewModelVerifier(string memory _modelType, bytes memory _bytecode) internal pure returns (bool) {
		return (
			keccak256(abi.encodePacked(_modelType)) != keccak256(abi.encodePacked("")) &&
			_bytecode.length > 0
		);
	}

	function validateverify(address _addrVerifier, bytes memory _data) internal pure returns (bool) {
		(bytes4 sig, bytes memory args) = abi.decode(_data, (bytes4, bytes));
		return (
			_addrVerifier != address(0) &&
			sig == bytes4(keccak256("verify(bool)")) && //@todo change based on standard
			abi.decode(args, (bool))
		);
	}

	// function verify(string memory _modelType, bytes memory _proof, bytes memory _inputs) public view returns (bool) {
	// 	(address _verifier, bytes memory _callData) = abi.decode(_proof, (address, bytes));
	// 	require(_verifier == modelVerifier[keccak256(abi.encodePacked(_modelType))], "ZKPVerifierAggregator: invalid verifier");
	// 	(bool success, bytes memory result) = _verifier.staticcall(_callData);
	// 	require(success, "ZKPVerifierAggregator: failed to call verifier");
	// 	return abi.decode(result, (bool));
	// }
}