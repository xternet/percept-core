pragma solidity 0.8.17;

/**
 * todo:
 *
 * https://app.diagrams.net/#G1Ie_Xm4E-gJG5_blKtyqz8bFa0BBeJGAl
 *
 * [ ] PerceptRegister.sol
 *    [x] addModelType()
 *    [x] setModelFee()
 * 		[ ] add verifer
 * 		[ ] proposeModel()
 * 			[ ] test Emit
 * 			[ ] verifer should be already deployed, with specific interface and access control for provider
 * 		[ ] approveModel()
 * 		[ ] registerModel()
 * 			[ ] deployVerifier()
 * 		[ ] registerSubscriber()
 * 		[ ] subscribeModel()
 *
 * [ ] PerceptProvider.sol
 * 		[ ] addRequest()
 * 		[ ] receiveResponse()
 * 		[ ] verifyResult()
 * 		[ ] splitPayment()
 * 		[ ] updateRegister()
 * 		[ ] sendRequestResult()
 *
 * //add option to withdraw ether, funds, etc.
 *
 * //after POC
 * [ ] add more secure access control (with multi-step change ownership)
 */
// import "./PerceptRegister.sol";
import "forge-std/Test.sol";
// import console log forge
import {Owned} from "solmate/auth/Owned.sol";
import {PerceptLibrary} from "./PerceptLibrary.sol";

contract PerceptProvider is Owned(msg.sender) {
	using PerceptLibrary for PerceptLibrary.Model;
	using PerceptLibrary for PerceptLibrary.ModelStatus;

	string[] public modelTypes;
	mapping(bytes32 => bool) internal modelType; //bytes32 instead of string for gas optimization

	uint256 public modelIndex;
	uint256 public modelProposalFee;
	mapping(uint256 => PerceptLibrary.Model) public models;

	event ModelTypeAdded(string modelType);
	event ModelProposalFeeChanged(uint256 proposeModelFee);
	event ModelProposed(PerceptLibrary.Model);
	// event ModelProposed(
	// 	uint256 _modelIndex,
	// 	string name,
	// 	string modelType,
	// 	string data, //possible bytecode of verifier or ipfs link
	// 	uint256 price,
	// 	uint256 priceCall,
	// 	address proposer,
	// 	address fundReceiver,
	// 	address verifier,
	// 	PerceptLibrary.ModelStatus
	// );

	constructor(uint256 _modelProposalFee) {
		setModelProposalFee(_modelProposalFee);
	}

	function setModelProposalFee(uint256 _modelProposalFee) public onlyOwner {
		require(_modelProposalFee != modelProposalFee, "Error: model proposal fee is already set to this value");
		modelProposalFee = _modelProposalFee;
		emit ModelProposalFeeChanged(modelProposalFee);
	}

	function addModelTypes(string[] memory _modelTypes) public onlyOwner {
		for (uint256 i = 0; i < _modelTypes.length; i++) {
			require(!getModelType(_modelTypes[i]), "Error: model type already exists");
			modelTypes.push(_modelTypes[i]);
			modelType[keccak256(abi.encodePacked(_modelTypes[i]))] = true;
			emit ModelTypeAdded(_modelTypes[i]);
		}
	}

	function getModelType(string memory _modelType) public view returns (bool) {
		return modelType[keccak256(abi.encodePacked(_modelType))];
	}

	function getModelTypes() public view returns (string[] memory) {
		return modelTypes;
	}

	function proposeModel(PerceptLibrary.Model calldata _model) public payable {
		require(validateModelProposal(_model, msg.value), "Invalid Model parameters");

		models[modelIndex++] = PerceptLibrary.Model( //check if here increase globally
			_model.name,
			_model.modelType,
			_model.data,
			_model.price,
			_model.priceCall,
			_model.proposer,
			_model.fundReceiver,
			_model.verifier,
			_model.status
		);

		emit ModelProposed(models[modelIndex-1]);
		// PerceptLibrary.Model memory newModel = models[modelIndex-1]; //not to safe?

		// emit ModelProposed(
		// 	modelIndex-1,
		// 	newModel.name,
		// 	newModel.modelType,
		// 	newModel.data,
		// 	newModel.price,
		// 	newModel.priceCall,
		// 	newModel.proposer,
		// 	newModel.fundReceiver,
		// 	newModel.verifier,
		// 	newModel.status
		// );
	}

	function validateModelProposal(PerceptLibrary.Model calldata _model, uint256 _feeAmount) public view returns (bool) {
		return (
			_feeAmount==modelProposalFee &&
			getModelType(_model.modelType) &&
			_model.proposer==msg.sender &&
			_model.status==PerceptLibrary.ModelStatus.Proposed &&
			_model.price>0 &&
			_model.priceCall>0 &&
			bytes(_model.name).length>0 &&
			bytes(_model.data).length>0 &&
			_model.verifier!=address(0) &&
			_model.fundReceiver!=address(0)
		);
	}
}