// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/uniswap/IUniswapV2Factory.sol";
import "./interface/uniswap/IUniswapV2Pair.sol";
//import "./interface/curve/ICurvePool.sol";
//import "./interface/curve/ICurveRegistry.sol";
import "./interface/mooniswap/IMooniFactory.sol";
import "./interface/mooniswap/IMooniswap.sol";
import "./Governable.sol";

pragma solidity 0.6.12;

contract OracleMatic is Governable {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  //Addresses for factories and registries for different DEX platforms. Functions will be added to allow to alter these when needed.
//  address public uniswapFactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
//  address public sushiswapFactoryAddress = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
  address public sushiswapFactoryAddress = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
//  address public curveRegistryAddress = 0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c;
//  address public oneInchFactoryAddress = 0xbAF9A5d4b0052359326A6CDAb54BABAa3a3A9643;

  uint256 public precisionDecimals = 18;

//  IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapFactoryAddress);
  IUniswapV2Factory sushiswapFactory = IUniswapV2Factory(sushiswapFactoryAddress);

  //Key tokens are used to find liquidity for any given token on Uni, Sushi and Curve.
  address[] public keyTokens = [
  0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, //USDC
  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619, //WETH
  0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, //DAI
  0xc2132D05D31c914a87C6611C10748AEb04B58e8F, //USDT
  0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6 //WBTC
  ];
  //Pricing tokens are Key tokens with good liquidity with the defined output token on Uniswap.
  address[] public pricingTokens = [
  0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, //USDC
  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619, //WETH
  0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, //DAI
  0xc2132D05D31c914a87C6611C10748AEb04B58e8F, //USDT
  0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6 //WBTC
  ];
  //The defined output token is the unit in which prices of input tokens are given.
  address public definedOutputToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; //USDC

  modifier validKeyToken(address keyToken){
      require(checkKeyToken(keyToken), "Not a Key Token");
      _;
  }
  modifier validPricingToken(address pricingToken){
      require(checkPricingToken(pricingToken), "Not a Pricing Token");
      _;
  }

  event FactoryChanged(address newFactory, address oldFactory);
  event RegistryChanged(address newRegistry, address oldRegistry);
  event KeyTokenAdded(address newKeyToken);
  event PricingTokenAdded(address newPricingToken);
  event KeyTokenRemoved(address keyToken);
  event PricingTokenRemoved(address pricingToken);
  event DefinedOutuptChanged(address newOutputToken, address oldOutputToken);
  event CurveExceptionAdded(address newException, uint256 exceptionList);
  event CurveExceptionRemoved(address oldException, uint256 exceptionList);

  constructor(address _storage)
  Governable(_storage) public {}

//  function changeUniFactory(address newFactory) external onlyGovernance {
//    address oldFactory = uniswapFactoryAddress;
//    uniswapFactoryAddress = newFactory;
//    uniswapFactory = IUniswapV2Factory(uniswapFactoryAddress);
//    emit FactoryChanged(newFactory, oldFactory);
//  }
  function changeSushiFactory(address newFactory) external onlyGovernance {
    address oldFactory = sushiswapFactoryAddress;
    sushiswapFactoryAddress = newFactory;
    sushiswapFactory = IUniswapV2Factory(sushiswapFactoryAddress);
    emit FactoryChanged(newFactory, oldFactory);
  }

  function addKeyToken(address newToken) external onlyGovernance {
    require((checkKeyToken(newToken)==false), "Already a key token");
    keyTokens.push(newToken);
    emit KeyTokenAdded(newToken);
  }

  function addPricingToken(address newToken) public onlyGovernance validKeyToken(newToken) {
    require((checkPricingToken(newToken)==false), "Already a pricing token");
    pricingTokens.push(newToken);
    emit PricingTokenAdded(newToken);
  }

  function removeKeyToken(address keyToken) external onlyGovernance validKeyToken(keyToken) {
    uint256 i;
    for ( i=0;i<keyTokens.length;i++) {
      if (keyToken == keyTokens[i]){
        break;
      }
    }
    while (i<keyTokens.length-1) {
      keyTokens[i] = keyTokens[i+1];
      i++;
    }
    keyTokens.pop();
    emit KeyTokenRemoved(keyToken);

    if (checkPricingToken(keyToken)) {
      removePricingToken(keyToken);
    }
  }

  function removePricingToken(address pricingToken) public onlyGovernance validPricingToken(pricingToken) {
    uint256 i;
    for (i=0;i<pricingTokens.length;i++) {
      if (pricingToken == pricingTokens[i]){
        break;
      }
    }
    while (i<pricingTokens.length-1) {
      pricingTokens[i] = pricingTokens[i+1];
      i++;
    }
    pricingTokens.pop();
    emit PricingTokenRemoved(pricingToken);
  }
  function changeDefinedOutput(address newOutputToken) external onlyGovernance validKeyToken(newOutputToken) {
    address oldOutputToken = definedOutputToken;
    definedOutputToken = newOutputToken;
    emit DefinedOutuptChanged(newOutputToken, oldOutputToken);
  }

  //Main function of the contract. Gives the price of a given token in the defined output token.
  //The contract allows for input tokens to be LP tokens from Uniswap, Sushiswap, Curve and 1Inch.
  //In case of LP token, the underlying tokens will be found and valued to get the price.
  function getPrice(address token) external view returns (uint256) {
    if (token == definedOutputToken) {
      return (10**precisionDecimals);
    }
    bool uniSushiLP = isLPCheck(token);
    uint256 priceToken;
    uint256 tokenValue;
    uint256 price;
    uint256 i;
    if (uniSushiLP) {
      address[2] memory tokens;
      uint256[2] memory amounts;
      (tokens, amounts) = getUniUnderlying(token);
      for (i=0;i<2;i++) {
        priceToken = computePrice(tokens[i]);
        if (priceToken == 0) {
          price = 0;
          return price;
        }
        tokenValue = priceToken*amounts[i]/10**precisionDecimals;
        price = price + tokenValue;
      }
      return price;
    } else {
      return computePrice(token);
    }
  }

  function isLPCheck(address token) public view returns(bool) {
    bool isUniSushi = isUniSushiCheck(token);
    return isUniSushi;
  }

  //Checks if address is Uni or Sushi LP. This is done in two steps, because the second step seems to cause errors for some tokens.
  //Only the first step is not deemed accurate enough, as any token could be called UNI-V2.
  function isUniSushiCheck(address token) internal view returns (bool) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
//    string memory uniSymbol = "UNI-V2";
    string memory sushiSymbol = "SLP";
    string memory symbol = pair.symbol();
//    if (isEqualString(symbol, uniSymbol)) {
//      return checkFactory(pair, uniswapFactoryAddress);
//    } else
    if (isEqualString(symbol, sushiSymbol)) {
      return checkFactory(pair, sushiswapFactoryAddress);
    } else {
      return false;
    }
  }

  function isEqualString(string memory arg1, string memory arg2) internal view returns (bool) {
    bool check = (keccak256(abi.encodePacked(arg1)) == keccak256(abi.encodePacked(arg2)))? true:false;
    return check;
  }

  function checkFactory(IUniswapV2Pair pair, address compareFactory) internal view returns (bool) {
    try pair.factory{gas: 3000}() returns (address factory) {
      bool check = (factory == compareFactory)? true:false;
      return check;
    } catch {
      return false;
    }
  }

  //Get underlying tokens and amounts for Uni/Sushi LPs
  function getUniUnderlying(address token) public view returns (address[2] memory, uint256[2] memory) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
    address[2] memory tokens;
    uint256[2] memory amounts;
    tokens[0] = pair.token0();
    tokens[1] = pair.token1();
    uint256 token0Decimals = ERC20(tokens[0]).decimals();
    uint256 token1Decimals = ERC20(tokens[1]).decimals();
    uint256 supplyDecimals = ERC20(token).decimals();
    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    uint256 totalSupply = pair.totalSupply();
    if (reserve0 == 0 || reserve1 == 0 || totalSupply == 0) {
      amounts[0] = 0;
      amounts[1] = 0;
      return (tokens, amounts);
    }
    amounts[0] = reserve0*10**(supplyDecimals-token0Decimals+precisionDecimals)/totalSupply;
    amounts[1] = reserve1*10**(supplyDecimals-token1Decimals+precisionDecimals)/totalSupply;
    return (tokens, amounts);
  }

  //General function to compute the price of a token vs the defined output token.
  function computePrice(address token) public view returns (uint256) {
    uint256 price;
    if (token == definedOutputToken) {
      price = 10**precisionDecimals;
    } else if (token == address(0)) {
      price = 0;
    } else {
      (address keyToken, address pool, bool uni, bool sushi) = getLargestPool(token,keyTokens);
      uint256 priceVsKeyToken;
      uint256 keyTokenPrice;
      if (keyToken == address(0)) {
        price = 0;
//      } else if (uni) {
//        priceVsKeyToken = getPriceVsTokenUni(token,keyToken);
//        keyTokenPrice = getKeyTokenPrice(keyToken);
//        price = priceVsKeyToken*keyTokenPrice/10**precisionDecimals;
      } else if (sushi) {
        priceVsKeyToken = getPriceVsTokenSushi(token,keyToken);
        keyTokenPrice = getKeyTokenPrice(keyToken);
        price = priceVsKeyToken*keyTokenPrice/10**precisionDecimals;
      }
    }
    return (price);
  }

  //Checks the results of the different largest pool functions and returns the largest.
  function getLargestPool(address token, address[] memory tokenList) public view returns (address, address, bool, bool) {
    (address uniSushiKeyToken, uint256 uniSushiLiquidity, bool isUni) = getUniSushiLargestPool(token, tokenList);
//    (address curveKeyToken, address curvePool, uint256 curveLiquidity) = getCurveLargestPool(token, tokenList);
//    if (uniSushiLiquidity > curveLiquidity) {
      bool isSushi = (isUni)? false:true;
      return (uniSushiKeyToken, address(0), isUni, isSushi);
  }

  //Gives the Uniswap pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  function getUniSushiLargestPool(address token, address[] memory tokenList) internal view returns (address, uint256, bool) {
    uint256 largestPoolSize = 0;
    address largestKeyToken;
    uint256 poolSize;
    uint256 i;
    uint256 poolSizeUni;
    uint256 poolSizeSushi;
    bool largestPoolisUni;
    for (i=0;i<tokenList.length;i++) {
//      address pairAddressUni = uniswapFactory.getPair(token,tokenList[i]);
      address pairAddressSushi = sushiswapFactory.getPair(token,tokenList[i]);
//      if (pairAddressUni!=address(0)) {
//        poolSizeUni = getUniPoolSize(pairAddressUni, token);
//      }
      if (pairAddressSushi!=address(0)) {
        poolSizeSushi = getUniPoolSize(pairAddressSushi, token);
      }
      bool uniDex = (poolSizeUni > poolSizeSushi);
      poolSize = (uniDex)? poolSizeUni:poolSizeSushi;
      if (poolSize > largestPoolSize) {
        largestPoolSize = poolSize;
        largestKeyToken = tokenList[i];
        largestPoolisUni = uniDex;
      }
    }
    return (largestKeyToken, largestPoolSize, largestPoolisUni);
  }

  function getUniPoolSize(address pairAddress, address token) internal view returns(uint256) {
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    address token0 = pair.token0();
    (uint112 poolSize0, uint112 poolSize1,) = pair.getReserves();
    uint256 poolSize = (token==token0)? poolSize0:poolSize1;
    return poolSize;
  }

  /*
//Generic function giving the price of a given token vs another given token on Uniswap.
function getPriceVsTokenUni(address token0, address token1) internal view returns (uint256) {
  address pairAddress = uniswapFactory.getPair(token0,token1);
  IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
  (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
  uint256 token0Decimals = ERC20(token0).decimals();
  uint256 token1Decimals = ERC20(token1).decimals();
  uint256 price;
  if (token0 == pair.token0()) {
    price = (reserve1*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve0;
  } else {
    price = (reserve0*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve1;
  }
  return price;
}
*/

  //Generic function giving the price of a given token vs another given token on Sushiswap.
  function getPriceVsTokenSushi(address token0, address token1) internal view returns (uint256) {
    address pairAddress = sushiswapFactory.getPair(token0,token1);
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();
    uint256 price;
    if (token0 == pair.token0()) {
      price = (reserve1*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve0;
    } else {
      price = (reserve0*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve1;
    }
    return price;
  }

  //Gives the price of a given keyToken.
  function getKeyTokenPrice(address token) internal view returns (uint256) {
    bool isPricingToken = checkPricingToken(token);
    uint256 price;
    uint256 priceVsPricingToken;
    if (token == definedOutputToken) {
      price = 10**precisionDecimals;
    } else if (isPricingToken) {
//      price = getPriceVsTokenUni(token,definedOutputToken);
      price = getPriceVsTokenSushi(token,definedOutputToken);
    } else {
      uint256 pricingTokenPrice;
      (address pricingToken, address pricingPool, bool uni, bool sushi) = getLargestPool(token,pricingTokens);
//      if (uni) {
//        priceVsPricingToken = getPriceVsTokenUni(token,pricingToken);
//      } else if (sushi) {
        priceVsPricingToken = getPriceVsTokenSushi(token,pricingToken);
//      } else {
//        priceVsPricingToken = getPriceVsTokenCurve(token,pricingToken,pricingPool);
//      }
//      pricingTokenPrice = (pricingToken == definedOutputToken)? 10**precisionDecimals:getPriceVsTokenUni(pricingToken,definedOutputToken);
      pricingTokenPrice = (pricingToken == definedOutputToken)? 10**precisionDecimals:getPriceVsTokenSushi(pricingToken,definedOutputToken);
      price = priceVsPricingToken*pricingTokenPrice/10**precisionDecimals;
    }
    return price;
  }

  //Checks if a given token is in the pricingTokens list.
  function checkPricingToken(address token) public view returns (bool) {
    uint256 i;
    for (i=0;i<pricingTokens.length;i++) {
      if (token == pricingTokens[i]) {
        return true;
      }
    }
    return false;
  }

  //Checks if a given token is in the keyTokens list.
  function checkKeyToken(address token) public view returns (bool) {
    uint256 i;
    for (i=0;i<keyTokens.length;i++) {
      if (token == keyTokens[i]) {
        return true;
      }
    }
    return false;
  }
}
