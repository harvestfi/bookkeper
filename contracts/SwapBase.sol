// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Governable.sol";

pragma solidity 0.6.12;

abstract contract SwapBase is Governable {

  using Address for address;
  using SafeMath for uint256;

  uint256 public precisionDecimals = 18;

  address factoryAddress;

  event FactoryChanged(address newFactory, address oldFactory);

  constructor(address _factoryAddress, address _storage) Governable(_storage) public {
    factoryAddress = _factoryAddress;
    if (factoryAddress!=address(0)) initializeFactory();
  }

  function initializeFactory() public virtual;

  function changeFactory(address newFactory) external onlyGovernance {
    address oldFactory = factoryAddress;
    factoryAddress = newFactory;
    if (factoryAddress!=address(0)) initializeFactory();
    emit FactoryChanged(newFactory, oldFactory);
  }

  /// @dev Check what token is pool of this Swap
  function isPool(address token) public virtual view returns(bool);

  /// @dev Get underlying tokens and amounts
  function getUnderlying(address token) public virtual view returns (address[] memory, uint256[] memory);

  /// @dev Gives a pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  function getLargestPool(address token, address[] memory tokenList) public virtual view returns (address, address, uint256);
  // return (largestKeyToken, largestPoolAddress, largestPoolSize);

  /// @dev Generic function giving the price of a given token vs another given token
  function getPriceVsToken(address token0, address token1, address poolAddress) public virtual view returns (uint256) ;

}
