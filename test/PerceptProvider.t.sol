pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/Verifier.sol";
import "../src/PerceptToken.sol";
import "../src/PerceptLibrary.sol";
import "../src/PerceptProvider.sol";
import "../src/MockSubscriber.sol";
import {Utilities} from "./utils/Utilities.sol";

contract PerceptProviderTest is Test {
	using PerceptLibrary for PerceptLibrary.Model;
	using PerceptLibrary for PerceptLibrary.ModelStatus;

	Utilities utils;
	Verifier verifier;
	PerceptToken perceptToken;
	MockSubscriber mockSubscriber;
	PerceptProvider perceptProvider;

	uint256 internal constant NUM_USERS = 4;
	address[] internal users;
	address internal deployer;
	address internal modelProposer;
	address internal subscriber;
	address internal perceptNetwork;

	string public modelType;
	uint256 public modelTypeSubscriptonFee;

	uint256 modelProposalFee;
	uint256 modelSubcriptionFee;

	string  validModelName;
	string  validModelType;
	string  validModelData;
	uint256 validModelPrice;
	uint256 validModelPriceCall;
	address validModelProposer;
	address validModelFundReceiver;
	address validModelVerifier;
	PerceptLibrary.ModelStatus validModelStatus;

	event ModelProposed(PerceptLibrary.Model);
	event NewRequest(uint256 id, address subscriber, string modelType, uint callFee, bytes data);
	event Transfer(address indexed from, address indexed to, uint256 amount);

	function setUp() public {
		utils = new Utilities();
    users = utils.createUsers(NUM_USERS);

		deployer = users[0];
		modelProposer = users[1];
		subscriber = users[2];
		perceptNetwork = users[3];

		modelProposalFee = 1 ether;
		modelSubcriptionFee = 1 ether;

		modelType = "DOV Strike Selection";

		vm.startPrank(modelProposer);
		verifier = new Verifier();
		vm.stopPrank();

		vm.startPrank(deployer);
		perceptToken = new PerceptToken();
		perceptProvider = new PerceptProvider(perceptToken, modelProposalFee, address(verifier)); //init fee 1 wei
		perceptProvider.addModelType(modelType, modelSubcriptionFee);
		perceptProvider.setPerceptNetwork(perceptNetwork);
		vm.stopPrank();

		vm.startPrank(subscriber);
		mockSubscriber = new MockSubscriber(address(perceptProvider), address(perceptToken));
		vm.stopPrank();

		vm.startPrank(deployer);
		perceptToken.transfer(modelProposer, 100 ether);
		perceptToken.transfer(address(mockSubscriber), 100 ether);
		vm.stopPrank();

		validModelName = "Model0";
		validModelType = modelType;
		validModelData = 'IPFS LINK';
		validModelPrice = 10 ether;
		validModelPriceCall = 1 ether;
		validModelProposer = modelProposer;
		validModelFundReceiver = modelProposer;
		validModelVerifier = address(verifier);
		validModelStatus = PerceptLibrary.ModelStatus.Proposed;

	}
	function testVerify() public {
		assertEq(verifier.verify(true), true);
		assertEq(verifier.verify(false), false);
	}

	function testPerceptNetwork() public {
		assertEq(perceptProvider.perceptNetwork(), perceptNetwork);
	}

	function testMockSubscriber() public {
		assertEq(mockSubscriber.perceptProvider(), address(perceptProvider));
		assertEq(perceptToken.balanceOf(address(mockSubscriber)), 100 ether);
		assertEq(perceptToken.allowance(address(mockSubscriber), address(perceptProvider)), type(uint256).max);
	}
	function testSetModelProposalFee() public {
		vm.startPrank(deployer);
		perceptProvider.setModelProposalFee(modelProposalFee*2);
		assertEq(perceptProvider.modelProposalFee(), modelProposalFee*2);
		vm.stopPrank();
	}

	function testAddModelType() public {
		assertEq(perceptProvider.modelTypeExists(modelType), true);
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

		uint256 modelIDBefore = perceptProvider.modelID();
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		assertEq(perceptProvider.modelID(), modelIDBefore+1);
		// assertEq(perceptToken.balanceOf(modelProposer), 100 ether - modelProposalFee);
		vm.stopPrank();
	}

	function testApproveModel() public {
		testModelProposal();

		vm.startPrank(deployer);
		perceptProvider.approveModel(0);
		(,,,,,,,,PerceptLibrary.ModelStatus status) = perceptProvider.models(0);

		assertEq(uint8(status), uint8(PerceptLibrary.ModelStatus.Approved));
		vm.stopPrank();
	}

	function testRegisterModel() public {
		testApproveModel();

		vm.startPrank(modelProposer);
		perceptProvider.registerModel(0);
		(,,,,,,,,PerceptLibrary.ModelStatus status) = perceptProvider.models(0);

		uint256[] memory modelIDs = perceptProvider.getModelIDsByType(validModelType);

		assertEq(uint8(status), uint8(PerceptLibrary.ModelStatus.Active));
		vm.stopPrank();
	}

	function testRegisterModels() public {
		testRegisterModel();
		testModelProposal();

		//approve @todo create functions approve & register to reuse by providing params
		vm.startPrank(deployer);
		perceptProvider.approveModel(1);
		(,,,,,,,,PerceptLibrary.ModelStatus statusApproved) = perceptProvider.models(1);
		assertEq(uint8(statusApproved), uint8(PerceptLibrary.ModelStatus.Approved));
		vm.stopPrank();

		//register
		vm.startPrank(modelProposer);
		perceptProvider.registerModel(1);
		(,,,,,,,,PerceptLibrary.ModelStatus statusActive) = perceptProvider.models(1);

		uint256[] memory validModelTypeModelIDs = perceptProvider.getModelIDsByType(validModelType);

		assertEq(validModelTypeModelIDs.length, 2);
		assertEq(uint8(statusActive), uint8(PerceptLibrary.ModelStatus.Active));
		vm.stopPrank();
	}

	function testSubscribeModelType() public {
		testRegisterModel();

		vm.startPrank(subscriber);
		mockSubscriber.subscribeModelType(validModelType);
		vm.stopPrank();

		assertEq(perceptProvider.subscribers(address(mockSubscriber)), validModelType);
	}

	function testSendRequest() public {
		testSubscribeModelType();

		vm.startPrank(subscriber);

		vm.expectEmit(true, true, true, true);
		emit NewRequest(0, address(mockSubscriber), validModelType, validModelPriceCall, bytes("1"));
		mockSubscriber.sendRequest(bytes("1"));

		assertEq(perceptToken.balanceOf(address(mockSubscriber)), 100 ether - validModelPriceCall - modelSubcriptionFee);
		vm.stopPrank();
	}
	function testReceiveResponse() public {
		testSendRequest();

		vm.startPrank(perceptNetwork);
		uint balanceBefore = perceptToken.balanceOf(address(perceptProvider));
		perceptProvider.receiveResponse(0, bytes("1"), true);
		vm.stopPrank();

		assertGe(balanceBefore, perceptToken.balanceOf(address(perceptProvider)));
		//@todo check balances of multiple model creators (b4 create them)
	}

	function testAddModelTypeAlreadyExistFail() public {
		vm.startPrank(deployer);
		vm.expectRevert("Error: model type already exists"); //onlyOwner
		perceptProvider.addModelType(modelType, modelTypeSubscriptonFee);
		vm.stopPrank();
	}

	function testAddModelTypeUnauthorizedFail() public {
		vm.startPrank(modelProposer);
		vm.expectRevert("UNAUTHORIZED"); //onlyOwner
    perceptProvider.addModelType(modelType, modelTypeSubscriptonFee);
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
		assertEq(perceptProvider.modelID(), 1);

		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: invalidModelProposalFee}(model);

		model.name = invalidModelName;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.name = validModelName;

		model.modelType = invalidModelType;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.modelType = validModelType;

		model.data = invalidModelData;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.data = validModelData;

		model.price = invalidModelPrice;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.price = validModelPrice;

		model.priceCall = invalidModelPriceCall;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.priceCall = validModelPriceCall;

		model.proposer = invalidModelProposer;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.proposer = validModelProposer;

		model.fundReceiver = invalidModelFundReceiver;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.fundReceiver = validModelFundReceiver;

		model.verifier = invalidModelVerifier;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.verifier = validModelVerifier;

		model.status = invalidModelStatus;
		vm.expectRevert("Error: proposeModel");
		perceptProvider.proposeModel{value: modelProposalFee}(model);
		model.status = validModelStatus;

		perceptProvider.proposeModel{value: modelProposalFee}(model);
		assertEq(perceptProvider.modelID(), 2);
	}
}