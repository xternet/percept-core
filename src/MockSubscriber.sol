pragma solidity 0.8.17;

import "forge-std/Test.sol";

contract MockSubscriber {
	address public perceptProvider;
	constructor(address _perceptProvider, address _perceptToken) {
		perceptProvider = _perceptProvider;
		(bool success, ) = _perceptToken.call(abi.encodeWithSignature("approve(address,uint256)", _perceptProvider, type(uint256).max));
		require(success, "Error: PCT approve");
	}

	fallback() external {
		if(msg.sender==perceptProvider) {
			// logic...
			console.log('in fallback');
		}
	}

	function subscribeModelType(string memory _modelType) public {
		(bool success, ) = perceptProvider.call(abi.encodeWithSignature("subscribeModelType(string)", _modelType));
		require(success, "Error: subscribeModelTypePercept");
	}

	function sendRequest(bytes memory _data) public {
		(bool success, ) = perceptProvider.call(abi.encodeWithSignature("sendRequest(bytes)", _data));
		require(success, "Error: sendRequestPercept");
	}
}