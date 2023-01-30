pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/PerceptLibrary.sol";
import "../src/PerceptProvider.sol";
import {Utilities} from "./utils/Utilities.sol";

contract PerceptProviderTest is Test {
	using PerceptLibrary for PerceptLibrary.Model;
	using PerceptLibrary for PerceptLibrary.ModelStatus;

	PerceptProvider perceptProvider;
	Utilities internal utils;

	uint256 internal constant NUM_USERS = 4;
	address[] internal users;
	address internal deployer;
	address internal modelProposer;
	string[] public modelTypes;
	uint modelProposalFee;


	string  validModelName;
	string  validModelType;
	string  validModelData;
	uint256 validModelPrice;
	uint256 validModelPriceCall;
	address validModelProposer;
	address validModelFundReceiver;
	address validModelVerifier;
	PerceptLibrary.ModelStatus validModelStatus;


	function setUp() public {
		utils = new Utilities();
    users = utils.createUsers(NUM_USERS);

		deployer = users[0];
		modelProposer = users[1];

		modelTypes = new string[](3);
		modelTypes[0] = "Liquidity Aggregation";
		modelTypes[1] = "AMM Optimization";
		modelTypes[2] = "DOV Strike Selection";

		modelProposalFee = 1 ether;


		validModelName = "Model0";
		validModelType = modelTypes[0];
		validModelData = 'IPFS LINK';
		validModelPrice = 10 ether;
		validModelPriceCall = 1 ether;
		validModelProposer = modelProposer;
		validModelFundReceiver = modelProposer;
		validModelVerifier = address(1);
		validModelStatus = PerceptLibrary.ModelStatus.Proposed;


		vm.startPrank(deployer);
		perceptProvider = new PerceptProvider(modelProposalFee); //init fee 1 wei
		perceptProvider.addModelTypes(modelTypes);
		vm.stopPrank();
	}

	function testSetModelProposalFee() public {
		vm.startPrank(deployer);
		perceptProvider.setModelProposalFee(modelProposalFee*2);
		assertEq(perceptProvider.modelProposalFee(), modelProposalFee*2);
		vm.stopPrank();
	}

	function testSetModelProposalFeeTheSameFail() public {
		vm.startPrank(deployer);
		vm.expectRevert("Error: model proposal fee is already set to this value"); //onlyOwner
		perceptProvider.setModelProposalFee(modelProposalFee);
		vm.stopPrank();
	}

	function testSetModelProposalFeeUnauthorizedFail() public {
		vm.startPrank(modelProposer);
		vm.expectRevert("UNAUTHORIZED"); //onlyOwner
		perceptProvider.setModelProposalFee(modelProposalFee*2);
		vm.stopPrank();
	}

	function testAddModelTypes() public {
		string[] memory modelTypesAdded = perceptProvider.getModelTypes();
		assertEq(modelTypesAdded[0], modelTypes[0]);
		assertEq(modelTypesAdded[1], modelTypes[1]);
		assertEq(modelTypesAdded[2], modelTypes[2]);
		assertEq(modelTypesAdded.length, modelTypes.length);
	}

	function testAddModelTypesAlreadyExistFail() public {
		vm.startPrank(deployer);
		vm.expectRevert("Error: model type already exists"); //onlyOwner
		perceptProvider.addModelTypes(modelTypes);
		vm.stopPrank();
	}

	function testAddModelTypesUnauthorizedFail() public {
		vm.startPrank(modelProposer);
		vm.expectRevert("UNAUTHORIZED"); //onlyOwner
    perceptProvider.addModelTypes(modelTypes);
		vm.stopPrank();
	}

	function testModelProposal() public {
		vm.startPrank(modelProposer);

		PerceptLibrary.Model memory model = PerceptLibrary.Model(
			validModelName,
			validModelType,
			validModelData,
			validModelPrice,
			validModelPriceCall,
			validModelProposer,
			validModelFundReceiver,
			validModelVerifier,
			validModelStatus
		);

		uint256 modelIndexBefore = perceptProvider.modelIndex();
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		assertEq(perceptProvider.modelIndex(), modelIndexBefore+1);
		vm.stopPrank();
	}

	function testProposeModelFail() public {
		uint256 invalidModelProposalFee = 0;
		string memory invalidModelName = "";
		string memory invalidModelType = "";
		string memory invalidModelData = "";
		uint256 invalidModelPrice = 0;
		uint256 invalidModelPriceCall = 0;
		address invalidModelProposer = address(0);
		address invalidModelFundReceiver = address(0);
		address invalidModelVerifier = address(0);
		PerceptLibrary.ModelStatus invalidModelStatus = PerceptLibrary.ModelStatus.Approved;

		vm.startPrank(modelProposer);
		PerceptLibrary.Model memory model = PerceptLibrary.Model(
			validModelName,
			validModelType,
			validModelData,
			validModelPrice,
			validModelPriceCall,
			validModelProposer,
			validModelFundReceiver,
			validModelVerifier,
			validModelStatus
		);

		perceptProvider.proposeModel{value: modelProposalFee}(model);
		assertEq(perceptProvider.modelIndex(), 1);

		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: invalidModelProposalFee}(model);

		model.name = invalidModelName;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.name = validModelName;

		model.modelType = invalidModelType;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.modelType = validModelType;

		model.data = invalidModelData;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.data = validModelData;

		model.price = invalidModelPrice;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.price = validModelPrice;

		model.priceCall = invalidModelPriceCall;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.priceCall = validModelPriceCall;

		model.proposer = invalidModelProposer;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.proposer = validModelProposer;

		model.fundReceiver = invalidModelFundReceiver;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.fundReceiver = validModelFundReceiver;

		model.verifier = invalidModelVerifier;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.verifier = validModelVerifier;

		model.status = invalidModelStatus;
		vm.expectRevert("Invalid Model parameters");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.status = validModelStatus;

		perceptProvider.proposeModel{value: modelProposalFee}(model);
		assertEq(perceptProvider.modelIndex(), 2);
	}
}