pragma solidity 0.8.17;

library PerceptLibrary {
	enum ModelStatus {
		Proposed,
		Approved,
		Registered,
		Active,
		Disabled
	}

	struct Model{
		// uint256 id; //consider gas optimization
		string name;
		string modelType;
		string data; //possible bytecode of verifier or ipfs link
		uint256 price;
		uint256 priceCall;
		address proposer;
		address fundReceiver;
		address verifier;
		ModelStatus status;
	}
}