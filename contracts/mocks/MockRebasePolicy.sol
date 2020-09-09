pragma solidity 0.4.24;

import "./Mock.sol";


contract MockRebasePolicy is Mock {

    function rebase() external {
        emit FunctionCalled("RebasePolicy", "rebase", msg.sender);
    }
}
