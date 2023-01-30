pragma solidity 0.8.17;

/**
 * todo:
 *
 * https://app.diagrams.net/#G1Ie_Xm4E-gJG5_blKtyqz8bFa0BBeJGAl
 *
 * [ ] PerceptRegister.sol
 * 		[ ] proposeModel()
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
 */
import "./PerceptRegister.sol";

contract PerceptProvider is PerceptRegister {
}