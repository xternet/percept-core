pragma solidity 0.8.17;

/**
 * todo: https://app.diagrams.net/#G1Ie_Xm4E-gJG5_blKtyqz8bFa0BBeJGAl
 * 		[ ] Setup
 * 				[x] constructor
 * 						[x] Owner @todo consider adding multi-step ownership change
 * 						[x] add PCT (consider deploying from contract) @todo discuss tokenomics
 * 						[x] setProposalFee() (in PCT)
 * 						[x] perceptVerifier()
 * 						[x] setPerceptNetwork() @todo should each modelType has seperate perceptNetwork? (4now 1x)
 * 								@todo to verifyCall bytecode attach verifier name, to know
 * 								@todo should each modelType has seperate perceptVerifier? (4now 1x)
 * 								@todo establish standard for bytes calldata, verifiers, aggregator, etc.
 * 				[ ] setModelType() @todo shouldn't it only be one time called for each model?
 * 						[x] setSubFee()
 * 						[x] setCallFee()
 * 						[x] deployVerifier()
 * 						[ ] totalBackTestPoints()
 * 						[ ] totalSuccessfullRequestAmt()
 *							@todo merge function name with called bytecode for gas optimization
 * 		[x] Registration:
 * 				[x] proposeModel() @todo consider add to event each data type separetly (instead of struct)
 * 				[x] approveModel()
 * 					[ ] assing backTestPoints
 * 				[ ] activateModel()
 * 				  [ ] ModelType.totalBackTestPoints+=ModelId.backTestpoints
 * 				  [ ] edit "magic" (based on requestAmt)
 * 				[ ] updateModel() perhaps can be implemented into propose
 * 				@todo consider adding removeModel (and perhaps removeModelType)
 * 				[x] subscribeModel()
 * 					@todo should allow EOA to do that (4now only contract can do that)
 * 					@todo can subscribe to multiple modelTypes? (4now 1x)
 * 					@todo unsubscribeModel() ?
 * 		[ ] Execution:
 * 				[x] sendRequest()
 * 						@todo specify type of data request (4now bytes)
 * 						@todo validate bytes (4now just boolean)
 * 				[x] receiveResponse()
 * 						@todo specify type of data response (4now bytes)
 * 						@todo validate bytes for subscriber & verfier (4now just boolean)
 * 				[x] verifyResult()
 * 				[x] sendResult()
 * 				[ ] withdraw()
 * 				[ ] withdraw() owner only
 *    [ ] Rest:
 * 				[ ] events, consider passing each argument seperately instead of struct
 * 				[ ] Reduce amount of variables (esp. mappings)
 * 				[ ] use only single counter for model ids and orders (if modelId exists, then increase, otherwise use counter)
 * 				[ ] testSuccess (get bytecode of modelVerifier) @todo ensure propose mode ids
 * 				[ ] testEvents (consider indexed events)
 * 				[ ] testFail
 * 				[ ] Migrate function to libs, etc.
 * 				[ ] Clean
 * 		[ ] Security&gas optimization:
 * 				[ ] Reentrancy
 * 				[ ] Ensure fundReceiver!=0x0 (in case of future selfdestruct)
 * 				[ ] Ensure ERC20 does not have decreaseAllowance
 * 				[ ] Ensure enum 0's will not lead to error (cuz 0 is default value)
 * 				[ ] Consider adding safeTransferFrom for PCT
 * 				[ ] Compare gas between error msg for each requirement and just "return logic x && y"
 * 				[ ] Fuzz testing
 */
