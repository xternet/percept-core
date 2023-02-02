pragma solidity 0.8.17;

import "../src/PerceptToken.sol";
import "forge-std/Test.sol";

contract PerceptTokenTest is Test {
	PerceptToken perceptToken;
	uint totalSupply = 1000000 ether;

	function setUp() public {
		perceptToken = new PerceptToken(totalSupply);
	}

	function testTokenName() public {
		assertEq(perceptToken.name(), "PerceptToken");
	}

	function testTokenSymbol() public {
		assertEq(perceptToken.symbol(), "PCT");
	}

	function testTokenDecimals() public {
		assertEq(perceptToken.decimals(), 18);
	}

	function testTokenTotalSupply() public {
		assertEq(perceptToken.totalSupply(), totalSupply);
	}

	function testTokenBalanceOf() public {
		assertEq(perceptToken.balanceOf(address(this)), totalSupply);
	}
}