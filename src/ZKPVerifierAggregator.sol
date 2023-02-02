pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
import {PerceptLibrary} from "./PerceptLibrary.sol";

contract ZKPVerifierAggregator is Owned(msg.sender){ //aka provider
	using PerceptLibrary for PerceptLibrary.Response;
	event VerifierDeployed(address _newModelVerifier);
	event VerifierResult(bool result, PerceptLibrary.Response response);

	function deployVerifier(bytes memory _bytecode)	external onlyOwner returns (address __verifier) {
		assembly { //consider using CREATE2 to avoid collisions
			__verifier := create(0, add(_bytecode, 0x20), mload(_bytecode))
			if iszero(extcodesize(__verifier)) {
				revert(0, 0)
			}
		}
		require(__verifier != address(0), "PerceptZKPVerifierAggregator: failed to deploy new model verifier"); //n01254f3?
		emit VerifierDeployed(__verifier);
		return __verifier;
	}

	function verify(PerceptLibrary.Response memory _response) external onlyOwner returns (bool) {
		(bool __success, bytes memory __data) = _response.verifier.call(_response.proof);
		(bool __legit) = abi.decode(__data, (bool));
		emit VerifierResult(__legit, _response);
		return __success && __legit;
	}

	//e.g.:
	// function verify(string memory _modelType, bytes memory _proof, bytes memory _inputs) public view returns (bool) {
	// 	(address _verifier, bytes memory _callData) = abi.decode(_proof, (address, bytes));
	// 	require(_verifier == modelVerifier[keccak256(abi.encodePacked(_modelType))], "ZKPVerifierAggregator: invalid verifier");
	// 	(bool success, bytes memory result) = _verifier.staticcall(_callData);
	// 	require(success, "ZKPVerifierAggregator: failed to call verifier");
	// 	return abi.decode(result, (bool));
	// }
}