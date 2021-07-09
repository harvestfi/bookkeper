// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

//import "@openzeppelin/contracts/proxy/Initializable.sol"; //TODO do not compiled for some reason (Identifier already declared.)
import "./Storage.sol";

contract Governable {

  Storage public store;

  constructor(address _store) public {
    initialize(_store);
  }

  function initialize(address _store) public virtual onlyGovernance /*initializer*/ { //TODO enable initializer directive
    setStorage(_store);
  }

  modifier onlyGovernance() {
    // pass check while store is not initialized
    require((address(store)==address(0)) || store.isGovernance(msg.sender), "Not governance");
    _;
  }

  function setStorage(address _store) public onlyGovernance {
    require(_store != address(0), "new storage shouldn't be empty");
    store = Storage(_store);
  }

  function governance() public view returns (address) {
    return store.governance();
  }
}