import "forge-std/Test.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PerceptLibrary} from "./PerceptLibrary.sol";
import {PerceptToken} from "./PerceptToken.sol";
import {ZKPVerifierAggregator} from "./ZKPVerifierAggregator.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract PerceptProvider is Owned(msg.sender), ReentrancyGuard {
	PerceptToken pctTkn;
	ZKPVerifierAggregator zkpVerifierAggregator;

	using PerceptLibrary for PerceptLibrary.Model;
	using PerceptLibrary for PerceptLibrary.Request;
	using PerceptLibrary for PerceptLibrary.Response;
	using PerceptLibrary for PerceptLibrary.ModelType;
	using PerceptLibrary for PerceptLibrary.ModelStatus;
	using PerceptLibrary for PerceptLibrary.RequestStatus;

	// string[] public modelTypes; //add to modelType, ids after approved
	// uint256 public modelID; //current model amt
	uint256 public feeProposal;
	uint256 public requestID;
	address public perceptNetwork;

	//mapping verifiers
	// mapping(bytes32=>uint256) internal modelFeeCall;
	mapping(address=>string) public subscriberModelType; //map subscriber to modelType
	// mapping(bytes32=>uint256) internal modelSubscriptionFee;

	// mapping(bytes32 => bool) internal modelType; //bytes32 instead of string for gas optimization
	// mapping(bytes32 => uint256[]) public modelTypeIDs; //will allow to view all model types to split payment
	mapping(bytes32 => PerceptLibrary.ModelType) public modelType;
	mapping(uint256 => PerceptLibrary.Model) public models;
	mapping(uint256 => PerceptLibrary.Request) public request;

	event PctTknDeployed(address pctTkn, uint256 totalSupply);
	event PerceptNetworkUpdated(address oldPerceptNetwork, address newPerceptNetwork);
	event ZKPVerifierAggregatorDeployed(address zkpVerifierAggregatorAddress);
	event ModelTypeVerifierUpdated(string modelType, address oldVerifier, address newVerifier);

	event FeeProposalUpdated(uint256 oldFeeProposal, uint256 newFeeProposal); //spam protection
	event FeeCallUpdated(string modelType, uint256 oldFeeCall, uint256 newFeeCall);
	event FeeSubscriptionUpdated(string modelType, uint256 oldFeeSubscription, uint256 newFeeSubscription);

	event ModelTypeAdded(PerceptLibrary.ModelType modelType);
	event ModelProposed(PerceptLibrary.Model model);
	event ModelApproved(PerceptLibrary.Model model);
	event ModelActivated(PerceptLibrary.Model model);

	event SubscriberRegistered(address subscriber, string modelType);
	event NewRequest(PerceptLibrary.Request request);
	event ResponseReceived(bool verified, uint256 id, address subscriber, string modelType, bytes data);

	constructor(uint256 _totalSupply, address _perceptNetwork, uint256 _feeProposal){
		_setPctTkn(_totalSupply);
	 _setZKPVerifierAggregator();
		setPerceptNetwork(_perceptNetwork);
		setFeeProposal(_feeProposal);
	}

	//getters
	function getPctTknAddr() public view returns (address) {
		return address(pctTkn);
	}

	function getZKPVerifierAggregatorAddr() public view returns (address) {
		return address(zkpVerifierAggregator);
	}

	function getFeeCall(string memory _modelType) public view returns (uint256) {
		return modelType[keccak256(abi.encodePacked(_modelType))].feeCall;
	}

	function getFeeSubscription(string memory _modelType) public view returns (uint256) {
		return modelType[keccak256(abi.encodePacked(_modelType))].feeSubscription;
	}

	function modelTypeExists(string memory _modelType) public view returns (bool) {
		return _modelType==modelType[keccak256(abi.encodePacked(_modelType))].name;
	}

	function getRequest(uint256 _id) public view returns (PerceptLibrary.Request memory) {
		return request[_id];
	}

	// function getModelIDsByType(string memory _modelType) public view returns (uint256[] memory) {
	// 	return modelTypeIDs[keccak256(abi.encodePacked(_modelType))];
	// }

	//setters
	function _setPctTkn(uint256 _totalSupply) internal {
		require(_totalSupply > 0, "Error: total supply is invalid");
		pctTkn = new PerceptToken(_totalSupply);
		emit PctTknDeployed(address(pctTkn), _totalSupply);
	}

	function _setZKPVerifierAggregator() internal {
		zkpVerifierAggregator = new ZKPVerifierAggregator();
		emit ZKPVerifierAggregatorDeployed(address(zkpVerifierAggregator));
	}

	// if want make updatable
	// function setZKPVerifierAggregator(address _newZKPVerifierAggregator) public onlyOwner {
	// 	address oldZKPVerifierAggregator = address(zkpVerifierAggregator);
	// 	require(validatateSetZKPVerifierAggregator(oldZKPVerifierAggregator, _newZKPVerifierAggregator), "Error: ZKPVerifierAggregator address is invalid");
	// 	zkpVerifierAggregator = ZKPVerifierAggregator(_newZKPVerifierAggregator);
	// 	emit ZKPVerifierAggregatorUpdated(oldZKPVerifierAggregator, _newZKPVerifierAggregator);
	// }

	function setPerceptNetwork(address _newPerceptNetwork) public onlyOwner {
		address oldPerceptNetwork = perceptNetwork;
		require(validatateSetPerceptNetwork(oldPerceptNetwork, _newPerceptNetwork), "Error: Percept network address is invalid");
		perceptNetwork = _newPerceptNetwork;
		emit PerceptNetworkUpdated(oldPerceptNetwork, _newPerceptNetwork);
	}

	function setFeeProposal(uint256 _newFeeProposal) public onlyOwner {
		uint256 oldFeeProposal = feeProposal;
		require(oldFeeProposal != _newFeeProposal, "Error: model proposal fee is already set to this value");
		feeProposal = _newFeeProposal;
		emit FeeProposalUpdated(oldFeeProposal, _newFeeProposal);
	}

	function setModelType(PerceptLibrary.ModelType memory _modelType) external onlyOwner {
		require(validateSetModelType(_modelType), "Error: setModelType");

		this.setFeeCall(_modelType.modelType, _modelType.feeCall);
		this.setFeeSubscription(_modelType.name, _modelType.feeSubscription); //require return true?
		this.setModelTypeVerifier(_modelType.name, _modelType.verifierBytecode);
		_setModelType(_modelType);
	}

	function _setModelType(PerceptLibrary.ModelType memory _modelType) private {
		modelType[keccak256(abi.encodePacked(_modelType.name))] = _modelType;
		emit ModelTypeAdded(_modelType);
	}

	function setFeeCall(string memory _modelType, uint256 _newFeeCall) external onlyOwner {
		uint256 __oldFeeCall = getFeeCall(_modelType);
		require(validateSetFeeCall(_modelType, __oldFeeCall, _newFeeCall), "Error: setFeeCall");
		_setFeeCall(_modelType, __oldFeeCall, _newFeeCall);
	}

	function _setFeeCall(string memory _modelType, uint256 _oldFeeCall, uint256 _newFeeCall) private {
		modelType[keccak256(abi.encodePacked(_modelType))].feeCall = _newFeeCall;
		emit FeeCallUpdated(_modelType, _oldFeeCall, _newFeeCall);
	}

	function setFeeSubscription(string memory _modelType, uint256 _newSubscriptionFee) external onlyOwner {
		uint256 __oldSubscriptionFee = getFeeSubscription(_modelType);
		require(validateSetFeeSubscription(_modelType, __oldSubscriptionFee, _newSubscriptionFee), "Error: setFeeSubscription");
		_setFeeSubscription(_modelType, __oldSubscriptionFee, _newSubscriptionFee);
	}

	function _setFeeSubscription(string memory _modelType, uint256 _oldSubscriptionFee, uint256 _newSubscriptionFee) private {
		modelType[keccak256(abi.encodePacked(_modelType))].feeSubscription = _newSubscriptionFee;
		emit FeeSubscriptionUpdated(_modelType, _oldSubscriptionFee, _newSubscriptionFee);
	}

	function setModelTypeVerifier(string memory _modelType, bytes calldata _bytecode) external onlyOwner {
		require(validateSetModelTypeVerifier(_modelType, _bytecode), "Error: setModelTypeVerifier");

		address __oldVerifier = zkpVerifierAggregator.getVerifierAddr(_modelType);
	  address __newVerifier = zkpVerifierAggregator.deployNewModelVerifier(_modelType, _bytecode); //addr 0 checked in aggegator

	 	emit ModelTypeVerifierUpdated(_modelType, __oldVerifier, __newVerifier);
	}

	//Registrations
	function proposeModel(PerceptLibrary.Model calldata _model) external {
		require(validateProposeModel(_model), "Error: proposeModel");
		models[modelID++] = _model; //add new model
		models[modelID-1].id = modelID-1; //set id in Struct
		emit ModelProposed(models[modelID-1]);
	}

	function approveModel(uint256 _modelID) external onlyOwner {
		require(models[_modelID].status==PerceptLibrary.ModelStatus.Proposed, "Error: Model is not in Proposed state");
		models[_modelID].status = PerceptLibrary.ModelStatus.Approved;
		emit ModelApproved(models[_modelID]);
	}

	function activateModel(uint256 _modelID) external {
		require(validateActivateModel(_modelID), "Error: activateModel");
		models[_modelID].status = PerceptLibrary.ModelStatus.Active;
		modelTypeIDs[keccak256(abi.encodePacked(models[_modelID].modelType))].push(_modelID);
		emit ModelActivated(models[_modelID]);
	}

	function subscribeModelType(string memory _modelType) external {
		require(validateSubscribeModelType(_modelType), "Error: subscribeModelType");
		pctTkn.transferFrom(msg.sender, address(this), getFeeSubscription(_modelType));
		subscriberModelType[msg.sender] = _modelType;
		emit SubscriberRegistered(msg.sender, _modelType);
	}

	function sendRequest(PerceptLibrary.Request calldata _request) external nonReentrant returns (uint256) {
		require(validateSendRequest(_request), "Error: sendRequest");

		request[_request.id]=_request;

		emit NewRequest(_request);
		return requestID++;
	}

	function receiveResponse(PerceptLibrary.Response calldata _response) external nonReentrant returns (bool __verified){
		PerceptLibrary.Request storage __request = request[_response.id];
		require(validateReceiveResponse(_response, __request), "Error: receiveResponse");

		__verified = zkpVerifierAggregator.verify(_response);
		_updateRequestStatus(__verified, __request);

		__verified ? _fowardResponse(_response) : _returnFeeCall(_response);
		emit ResponseReceived(__request, _response);
	}

	function _updateRequestStatus(bool _verified, PerceptLibrary.Response calldata _request) internal {
		_verified ?
			_request.status = PerceptLibrary.RequestStatus.Success:
			_request.status = PerceptLibrary.RequestStatus.Failure;
	}

	function _fowardResponse(PerceptLibrary.Response memory _response) private {
		_response.subscriber.call(_response.dataResponse); //skip success check to protect from DoS attack
	}

	function _returnFeeCall(PerceptLibrary.Response memory _response) private {
		pctTkn.transfer(_response.subscriber, getFeeCall(_response.modelType));
	}

	function withdraw(string memory _modelType) external { //ensure risks with reentrancy & modelAdd/update
		/**
		 * calc. based on:
		 * - "x" = amt of participated request calls
		 * - "y" = backTestPoints
		 * - "z" = global var, that:
		 * 			1. calc. if modelType added/updated.
		 * 			2. accounts "modelType[backTestPoints]"
		 * 			3. accounts "modelType[requestID]"
		 *
		 * then, withdraw & reset "x".
		 */
	}

	//validation
	function validatateSetPerceptNetwork(address _oldPerceptNetwork, address _newPerceptNetwork) internal view returns (bool) {
		return (
			_oldPerceptNetwork!=_newPerceptNetwork &&
			_newPerceptNetwork!=address(0)
		);
	}

	function validatateSetZKPVerifierAggregator(address _oldZKPVerifierAggregator, address _newZKPVerifierAggregator) internal view returns (bool) {
		return (
	 		_newZKPVerifierAggregator.code.length > 0 &&
			// _newZKPVerifierAggregator != address(0) && //not2safe as code.length > 0?
			// _newZKPVerifierAggregator != address(this) && //owner can change
			// _newZKPVerifierAggregator != address(pctTkn) && //owner can change
			_newZKPVerifierAggregator != _oldZKPVerifierAggregator
		);
	}

	function validateSetFeeCall(string memory _modelType, uint256 _oldFeeCall, uint256 _newFeeCall) internal view returns (bool) {
		return (
			modelTypeExists(_modelType) &&
			_oldFeeCall!=_newFeeCall
		);
	}

	function validateSetFeeSubscription(string memory _modelType, uint256 _oldSubscriptionFee, uint256 _newSubscriptionFee) internal view returns (bool) {
		return (
			modelTypeExists(_modelType) &&
			_oldSubscriptionFee!=_newSubscriptionFee
		);
	}

	function validateSetModelTypeVerifier(string memory _modelType, bytes calldata _bytecode) internal pure returns (bool) {
		return(
			bytes(_modelType).length > 0 &&
			_bytecode.length > 0
		);
	}

	function validateSetModelType(PerceptLibrary.ModelType calldata _modelType) internal view returns (bool) {
		return (
			!modelTypeExists(_modelType.name) &&
			_modelType.name.length>0 &&
			_modelType.feeCall > 0 &&
			_modelType.feeSubscription > 0 &&
			_modelType.totalBacktestPoints==0 &&
			_modelType.totalSuccessfulRequests==0 &&
			_modelType.verifierBytecode.length > 0 &&
			_modelType.modelIDs.length==0
		);
	}

	function validateProposeModel(PerceptLibrary.Model calldata _model) internal view returns (bool) {
		return (
			// _model.id == modelID && //4now is set in function
			pctTkn.transferFrom(msg.sender, address(this), feeProposal) &&
			_model.owner==msg.sender &&
			_model.data.length > 0 &&
			modelTypeExists(_model.modelType) &&
			_model.status==PerceptLibrary.ModelStatus.Proposed
		);
	}

	function validateActivateModel(uint256 _modelID) internal view returns (bool) {
		return (
			models[_modelID].status==PerceptLibrary.ModelStatus.Approved &&
			models[_modelID].proposer==msg.sender
		);
	}

	function validateSubscribeModelType(string memory _modelType) internal view returns (bool) {
		return (
			modelTypeExists(_modelType) && //modelType exists
			msg.sender.code.length>0 && //is contract after construction
			// pctTkn.allowance(msg.sender, address(this))==type(uint256).max && //transferFrom will revert
			bytes(subscriber[msg.sender]).length==0 //not already a subscriber
		);
	}

	function validateSendRequest(PerceptLibrary.Request calldata _request) internal view returns (bool) {
		return(
			_request.id==requestID &&
			_request.subscriber==msg.sender &&
			modelTypeExists(_request.modelType) &&
			_request.modelType==subscriberModelType[msg.sender] &&
			_request.status==PerceptLibrary.RequestStatus.Pending &&
			_request.dataRequest.length>0
		);
	}

	function validateReceiveResponse(
		PerceptLibrary.Response calldata _response,
		PerceptLibrary.Request calldata _request
	) internal view returns (bool) {
		return ( //n0t2s4fu?
			_response.subscriber!=address(0) &&
			msg.sender==perceptNetwork &&
			_response.proof.length>0 &&
			_response.dataResponse.length>0 &&
			_response.id==_request.id &&
			_response.modelType==_request.modelType &&
			_response.subscriber==_request.subscriber &&
			_response.subscriber==_request.subscriber &&
			_response.dataRequest==_request.dataRequest &&
			_request.status==PerceptLibrary.RequestStatus.Pending
		);
	}
}