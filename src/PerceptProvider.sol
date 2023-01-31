pragma solidity 0.8.17;

/**
 * todo:
 *
 * https://app.diagrams.net/#G1Ie_Xm4E-gJG5_blKtyqz8bFa0BBeJGAl
 *
 * [x] PerceptRegister.sol
 *    [x] add PCT into contract
 *    [x] addModelType()
 *    [x] setModelFee()
 * 				@todo ensure constructor
 * 		[x] proposeModel()
 * 				[x] add verifer
 * 				@todo specify which part should deploy verifier
 * 				@todo  specify who should determine prices (price, & priceCall specified in proposal)
 * 		[x] approveModel()
 * 			  @todo addModelReject onlyOwner (with reason)
 * 		[x] registerModel()
 * 		    @todo Should subscribers be attached to model types & modelIDs?
 * 					* convinent way to return these data, but takes storage&gas & can handle with event
 * 					* also contract can save all subscribers and filter by modelID
 * 		[x] subscriberModel() //aka register if not exist yet
 * 				[x] Subscriber must:
 * 					[x] be a contract type
 * 					[x] approve all PCT to provider
 * 					[x] must pay initial fee
 * 					[x] support callBack interface
 * 					[x] provide modelType that exist
 * 					[x] be attached to desired modelType
 *		  		@todo specify if subscriber can be attached to multiple modelTypes
 * 					@todo should 1-time fee be splitted?
 *
 * [x] PerceptProvider.sol
 * 		[x] sendRequest()
 * 			 @todo specify data type of request (perhaps "struct ModelTypeRequest" mapped to modelType)
 * 			 @todo edit if decide on multiple modelTypes
 * 		[x] receiveResponse()
 * 		[x] verifyResult()
 * 		[x] splitPayment() (after reqeuest data is received, based on the result, split payment)
 * 		[x] sendResult()
 *
 * @todo add option for owner to withdraw ether, tkns (expcept pct that belongs to user)
 * @todo enum 0's will not lead to error
 * @todo add event indexes
 * @todo safeTransferFrom (ensure balances are different)
 * @todo check all ERC20 function (ensure approve will remain near to max)
 * @todo change model proposal fee to PCT (and add test to check if tksn were deducted)
 * @todo add tests for all events
 * @todo perceptNetwork, specify if each modelType should be seperate.
 * @todo make each request unique
 * @todo add verifer to specifc model, not global (and in struct)
 * @todo in split payments consider adding fee to percent
 * @todo ensure fundReceive!=0x0 (in case of selfdestruct)
 * @todo add fail test cases
 * @todo add more secure access control (with multi-step change ownership)
 * @todo discuss percept token tokenomics
 * @todo consider adding EOA & contract subscriber as fee payer (4now only contract aka interactor)
 * @todo consider adding protocl fee as percentage of initialPrice (but also need to take if set to 1 wei to avoid spam)
 */
import "forge-std/Test.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PerceptLibrary} from "./PerceptLibrary.sol";
import {PerceptToken} from "./PerceptToken.sol";

