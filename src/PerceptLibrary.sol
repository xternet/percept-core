pragma solidity 0.8.17;

library PerceptLibrary {
	enum ModelStatus {
		Proposed,
		Approved,
		Active
	}

	struct Model {
		uint256 id;
		address owner; //aka fund receiver
		string data; //possible bytecode of verifier or ipfs link
		string modelType;
		uint256 backTestPoints;
		uint256 lastRequestID;
		ModelStatus status;
	}

	struct ModelType {
		string name;
		uint256 feeCall;
		uint256 feeSubscription;
		uint256 totalBacktestPoints;
		uint256 totalSuccessfulRequests; //successful
		bytes verifierBytecode;
		uint256[] modelIDs;
	}

	enum RequestStatus {
		Pending,
		Success,
		Failure
	}

	struct Request {
		uint256 id;
		address subscriber;
		string modelType;
		bytes dataRequest;
		RequestStatus status;
	}

	struct Response {
		uint256 id;
		address subscriber;
		string modelType;
		bytes dataRequest;
		bytes dataResponse;
		bytes proof;
	}

	// struct Request { //dont see the reason to store it, yet
	// 	uint256 id;
	// 	address subscriber;
	// 	string modelType;
	// 	bytes data;
	// 	uint256 timestamp;
	// }
}

/* 					modelTypesIDs = { //to view models id of each type
	* 						type1:
	* 							[
	* 								modelID1,
	* 								...
	* 								modelID2
	* 						],
	* 					  ...
	* 						typeN:
	* 							[
	* 								modelIDN-1,
	* 								...
	* 								modelIDN
	* 						]
	* 					}
**/