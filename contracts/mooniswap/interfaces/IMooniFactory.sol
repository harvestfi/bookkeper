pragma solidity >=0.5.0;

interface IMooniFactory {
  function isPool(address token) external view returns(bool);
}
