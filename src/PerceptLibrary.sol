pragma solidity 0.8.17;

library PerceptLibrary {
	struct Model {
		string name;
		string data;
		address verifier;
		uint256 feeCall;
		uint256 feeSubscription;
		uint256 amtVerifiedCalls;
		bytes verifierBytecode;
	}

	enum RequestStatus {
		Pending,
		Success,
		Failure
	}

	struct Request {
		uint256 id;
		address subscriber;
		string model;
		bytes dataRequest;
		RequestStatus status;
	}

	struct Response {
		uint256 id;
		address subscriber;
		string model;
		bytes dataRequest;
		bytes dataResponse;
		address verifier;
		bytes proof;
	}
}