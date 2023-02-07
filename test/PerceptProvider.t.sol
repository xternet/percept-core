pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/PerceptToken.sol";
import "../src/PerceptLibrary.sol";
import "../src/PerceptProvider.sol";
import "../src/Verifier.sol";
import "../src/interfaces/IPerceptProvider.sol";
import "../src/MockSubscriber.sol";
import {Utilities} from "./utils/Utilities.sol";

contract PerceptProviderTest is Test {
  using PerceptLibrary for PerceptLibrary.Model;
  using PerceptLibrary for PerceptLibrary.RequestStatus;
  using PerceptLibrary for PerceptLibrary.Response;
  using PerceptLibrary for PerceptLibrary.Proof;

  Utilities utils;
  PerceptToken perceptToken;
  MockSubscriber mockSubscriber;
  PerceptProvider perceptProvider;
  Verifier verifier;

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

  /**
   * ZKP proof for the following statement:
   * a * b = c
   * where a=3, b=11, and c as a result c=33
   *
   * obtained from: cd circuits/test/4_proof && snarkjs generatecall && cd ../../..
   */
  uint256[2] public a = [
    0x2df5d8728684e37dbfe1018fabd82b3a3c79bee0b29e4d178338819378117777,
    0x29625c6f4504e2c8c50760257deaeb08663fce5a019232d28ce2915a5396f85e
  ];

  uint256[2][2] public b = [
    [
      0x1b0d15e956f98fbf896f4929f7265ff5c34b3a5589eb9585a8a1242ef56f0d7c,
      0x12bd6375b4484aaf8541fea7380763247870adbc6796297ea63c7c16ebc9a19c
    ],
    [
      0x2512859064178aa30f1043a87ed8b0f6671e76d6c24447823f180d479ff71b7f,
      0x197b7d2b948a562b046fe2a5be30be9f045b0783d401df5677ea6916b02fc6f0
    ]
  ];
  uint256[2] public c = [
    0x1c69a6d7c0103a1852af0c40b24acddff61cdd5198e2fec996d30cc399baf1fe,
    0x14c837a6d6aa0d20ee08f7917a427796db0c2566017d51dc93f7228d8023d2e1
  ];
  uint256[1] public input = [
    0x0000000000000000000000000000000000000000000000000000000000000021
  ];

  //to test false proof
  uint256[1] public input_false = [
    0x0000000000000000000000000000000000000000000000000000000000000020
  ];

  bytes constant requestBytes = abi.encodeWithSignature("perceptCallback(bytes)", "0x");
  bytes constant responseProofTrue = abi.encodeWithSignature("verify(bool)", true);
  bytes constant responseProofFalse = abi.encodeWithSignature("verify(bool)", false);
  bytes constant responseBytes = abi.encodeWithSignature("perceptCallback(bytes)", abi.encode(bool(true)));

  event NewRequest(uint256 id, address subscriber, string modelType, uint callFee, bytes data);
  event Transfer(address indexed from, address indexed to, uint256 amount);

  function _getTrueProof() public view returns (bytes memory) {
    return abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[1])", a, b, c, input);
  }

  function _getFalseProof() public view returns (bytes memory) {
    return abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[1])", a, b, c, input_false);
  }


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

    vm.startPrank(deployer, deployer); //msg.sender & tx.origin
    perceptProvider = new PerceptProvider(pctTknTotalSupply, perceptNetwork);
    perceptToken = PerceptToken(perceptProvider.getPctTknAddr());
    verifier = new Verifier();

    model0_verifier = address(verifier);

    model0 = PerceptLibrary.Model({
      name: model0_name,
      data: model0_data,
      verifier: model0_verifier,
      feeCall: feeCall0,
      feeSubscription: feeSubcription0,
      amtVerifiedCalls: 0,
      verifierBytecode: ''
    });

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
    // assertEq(perceptProvider.getModel(model0_name).verifierBytecode, verifierBytecodeMultiplier);
    assertEq(perceptProvider.getFeeSubscription(model0_name), feeSubcription0);
    assertEq(perceptProvider.getFeeCall(model0_name), feeCall0);

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
      proof: _getTrueProof()
    });

    bool _verified = perceptProvider.response(response0);

    assert(_verified);
    assert(perceptProvider.getModel(model0_name).amtVerifiedCalls == 1);
    assert(perceptProvider.getRequest(0).status == PerceptLibrary.RequestStatus.Success);
    assert(perceptToken.balanceOf(address(perceptProvider)) == feeSubcription0 + feeCall0);
    assert(perceptToken.balanceOf(address(mockSubscriber)) == initMockSubscriberBalance - feeSubcription0 - feeCall0);
    vm.stopPrank();
  }

  function testFail_responseVerified() public {
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
      proof: _getFalseProof()
    });

    bool _verified = perceptProvider.response(response0);

    assert(_verified);
    assert(perceptProvider.getModel(model0_name).amtVerifiedCalls == 1);
    assert(perceptProvider.getRequest(0).status == PerceptLibrary.RequestStatus.Success);
    assert(perceptToken.balanceOf(address(perceptProvider)) == feeSubcription0 + feeCall0);
    assert(perceptToken.balanceOf(address(mockSubscriber)) == initMockSubscriberBalance - feeSubcription0 - feeCall0);
    vm.stopPrank();
  }

  function testFail_setModelInvalidVerifierBytecode() public {
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

  function testFail_setModelInvalidVerifierBytecodeAndAddress() public {
    model_invalid = PerceptLibrary.Model({
      name: model0_name,
      data: model0_data,
      verifier: address(0),
      feeCall: feeCall0,
      feeSubscription: feeSubcription0,
      amtVerifiedCalls: 0,
      verifierBytecode: ''
    });

    vm.startPrank(deployer, deployer);
    perceptProvider = new PerceptProvider(pctTknTotalSupply, perceptNetwork);
    perceptProvider.setModel(model_invalid);
    vm.stopPrank();
  }
}