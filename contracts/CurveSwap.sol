// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Governable.sol";

import "./interface/curve/ICurvePool.sol";
import "./interface/curve/ICurveRegistry.sol";
import "./SwapBase.sol";

pragma solidity 0.6.12;

abstract contract CurveSwap is SwapBase {

  ICurveRegistry public curveRegistry;

  //Below are addresses of LP tokens for which it is known that the get_underlying functions of Curve Registry do not work because of errors in the Curve contract.
  //The exceptions are split. In the first exception the get_underlying_coins is called with get_balances.
  //In the second exception get_coins and get_balances are called.
  address[] public curveExceptionList0;
  address[] public curveExceptionList1;

  address public ETH  = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public WETH = address(0);


  modifier validException(address exception){
    (bool check0, bool check1) = checkCurveException(exception);
    require(check0 || check1, "Not an exception");
    _;
  }

  event CurveExceptionAdded(address newException, uint256 exceptionList);
  event CurveExceptionRemoved(address oldException, uint256 exceptionList);

  constructor(address _factoryAddress, address _storage, address _WETH, address[] _exceptionList0, address[] _exceptionList1) SwapBase(_factoryAddress, _storage) public {
    curveExceptionList0 = _exceptionList0;
    curveExceptionList1 = _exceptionList1;
    WETH = _WETH;
  }

  function initializeFactory() public virtual;

  function changeFactory(address newFactory) external onlyGovernance {
    address oldFactory = factoryAddress;
    factoryAddress = newFactory;
    if (factoryAddress!=address(0)) initializeFactory();
    emit FactoryChanged(newFactory, oldFactory);
  }

  /// @dev  Check what token is pool of this Swap
  function isPool(address token) public virtual view returns(bool){
    address pool = curveRegistry.get_pool_from_lp_token(token);
    bool check = (pool != address(0))? true:false;
    return check;
  }

  /// @dev  Get underlying tokens and amounts
  function getUnderlying(address token) public virtual view returns (address[] memory, uint256[] memory){
    address pool = curveRegistry.get_pool_from_lp_token(token);
    (bool exception0, bool exception1) = checkCurveException(token);
    address[8] memory tokens;
    uint256[8] memory reserves;
    if (exception0) {
      tokens = curveRegistry.get_underlying_coins(pool);
      reserves = curveRegistry.get_balances(pool);
    } else if (exception1) {
      tokens = curveRegistry.get_coins(pool);
      reserves = curveRegistry.get_balances(pool);
    } else {
      tokens = curveRegistry.get_underlying_coins(pool);
      reserves = curveRegistry.get_underlying_balances(pool);
    }

    //Some pools work with ETH instead of WETH. For further calculations and functionality this is changed to WETH address.
    uint256[8] memory decimals;
    uint256 i;
    uint256 totalSupply = IERC20(token).totalSupply();
    uint256 supplyDecimals = ERC20(token).decimals();
    uint256[8] memory amounts;
    for (i=0;i<tokens.length;i++) {
      if (tokens[i] == address(0)){
        break;
      } else if (tokens[i]==ETH){
        decimals[i] = 18;
        tokens[i] = WETH;
      } else {
        decimals[i] = ERC20(tokens[i]).decimals();
      }

      amounts[i] = reserves[i]*10**(supplyDecimals-decimals[i]+precisionDecimals)/totalSupply;
      //Curve has errors in their registry, where amounts are stored with the wrong number of decimals
      //This steps accounts for this. In general there will never be more than 1 of any underlying token
      //per curve LP token. If it is more, the decimals are corrected.
      if (amounts[i] > 10**precisionDecimals) {
        amounts[i] = amounts[i]*10**(decimals[i]-18);
      }
    }
    return (tokens, amounts);
  }

  /// @dev Returns pool size
  function getPoolSize(address pairAddress, address token) public virtual view returns(uint256);

  /// @dev Gives a pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  //Gives the Curve pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  //Curve can have multiple pools for a given pair. Research showed that the largest pool is always given as first instance, so only the first needs to be called.
  //In Curve USD based tokens are often pooled with 3Pool. In this case liquidity is the same with USDC, DAI and USDT. When liquidity is found with USDC
  //the loop is stopped, as no larger liquidity will be found with any other asset and this reduces calls.
  function getLargestPool(address token, address[] memory tokenList) internal view returns (address, address, uint256){
    uint256 largestPoolSize = 0;
    address largestPoolAddress;
    address largestKeyToken;
    uint256 poolSize;
    uint256 i;
    for (i=0;i<tokenList.length;i++) {
      address poolAddress = curveRegistry.find_pool_for_coins(token, tokenList[i],0);
      if (poolAddress == address(0)) {
        continue;
      }
      address lpToken = curveRegistry.get_lp_token(poolAddress);
      (bool exception0,) = checkCurveException(lpToken);
      if (exception0) {
        continue;
      }
      poolSize = getBalance(token, tokenList[i], poolAddress);
      if (poolSize > largestPoolSize) {
        largestPoolSize = poolSize;
        largestKeyToken = tokenList[i];
        largestPoolAddress = poolAddress;
        if (largestKeyToken == definedOutputToken) {
          return (largestKeyToken, largestPoolAddress, largestPoolSize);
        }
      }
    }
    return (largestKeyToken, largestPoolAddress, largestPoolSize);
  }

  /// @dev Gives the balance of a given token in a given pool.
  function getBalance(address tokenFrom, address tokenTo, address pool) internal view returns (uint256){
    uint256 balance;
    (int128 indexFrom,,bool underlying) = curveRegistry.get_coin_indices(pool, tokenFrom, tokenTo);
    uint256[8] memory balances;
    if (underlying) {
      balances = curveRegistry.get_underlying_balances(pool);
      uint256 decimals = ERC20(tokenFrom).decimals();
      balance = balances[uint256(indexFrom)];
      if (balance > 10**(decimals+10)) {
        balance = balance*10**(decimals-18);
      }
    } else {
      balances = curveRegistry.get_balances(pool);
      balance = balances[uint256(indexFrom)];
    }
    return balance;
  }

  /// @dev Generic function giving the price of a given token vs another given token
  function getPriceVsToken(address token0, address token1, address poolAddress) internal view returns (uint256) {
    ICurvePool pool = ICurvePool(poolAddress);
    (int128 indexFrom, int128 indexTo, bool underlying) = curveRegistry.get_coin_indices(poolAddress, token0, token1);
    uint256 decimals0 = ERC20(token0).decimals();
    uint256 decimals1 = ERC20(token1).decimals();
    //Accuracy is impacted when one of the tokens has low decimals.
    //This addition does not impact the outcome of computation, other than increased accuracy.
    if (decimals0 < 4 || decimals1 < 4) {
      decimals0 = decimals0 + 4;
      decimals1 = decimals1 + 4;
    }
    uint256 amount1;
    uint256 price;
    if (underlying) {
      amount1 = pool.get_dy_underlying(indexFrom, indexTo, 10**decimals0);
      price = amount1*10**(precisionDecimals-decimals1);
    } else {
      amount1 = pool.get_dy(indexFrom, indexTo, 10**decimals0);
      price = amount1*10**(precisionDecimals-decimals1);
    }
    return price;
  }


  function addCurveException(address newException, uint256 exceptionList) external onlyGovernance {
    (bool check0, bool check1) = checkCurveException(newException);
    require(check0==false && check1 == false, "Already an exception");
    require(exceptionList <= 1, 'Only accepts 0 or 1');
    if (exceptionList == 0) {
      curveExceptionList0.push(newException);
    } else {
      curveExceptionList1.push(newException);
    }
    emit CurveExceptionAdded(newException, exceptionList);
  }
  function removeCurveException(address exception) external onlyGovernance validException(exception) {
    (bool check0,) = checkCurveException(exception);
    uint256 i;
    uint256 j;
    uint256 list;
    if (check0) {
      list = 0;
      for (i=0;i<curveExceptionList0.length;i++) {
        if (exception == curveExceptionList0[i]){
          break;
        }
      }
      while (i<curveExceptionList0.length-1) {
        curveExceptionList0[i] = curveExceptionList0[i+1];
        i++;
      }
      curveExceptionList0.pop();
    } else {
      list = 1;
      for (j=0;j<curveExceptionList1.length;j++) {
        if (exception == curveExceptionList1[j]){
          break;
        }
      }
      while (j<curveExceptionList1.length-1) {
        curveExceptionList1[j] = curveExceptionList1[j+1];
        j++;
      }
      curveExceptionList1.pop();
    }
    emit CurveExceptionRemoved(exception, list);
  }

  //Check address for the Curve exception lists.
  function checkCurveException(address token) internal view returns (bool, bool) {
    uint256 i;
    for (i=0;i<curveExceptionList0.length;i++) {
      if (token == curveExceptionList0[i]) {
        return (true, false);
      }
    }
    for (i=0;i<curveExceptionList1.length;i++) {
      if (token == curveExceptionList1[i]) {
        return (false, true);
      }
    }
    return (false, false);
  }

}