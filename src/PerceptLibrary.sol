pragma solidity 0.8.17;

library PerceptLibrary {
	enum ModelStatus {
		Proposed,
		Approved,
		Active,
		Rejected,
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