contract PerceptProvider is Owned(msg.sender) {
	PerceptToken pct;
	using PerceptLibrary for PerceptLibrary.Model;
	using PerceptLibrary for PerceptLibrary.ModelStatus;

	string[] public modelTypes; //add to modelType, ids after approved
	uint256 public modelID; //current model amt
	uint256 public requestID;
	uint256 public modelProposalFee;
	uint256 public modelCallFee;
	address public perceptNetwork;
	address public verifier;

	mapping(uint256=>address) public requests;
	mapping(bytes32=>uint256) public modelTypeSubscriptionFees;
	mapping(bytes32 => bool) internal modelType; //bytes32 instead of string for gas optimization
	mapping(bytes32 => uint256[]) public modelTypesIDs; //will allow to view all model types to split payment
	mapping(uint256 => PerceptLibrary.Model) public models;
	mapping(address=>string) public subscribers; //map subscriber to modelType

	event PerceptNetworkChanged(address perceptNetwork);
	event ModelTypeAdded(string modelType);
	event ModelProposalFeeChanged(uint256 proposeModelFee); //to avoid spam
	event ModelTypeSubscriptionFeeChanged(string modelType, uint256 modelTypeSubscriptionFee);
	event ModelProposed(uint256 modelID, PerceptLibrary.Model model); //@todo consider adding each argument separately
	event ModelApproved(uint256 modelID, PerceptLibrary.Model model);
	event ModelRegistered(uint256 modelID, PerceptLibrary.Model model);
	event SubscriberRegistered(address subscriber, string modelType);
	event NewRequest(uint256 id, address subscriber, string modelType, uint256 callFee, bytes data);
	event ReceiveResponse(uint256 id, address subscriber, string modelType, bytes data);
	event PaymentSplitted(uint256 id, address subscriber, string modelType, uint256 callFee);

	constructor(PerceptToken _pct, uint256 _modelProposalFee, address _verifier) {
		pct = _pct;
		setModelProposalFee(_modelProposalFee); //to avoid spam
		modelCallFee = 1 ether;
		verifier = _verifier;
	}

	//getters
	function getPerceptTokenAddress() public view returns (address) {
		return address(pct);
	}

	function modelTypeExists(string memory _modelType) public view returns (bool) {
		return modelType[keccak256(abi.encodePacked(_modelType))];
	}

	function getModelIDsByType(string memory _modelType) public view returns (uint256[] memory) {
		return modelTypesIDs[keccak256(abi.encodePacked(_modelType))];
	}

	function getModelTypeSubscritionFee(string memory _modelType) public view returns (uint256) {
		return modelTypeSubscriptionFees[keccak256(abi.encodePacked(_modelType))];
	}

	//setters
	function setPerceptNetwork(address _perceptNetwork) public onlyOwner {
		require(_perceptNetwork != address(0), "Error: percept network address is invalid");
		perceptNetwork = _perceptNetwork;
		emit PerceptNetworkChanged(perceptNetwork);
	}

	function setModelProposalFee(uint256 _modelProposalFee) public onlyOwner {
		require(_modelProposalFee != modelProposalFee, "Error: model proposal fee is already set to this value");
		modelProposalFee = _modelProposalFee;
		emit ModelProposalFeeChanged(modelProposalFee);
	}

	function setModelTypeSubscriptionFee(string memory _modelType, uint256 _modelSubscriptionFee) public onlyOwner {
		require(validateSetModelTypeSubscriptionFee(_modelType, _modelSubscriptionFee));
		modelTypeSubscriptionFees[keccak256(abi.encodePacked(_modelType))] = _modelSubscriptionFee;
		emit ModelTypeSubscriptionFeeChanged(_modelType, _modelSubscriptionFee);
	}

	function addModelType(string memory _modelType, uint256 _modelTypeSubscriptionFee) public onlyOwner {
		require(!modelTypeExists(_modelType), "Error: model type already exists");
		modelTypes.push(_modelType);
		modelType[keccak256(abi.encodePacked(_modelType))] = true;
		setModelTypeSubscriptionFee(_modelType, _modelTypeSubscriptionFee); //require return true?
		emit ModelTypeAdded(_modelType);
	}

	function proposeModel(PerceptLibrary.Model calldata _model) public payable {
		require(validateModelProposal(_model, msg.value), "Error: proposeModel");

		models[modelID++] = _model;

		// modelID+=1;
		emit ModelProposed(modelID-1, models[modelID]); //@todo consider passing each argument seperately
	}

	function approveModel(uint256 _modelID) public onlyOwner {
		require(models[_modelID].status==PerceptLibrary.ModelStatus.Proposed, "Error: Model is not in proposed state");
		models[_modelID].status = PerceptLibrary.ModelStatus.Approved;
		emit ModelApproved(_modelID, models[_modelID]);
	}

	function registerModel(uint256 _modelID) public {
		require(validateRegisterModel(_modelID), "Error: RegisterModel");
		models[_modelID].status = PerceptLibrary.ModelStatus.Active;
		modelTypesIDs[keccak256(abi.encodePacked(models[_modelID].modelType))].push(_modelID);
		emit ModelRegistered(_modelID, models[_modelID]);
	}

	function subscribeModelType(string memory _modelType) public {
		require(validateSubscriber(_modelType), "Error: subscribeModelType");
		pct.transferFrom(msg.sender, address(this), getModelTypeSubscritionFee(_modelType));
		subscribers[msg.sender] = _modelType;
		emit SubscriberRegistered(msg.sender, _modelType);
	}

	function sendRequest(bytes memory _data) public {
		require(validateSendRequest(_data), "Error: sendRequest");
		pct.transferFrom(msg.sender, address(this), modelCallFee);
		requests[requestID++]=msg.sender;
		emit NewRequest(requestID-1, msg.sender, subscribers[msg.sender], modelCallFee, _data);
	}

	function receiveResponse(uint256 id, bytes memory _data, bool _legit) public {
		require(msg.sender==perceptNetwork, "Error: receiveRequest");
		(bool success, ) = verifier.call(abi.encodeWithSignature("verify(bool)", _legit));
		require(success, "Error: verify");

		requests[id].call(_data);

		//splitPayments
		emit ReceiveResponse(id, requests[id], subscribers[requests[id]], _data);
		splitPayments(id);
	}

	function splitPayments(uint256 id) private {
		console.log('subscribers[requests[id]]', subscribers[requests[id]]);
		uint256[] memory modelIDs = getModelIDsByType(subscribers[requests[id]]);

		for(uint i=0;i<modelIDs.length;i++) {
			address fundReceiver = models[modelIDs[i]].fundReceiver;
			pct.transfer(fundReceiver, modelCallFee/modelIDs.length);
		}

		emit PaymentSplitted(id, requests[id], subscribers[requests[id]], modelCallFee/modelIDs.length);
	}

	//validation
	function validateSetModelTypeSubscriptionFee(string memory _modelType, uint256 _modelSubscriptionFee) public view returns (bool) {
		return (
			modelTypeExists(_modelType) && //modelType exists
			_modelSubscriptionFee>0
		);
	}

	function validateModelProposal(PerceptLibrary.Model calldata _model, uint256 _feeAmount) public view returns (bool) {
		return (
			_feeAmount==modelProposalFee &&
			modelTypeExists(_model.modelType) &&
			_model.proposer==msg.sender &&
			_model.status==PerceptLibrary.ModelStatus.Proposed &&
			_model.price>0 &&
			_model.priceCall>0 &&
			bytes(_model.name).length>0 &&
			bytes(_model.data).length>0 &&
			_model.verifier.code.length>0 && //not addr 0 & only contract
			_model.fundReceiver!=address(0)
		);
	}

	function validateRegisterModel(uint256 _modelID) public view returns (bool) {
		return (
			models[_modelID].status==PerceptLibrary.ModelStatus.Approved &&
			models[_modelID].proposer==msg.sender
		);
	}

	function validateSubscriber(string memory _modelType) public view returns (bool) {
		return (
			modelTypeExists(_modelType) && //modelType exists
			msg.sender.code.length>0 && //is contract
			pct.allowance(msg.sender, address(this))==type(uint256).max && //max allowance to Provider
			bytes(subscribers[msg.sender]).length==0 //not already a subscriber
		);
	}

	function validateSendRequest(bytes memory _data) public view returns (bool) {
		return (
			bytes(subscribers[msg.sender]).length>0 && //is subscriber
			modelTypeExists(subscribers[msg.sender]) && //@todo modelType exists (is above check redundant?)
			_data.length>0
		);
	}
}