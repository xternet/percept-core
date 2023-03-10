pragma solidity 0.8.17;

import "forge-std/Test.sol";
//import percept libarary
import "../src/PerceptLibrary.sol";
//import percept provider
import "../src/PerceptProvider.sol";
import "../src/interfaces/IPerceptProvider.sol";

contract MockSubscriber {
  IPerceptProvider perceptProvider;
  constructor(address _perceptProvider, address _perceptToken) {
    perceptProvider = IPerceptProvider(_perceptProvider);
    (bool success, ) = _perceptToken.call(abi.encodeWithSignature("approve(address,uint256)", _perceptProvider, type(uint256).max));
    require(success, "Error: PCT approve");
  }

  fallback() external { //alternative to using the perceptCallback function
    console.log('in fallback');
    if(msg.sender==address(perceptProvider)) {
      (bytes memory response) = abi.decode(msg.data[4:], (bytes));
      (bool success) = abi.decode(response, (bool));
      if(success){
        console.log('MockSubscriber (fallback) perceptCallback success');
        //logic...
        revert();
      }
    }
  }

  function getPerceptProviderAddr() public view returns (address) {
    return address(perceptProvider);
  }

  function subscribeModel(string memory _modelType) public {
    (bool success0, bytes memory __data) = address(perceptProvider).call(abi.encodeWithSignature("getModel(string)", _modelType));
    require(success0, "MockSubscriberError: getModelPercept");
    (PerceptLibrary.Model memory __model) = abi.decode(__data, (PerceptLibrary.Model));

    (bool success1, ) = address(perceptProvider).call(
      abi.encodeWithSignature(
        "subscribeModel((string,string,address,uint256,uint256,uint256,bytes))",
        __model
      )
    );

    require(success1, "MockSubscriberError: subscribeModelTypePercept");
  }

  function sendRequest(bytes memory _data) public {
    IPerceptProvider.Request memory __request = IPerceptProvider.Request({
      id: perceptProvider.getRequestID(),
      subscriber: address(this),
      model: perceptProvider.getSubscriberModel(address(this)).name,
      dataRequest: _data,
      status: IPerceptProvider.RequestStatus.Pending
    });

    perceptProvider.sendRequest(__request);
  }

  function perceptCallback(bytes memory _data) external view { //typo
    require(msg.sender==address(perceptProvider), "MockSubscriberError: perceptCallbackPercept");
    (bool success) = abi.decode(_data, (bool));
    if(success){
      console.log('MockSubscriber perceptCallback success');
      revert();
      //logic..
    }
  }
}