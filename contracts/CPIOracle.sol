pragma solidity 0.4.24;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";

import "./lib/SafeMathInt.sol";
import "./lib/UInt256Lib.sol";
import "./Rebase.sol";


contract CPIOracle is Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;

    event LogCPI(
        uint256 indexed cpi,
        bool validity
    );

    // cpi value, in order to get target =1, cpi and baseCpi must have the same value
    uint256 public cpi;

    uint256 private constant DECIMALS = 18;


    function initialize(address owner_, uint256 cpi_)
    public
    initializer
    {
        Ownable.initialize(owner_);
        cpi = cpi_;
    }


    function getData()
    external
    returns (uint256, bool)
    {
        bool validity = cpi > 0 ;
        emit LogCPI(cpi,validity);
        return (cpi, validity);
    }


    function setCPIValue(uint256 data)
    public
    onlyOwner
    {
        cpi = data;
    }

}
