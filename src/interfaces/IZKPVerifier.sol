pragma solidity ^0.8.0;

interface IZKPVerifier {
	function verify(bool proof) external returns (bool);
}