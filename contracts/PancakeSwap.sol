// SPDX-License-Identifier: MIT
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "./interface/pancakeswap/IPancakeFactory.sol";
import "./interface/pancakeswap/IPancakePair.sol";
import "./Governable.sol";
import "./SwapBase.sol";

pragma solidity 0.6.12;

contract PancakeSwap is SwapBase {

  IPancakeFactory pancakeFactory;

  constructor(address _factoryAddress, address _storage) SwapBase(_factoryAddress, _storage) public {

  }

  function initializeFactory() public virtual override {
    pancakeFactory = IPancakeFactory(factoryAddress);
  }

  function checkFactory(IPancakePair pair, address compareFactory) internal view returns (bool) {
    bool check;
    try pair.factory{gas: 3000}() returns (address factory) {
      check = (factory == compareFactory);
    } catch {
      check = false;
    }
    return check;
  }

  /// @dev Check what token is pool of this Swap
  function isPool(address token) public virtual override view returns(bool){
    IPancakePair pair = IPancakePair(token);
    return checkFactory(pair, factoryAddress);
  }

  /// @dev Get underlying tokens and amounts
  function getUnderlying(address token) public virtual override view returns (address[] memory, uint256[] memory){
    IPancakePair pair = IPancakePair(token);
    IBEP20 pairToken = IBEP20(token);
    address[] memory tokens  = new address[](2);
    uint256[] memory amounts = new uint256[](2);
    tokens[0] = pair.token0();
    tokens[1] = pair.token1();
    uint256 token0Decimals = IBEP20(tokens[0]).decimals();
    uint256 token1Decimals = IBEP20(tokens[1]).decimals();
    uint256 supplyDecimals = IBEP20(token).decimals();
    (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) = pair.getReserves();
    uint256 totalSupply = pairToken.totalSupply();
    if (reserve0 == 0 || reserve1 == 0 || totalSupply == 0) {
      amounts[0] = 0;
      amounts[1] = 0;
      return (tokens, amounts);
    }
    amounts[0] = reserve0 * 10 ** (supplyDecimals - token0Decimals + precisionDecimals) / totalSupply;
    amounts[1] = reserve1 * 10 ** (supplyDecimals - token1Decimals + precisionDecimals) / totalSupply;
    return (tokens, amounts);
  }

  /// @dev Returns pool size
  function getPoolSize(address pairAddress, address token) internal view returns(uint256){
    IPancakePair pair = IPancakePair(pairAddress);
    address token0 = pair.token0();
    (uint112 poolSize0, uint112 poolSize1,) = pair.getReserves();
    uint256 poolSize = (token == token0) ? poolSize0 : poolSize1;
    return poolSize;
  }

  /// @dev Gives a pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  function getLargestPool(address token, address[] memory tokenList) public virtual override view returns (address, address, uint256){
    uint256 largestPoolSize = 0;
    address largestKeyToken;
    address largestPool;
    uint256 poolSize;
    uint256 i;
    for (i=0;i<tokenList.length;i++) {
      address poolAddress = pancakeFactory.getPair(token,tokenList[i]);
      poolSize = poolAddress !=address(0) ? getPoolSize(poolAddress, token) : 0;
      if (poolSize > largestPoolSize) {
        largestKeyToken = tokenList[i];
        largestPool = poolAddress;
        largestPoolSize = poolSize;
      }
    }
    return (largestKeyToken, largestPool, largestPoolSize);
  }

  /// @dev Generic function giving the price of a given token vs another given token
  function getPriceVsToken(address token0, address token1, address poolAddress) public virtual override view returns (uint256){
    address pairAddress = pancakeFactory.getPair(token0, token1);
    IPancakePair pair = IPancakePair(pairAddress);
    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    uint256 token0Decimals = IBEP20(token0).decimals();
    uint256 token1Decimals = IBEP20(token1).decimals();
    uint256 price;
    if (token0 == pair.token0()) {
      price = (reserve1 * 10 ** (token0Decimals - token1Decimals + precisionDecimals)) / reserve0;
    } else {
      price = (reserve0 * 10 ** (token0Decimals - token1Decimals + precisionDecimals)) / reserve1;
    }
    return price;
  }

}