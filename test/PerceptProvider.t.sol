pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/ZKPVerifier.sol";
import "../src/PerceptToken.sol";
import "../src/PerceptLibrary.sol";
import "../src/PerceptProvider.sol";
import "../src/interfaces/IPerceptProvider.sol";
import "../src/MockSubscriber.sol";
import {Utilities} from "./utils/Utilities.sol";

contract PerceptProviderTest is Test {
  using PerceptLibrary for PerceptLibrary.Model;
  using PerceptLibrary for PerceptLibrary.RequestStatus;
  using PerceptLibrary for PerceptLibrary.Response;

  Utilities utils;
  ZKPVerifier zkpVerifier;
  PerceptToken perceptToken;
  MockSubscriber mockSubscriber;
  PerceptProvider perceptProvider;

  PerceptLibrary.Model model0;
  PerceptLibrary.Model model_invalid; //the one with invalid verifier (selfdestructed)
  PerceptLibrary.Response response0;

  string model0_name;
  string model0_data;
  address model0_verifier;

  uint256 internal constant NUM_USERS = 4;
  address[] internal users;
  address internal deployer;
  address internal modelProposer;
  address internal subscriber;
  address internal perceptNetwork;

  uint256 public modelTypeSubscriptonFee;

  uint256 pctTknTotalSupply;
  uint256 feeCall0;
  uint256 feeSubcription0;
  uint256 initMockSubscriberBalance;

  bytes constant verifierBytecode = hex'608060405234801561001057600080fd5b50600080546001600160a01b031916339081178255604051909182917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0908290a350610235806100616000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c806333364197146100465780638da5cb5b1461006e578063f2fde38b146100b3575b600080fd5b6100596100543660046101c9565b6100c8565b60405190151581526020015b60405180910390f35b60005461008e9073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610065565b6100c66100c13660046101f2565b6100d4565b005b60008115610041575090565b60005473ffffffffffffffffffffffffffffffffffffffff163314610159576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600c60248201527f554e415554484f52495a45440000000000000000000000000000000000000000604482015260640160405180910390fd5b600080547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081178255604051909133917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a350565b6000602082840312156101db57600080fd5b813580151581146101eb57600080fd5b9392505050565b60006020828403121561020457600080fd5b813573ffffffffffffffffffffffffffffffffffffffff811681146101eb57600080fdfea164736f6c6343000811000a';

  //the one with selfdestruct in constructor
  bytes constant verifierBytecodeInvalid = hex'608060405234801561001057600080fd5b50600080546001600160a01b031916339081178255604051909182917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0908290a35033fffe';


  bytes constant requestBytes = abi.encodeWithSignature("perceptCallback(bytes)", "0x");
  bytes constant responseProofTrue = abi.encodeWithSignature("verify(bool)", true);
  bytes constant responseProofFalse = abi.encodeWithSignature("verify(bool)", false);
  bytes constant responseBytes = abi.encodeWithSignature("perceptCallback(bytes)", abi.encode(bool(true)));

  event NewRequest(uint256 id, address subscriber, string modelType, uint callFee, bytes data);
  event Transfer(address indexed from, address indexed to, uint256 amount);

  function setUp() public {
    utils = new Utilities();
    users = utils.createUsers(NUM_USERS);

    deployer = users[0];
    subscriber = users[1];
    perceptNetwork = users[2];

    feeCall0 = 1 ether;
    feeSubcription0 = 10 ether;
    pctTknTotalSupply = 1000000 ether;
    initMockSubscriberBalance = 100 ether;

    model0_name = "DOV";
    model0_data = "0x";

    model0 = PerceptLibrary.Model({
      name: model0_name,
      data: model0_data,
      verifier: model0_verifier,
      feeCall: feeCall0,
      feeSubscription: feeSubcription0,
      amtVerifiedCalls: 0,
      verifierBytecode: verifierBytecode
    });

    vm.startPrank(deployer, deployer); //msg.sender & tx.origin
    perceptProvider = new PerceptProvider(pctTknTotalSupply, perceptNetwork);

    perceptToken = PerceptToken(perceptProvider.getPctTknAddr());

    perceptProvider.setModel(model0); // & deploy verifier
    vm.stopPrank();

    vm.startPrank(subscriber);
    mockSubscriber = new MockSubscriber(address(perceptProvider), address(perceptToken));
    vm.stopPrank();

    vm.startPrank(deployer);
    perceptToken.transfer(address(mockSubscriber), initMockSubscriberBalance);
    vm.stopPrank();
  }

  function testTrue_setUp() public {
    assert(address(perceptProvider) != address(0));
    assert(address(perceptToken) != address(0));
    assert(address(mockSubscriber) != address(0));
    assertEq(perceptToken.totalSupply(), pctTknTotalSupply);
    assertEq(perceptToken.balanceOf(address(mockSubscriber)), initMockSubscriberBalance);
    assertEq(perceptToken.balanceOf(address(deployer)), pctTknTotalSupply - initMockSubscriberBalance);
    assertEq(mockSubscriber.getPerceptProviderAddr(), address(perceptProvider));
  }

  function testTrue_setPerceptNetwork() public {
    vm.startPrank(deployer);
    perceptProvider.setPerceptNetwork(address(1));
    assertEq(perceptProvider.perceptNetwork(), address(1));
    vm.stopPrank();
  }

  function testTrue_setModel() public {
    vm.startPrank(deployer);
    assertEq(perceptProvider.getModel(model0_name).name, model0_name);
    assertEq(perceptProvider.modelExists(model0_name), true);
    assertEq(perceptProvider.getModel(model0_name).name, model0_name);
    assertEq(perceptProvider.getModel(model0_name).data, model0_data);
    assertEq(perceptProvider.getModel(model0_name).feeCall, feeCall0);
    assertEq(perceptProvider.getModel(model0_name).feeSubscription, feeSubcription0);
    assertEq(perceptProvider.getModel(model0_name).amtVerifiedCalls, 0);
    assertEq(perceptProvider.getModel(model0_name).verifierBytecode, verifierBytecode);
    assertEq(perceptProvider.getFeeSubscription(model0_name), feeSubcription0);
    assertEq(perceptProvider.getFeeCall(model0_name), feeCall0);


    zkpVerifier = ZKPVerifier(perceptProvider.getModel(model0_name).verifier);
    assert(address(zkpVerifier)!=address(0));
    vm.stopPrank();
  }

  function testTrue_setSubscribeModel() public {
    vm.startPrank(subscriber);
    mockSubscriber.subscribeModel(model0.name);

    assertEq(perceptToken.balanceOf(address(mockSubscriber)), initMockSubscriberBalance - feeSubcription0);
    assertEq(perceptToken.balanceOf(address(perceptProvider)), feeSubcription0);
    assertEq(perceptProvider.getSubscriberModel(address(mockSubscriber)).name, model0_name);
    assertEq(perceptProvider.getModel(model0_name).amtVerifiedCalls, 0);
    vm.stopPrank();
  }


  function testTrue_sendRequest() public {
    testTrue_setSubscribeModel();
    vm.startPrank(subscriber);
    mockSubscriber.sendRequest(requestBytes);
    vm.stopPrank();

    assertEq(perceptToken.balanceOf(address(mockSubscriber)), initMockSubscriberBalance - feeSubcription0 - feeCall0);
    assert(perceptProvider.getRequest(0).status == PerceptLibrary.RequestStatus.Pending);
    assertEq(perceptToken.balanceOf(address(perceptProvider)), feeSubcription0 + feeCall0);
    assertEq(perceptProvider.getRequest(0).subscriber, address(mockSubscriber));
    assertEq(perceptProvider.getModel(model0_name).amtVerifiedCalls, 0);
    assertEq(perceptProvider.getRequest(0).dataRequest, requestBytes);
    assertEq(perceptProvider.getRequest(0).model, model0_name);
    assertEq(perceptProvider.getRequest(0).id, 0);
    assertEq(perceptProvider.requestID(), 1);
  }

  function test_responseVerified() public {
    testTrue_sendRequest();
    vm.startPrank(perceptNetwork);

    PerceptLibrary.Request memory _request = perceptProvider.getRequest(0);
    response0 = PerceptLibrary.Response({
      id: _request.id,
      subscriber: _request.subscriber,
      model: _request.model,
      dataRequest: _request.dataRequest,
      dataResponse: responseBytes, //perceptCallback(bytes(bool))
      verifier: perceptProvider.getModel(model0_name).verifier,
      proof: responseProofTrue
    });

    bool _verified = perceptProvider.response(response0);

    assert(_verified);
    assert(perceptProvider.getModel(model0_name).amtVerifiedCalls == 1);
    assert(perceptProvider.getRequest(0).status == PerceptLibrary.RequestStatus.Success);
    assert(perceptToken.balanceOf(address(perceptProvider)) == feeSubcription0 + feeCall0);
    assert(perceptToken.balanceOf(address(mockSubscriber)) == initMockSubscriberBalance - feeSubcription0 - feeCall0);
    vm.stopPrank();
  }

  function test_responseNotVerified() public {
    testTrue_sendRequest();
    vm.startPrank(perceptNetwork);

    PerceptLibrary.Request memory _request = perceptProvider.getRequest(0);
    response0 = PerceptLibrary.Response({
      id: _request.id,
      subscriber: _request.subscriber,
      model: _request.model,
      dataRequest: _request.dataRequest,
      dataResponse: responseBytes, //perceptCallback(bytes(bool))
      verifier: perceptProvider.getModel(model0_name).verifier,
      proof: responseProofFalse //<---------- verify(bool) FALSE
    });

    bool _verified = perceptProvider.response(response0);

    assert(_verified == false);
    assert(perceptProvider.getModel(model0_name).amtVerifiedCalls == 0);
    assert(perceptProvider.getRequest(0).status == PerceptLibrary.RequestStatus.Failure);
    assert(perceptToken.balanceOf(address(perceptProvider)) == feeSubcription0);
    assert(perceptToken.balanceOf(address(mockSubscriber)) == initMockSubscriberBalance - feeSubcription0);
    vm.stopPrank();
  }

  function testFail_setModelInvalidVerifierBytecode() public {
    model_invalid = PerceptLibrary.Model({
      name: model0_name,
      data: model0_data,
      verifier: model0_verifier,
      feeCall: feeCall0,
      feeSubscription: feeSubcription0,
      amtVerifiedCalls: 0,
      verifierBytecode: verifierBytecodeInvalid
    });

    vm.startPrank(deployer, deployer);
    perceptProvider = new PerceptProvider(pctTknTotalSupply, perceptNetwork);
    perceptProvider.setModel(model_invalid);
    vm.stopPrank();
  }

  function testFail_setModelInvalidVerifierBytecodeAndAddress() public {
    model_invalid = PerceptLibrary.Model({
      name: model0_name,
      data: model0_data,
      verifier: address(0),
      feeCall: feeCall0,
      feeSubscription: feeSubcription0,
      amtVerifiedCalls: 0,
      verifierBytecode: '0x'
    });

    vm.startPrank(deployer, deployer);
    perceptProvider = new PerceptProvider(pctTknTotalSupply, perceptNetwork);
    perceptProvider.setModel(model_invalid);
    vm.stopPrank();
  }
}