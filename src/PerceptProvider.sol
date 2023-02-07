//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * todo: https://app.diagrams.net/#G1Ie_Xm4E-gJG5_blKtyqz8bFa0BBeJGAl
 * 		[x] Setup
 * 				[x] constructor
 * 						[x] deployPctTkn
 * 						[x] setPerceptNetwork()
 * 		[x] Registration:
  * 			[x] setModel
	* 					[x] Deploy verifier contract from circom
  * 					[ ] @todo EZKL verification contract
 * 				[x] subscribeModel 4now 1 subscriber=1 model
 * 		[x] Execution:
 * 				[x] sendRequest()
 * 				[x] response()
 * 					 [x] verifyResult()
 * 					 [x] sendResult() @todo specify gasLeft
 *				[ ] withdraw() @todo ML marketplace
 *
 * 		[ ] Security&Optimization&Others:
 * 				[ ] Vulns. list.
 * 				[ ] More unit tests
 *  			[ ] Fuzz testing
 * 				[ ] Ensure pctTkn fundReceiver!=0x0 (in case of future selfdestruct)
 *        [ ] events (indexed, arguments seperately or struct)
 * 				[ ] Compare gas between error msg for each "require" and just "return logic x && y"
 */

import "forge-std/Test.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PerceptLibrary} from "./PerceptLibrary.sol";
import {PerceptToken} from "./PerceptToken.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract PerceptProvider is Owned(msg.sender), ReentrancyGuard {
  PerceptToken pctTkn;

  using PerceptLibrary for PerceptLibrary.Model;
  using PerceptLibrary for PerceptLibrary.Request;
  using PerceptLibrary for PerceptLibrary.Response;
  using PerceptLibrary for PerceptLibrary.RequestStatus;

  uint256 public requestID;
  address public perceptNetwork;

  mapping(bytes32=> PerceptLibrary.Model) internal subscriber;
  mapping(bytes32 => PerceptLibrary.Model) internal model;
  mapping(bytes32 => PerceptLibrary.Request) internal request;

  event PctTknDeployed(address pctTkn, uint256 totalSupply);
  event PerceptNetworkUpdated(address oldPerceptNetwork, address newPerceptNetwork);
	event VerifierDeployed(string model, address verifierAddress);

  event ModelAdded(PerceptLibrary.Model model);
  event SubscriberRegistered(address subscriber, PerceptLibrary.Model model);
  event NewRequest(PerceptLibrary.Request request);
  event ResponseReceived(bool verified, PerceptLibrary.Request request, PerceptLibrary.Response response);

  constructor(uint256 _totalSupply, address _perceptNetwork){
		_setPctTkn(_totalSupply);
		setPerceptNetwork(_perceptNetwork);
  }

  receive() external payable {
  	revert("PerceptError: contract does not accept ETH");
  }

  //getters
  function getPctTknAddr() external view returns (address) {
  	return address(pctTkn);
  }

	function getRequestID() external view returns (uint256) {
		return requestID;
	}
	function getPerceptNetwork() external view returns (address) {
		return perceptNetwork;
	}

  function getModel(string memory _model) external view returns (PerceptLibrary.Model memory) {
  	return model[keccak256(abi.encodePacked(_model))];
  }

  function getSubscriberModel(address _subscriber) public view returns (PerceptLibrary.Model memory) {
  	return subscriber[keccak256(abi.encodePacked(_subscriber))];
  }

  function getRequest(uint256 _id) external view returns (PerceptLibrary.Request memory) {
  	return request[keccak256(abi.encodePacked(_id))];
  }

  function getFeeCall(string memory _model) public view returns (uint256) {
  	return model[keccak256(abi.encodePacked(_model))].feeCall;
  }

  function getFeeSubscription(string memory _model) public view returns (uint256) {
  	return model[keccak256(abi.encodePacked(_model))].feeSubscription;
  }

  function modelExists(string memory _model) public view returns (bool) {
		return(
			keccak256(abi.encodePacked(_model)) ==
			keccak256(abi.encodePacked(model[keccak256(abi.encodePacked(_model))].name))
		);
  }

  //setters
  function _setPctTkn(uint256 _totalSupply) internal {
		require(_totalSupply > 0, "PerceptError: total supply is invalid");
		pctTkn = new PerceptToken(_totalSupply);
		emit PctTknDeployed(address(pctTkn), _totalSupply);
  }

  function setPerceptNetwork(address _newPerceptNetwork) public onlyOwner {
		address __oldPerceptNetwork = perceptNetwork;
		require(
			_validatateSetPerceptNetwork(__oldPerceptNetwork, _newPerceptNetwork),
			"PerceptError: Percept network address is invalid"
		);
		perceptNetwork = _newPerceptNetwork;
		emit PerceptNetworkUpdated(__oldPerceptNetwork, _newPerceptNetwork);
  }

  function setModel(PerceptLibrary.Model memory _model) external onlyOwner {
		require(_validateSetModel(_model), "PerceptError: setModel");
		if(_model.verifier == address(0)) _model.verifier = _deployVerifier(_model);
		_setModel(_model);
  }

	function _deployVerifier(PerceptLibrary.Model memory _model) private returns (address __verifier) {
    bytes memory _bytecode = _model.verifierBytecode;

		assembly {
      __verifier := create(0, add(_bytecode, 0x20), mload(_bytecode))
      if iszero(extcodesize(__verifier)) {
				revert(0, 0)
      }
    }

    emit VerifierDeployed(_model.name, __verifier);
    return __verifier;
  }

  function _setModel(PerceptLibrary.Model memory _model) private {
		model[keccak256(abi.encodePacked(_model.name))] = _model;
		emit ModelAdded(_model);
  }

  function subscribeModel(PerceptLibrary.Model calldata _model) external returns (bool){
		require(_validateSubscribeModel(_model), "PerceptError: subscribeModel");
		_transferFeeSubscription(_model);
		_setSubscriber(_model);
		return true;
  }

  function _transferFeeSubscription(PerceptLibrary.Model calldata _model) private {
  	pctTkn.transferFrom(msg.sender, address(this), getFeeSubscription(_model.name));
  }

  function _setSubscriber(PerceptLibrary.Model calldata _model) private {
  	subscriber[keccak256(abi.encodePacked(msg.sender))] = _model;
  	emit SubscriberRegistered(msg.sender, _model);
  }

  function sendRequest(PerceptLibrary.Request memory _request) external nonReentrant returns (uint256) {
		PerceptLibrary.Model memory __subscriberModel = getSubscriberModel(msg.sender);
		require(_validateSendRequest(_request, __subscriberModel), "PerceptError: sendRequest");
		_transferFeeCall(_request);
		_setRequest(_request);
		emit NewRequest(_request); //→→→ PerceptNetwork.
		return requestID++;
  }

  function _transferFeeCall(PerceptLibrary.Request memory _request) private {
  	pctTkn.transferFrom(msg.sender, address(this), getFeeCall(_request.model));
  }

  function _setRequest(PerceptLibrary.Request memory _request) private {
  	request[keccak256(abi.encodePacked(_request.id))] = _request;
  }

  function response(PerceptLibrary.Response calldata _response) external nonReentrant returns (bool __verified){
		PerceptLibrary.Request storage __request = request[keccak256(abi.encodePacked(_response.id))];
		require(_validateResponse(__request, _response), "PerceptError: response");

		__verified = _verify(_response);
		__verified ? _setExecSuccess(__request, _response) : _setExecFailure(__request, _response);

		emit ResponseReceived(
			__verified,
			__request,
			_response
		);
  }

  function _verify(PerceptLibrary.Response memory _response) private returns (bool __verified) {
    (bool _success, bytes memory _data) = _response.verifier.call(_response.proof); //revert=false; !revert=true
		__verified = _success && abi.decode(_data, (bool));
  }

  function _setExecSuccess(
  	PerceptLibrary.Request storage __request,
  	PerceptLibrary.Response calldata _response
  ) private {
  	__request.status = PerceptLibrary.RequestStatus.Success;
  	model[keccak256(abi.encodePacked(_response.model))].amtVerifiedCalls++;
  	_response.subscriber.call(_response.dataResponse); //skip success check to protect from DoS attack @todo specify gasLeft
  }

  function _setExecFailure(
  	PerceptLibrary.Request storage __request,
  	PerceptLibrary.Response calldata _response
  ) private {
		__request.status = PerceptLibrary.RequestStatus.Failure;
  	pctTkn.transfer(_response.subscriber, getFeeCall(_response.model));
  	_response.subscriber.call(abi.encodeWithSignature("perceptCallback(bytes)", bytes(''))); //skip success check to protect from DoS attack @todo specify gasLeft
  }

  function withdraw() external view onlyOwner returns(bool) { //ensure risks with reentrancy & modelAdd/update
		{
			/**
			 * calc. reward distribution, e.g. based on:
			 * 	1. Model's "amtVerifiedCalls"
			 *  2. Models' "data" (based on ML Marketplace data)
			 */
		}
		return true; //mute
  }

  //validation
  function _validatateSetPerceptNetwork(
  	address _oldPerceptNetwork,
  	address _newPerceptNetwork
  ) private pure returns (bool) {
		return (
			_oldPerceptNetwork!=_newPerceptNetwork &&
			_newPerceptNetwork!=address(0)
		);
  }

  function _validateSetModel(PerceptLibrary.Model memory _model) private view returns (bool) {
		return (
			bytes(_model.name).length>0 &&
			!modelExists(_model.name) &&
			bytes(_model.data).length>0 &&
			_model.feeCall > 0 &&
			_model.feeSubscription > 0 &&
			_model.amtVerifiedCalls ==0 &&
			( //>=1 must contain data
				_model.verifier!=address(0)
				||
				_model.verifierBytecode.length!=0
			)
		);
  }

  function _validateSubscribeModel(PerceptLibrary.Model calldata _model) private view returns (bool) {
		return (
			modelExists(_model.name) && //model exists
			msg.sender.code.length>0 //is contract after construction
		);
  }

  function _validateSendRequest(
  	PerceptLibrary.Request memory _request,
  	PerceptLibrary.Model memory __subscriberModel
  ) private view returns (bool) {
		return(
			_request.id==requestID &&
			_request.subscriber==msg.sender &&
			modelExists(_request.model) &&
			_request.status==PerceptLibrary.RequestStatus.Pending &&
			( //correct callback
				bytes4(_request.dataRequest)
				==
				bytes4(keccak256("perceptCallback(bytes)"))
			) &&
			( //correct model
				keccak256(abi.encodePacked(_request.model))
				==
				keccak256(abi.encodePacked(__subscriberModel.name))
			)
		);
  }

  function _validateResponse(
  	PerceptLibrary.Request storage _request,
  	PerceptLibrary.Response calldata _response
  ) private view returns (bool) {
  	return (
			msg.sender==perceptNetwork &&
			_response.id==_request.id &&
			_response.subscriber!=address(0) &&
			_response.subscriber==_request.subscriber &&
			(//same model
				keccak256(abi.encodePacked(_response.model))
				==
				keccak256(abi.encodePacked(_request.model))
			) &&
			( //same data request
				keccak256(abi.encodePacked(_response.dataRequest))
				==
				keccak256(abi.encodePacked(_request.dataRequest))
			) &&
			( //same verifier
				_response.verifier
				==
				model[keccak256(abi.encodePacked(_response.model))].verifier
			) &&
			( //correct callback signature
				bytes4(_response.dataResponse)
				==
				bytes4(keccak256("perceptCallback(bytes)"))
			) &&
			( //correct verifier signature
				bytes4(_response.proof)
				==
				bytes4(keccak256("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[1])"))
			)
		);
  }
}