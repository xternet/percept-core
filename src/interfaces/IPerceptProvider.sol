pragma solidity ^0.8.0;

interface IPerceptProvider {
  struct Model {
    string name;
    string data;
    address verifier;
    uint256 feeCall;
    uint256 feeSubscription;
    uint256 amtVerifiedCalls;
    bytes verifierBytecode;
  }

  enum RequestStatus {
    Pending,
    Success,
    Failure
  }

  struct Request {
    uint256 id;
    address subscriber;
    string model;
    bytes dataRequest;
    RequestStatus status;
  }

  struct Response {
    uint256 id;
    address subscriber;
    string model;
    bytes dataRequest;
    bytes dataResponse;
    address verifier;
    bytes proof;
  }

  event PctTknDeployed(address pctTkn, uint256 totalSupply);
  event PerceptNetworkUpdated(address oldPerceptNetwork, address newPerceptNetwork);
  event VerifierDeployed(string model, address verifierAddress);

  event ModelAdded(Model model);
  event SubscriberRegistered(address subscriber, Model model);
  event NewRequest(Request request);
  event ResponseReceived(bool verified, Request request, Response response);

  function getRequestID() external view returns (uint256);
  function getPerceptNetwork() external view returns (uint256);
  function getPctTknAddr() external view returns (address);
  function getModel(string memory) external view returns (Model memory model);
  function getSubscriberModel(address) external view returns (Model memory model);
  function getRequest(uint256) external view returns (Request memory request);
  function getFeeCall(string memory) external view returns (uint256);
  function getFeeSubscription(string memory) external view returns (uint256);
  function modelExists(string memory) external view returns (bool);
  function setModel(Model memory model) external;
  function subscribeModel(Model memory model) external returns (bool);
  function sendRequest(Request memory request) external returns (uint256);
  function response(Response calldata response) external returns (bool);
  function perceptCallback(bytes memory) external;
}