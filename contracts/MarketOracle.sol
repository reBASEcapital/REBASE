pragma solidity 0.4.24;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";

import "./lib/SafeMathInt.sol";
import "./lib/UInt256Lib.sol";
import "./lib/UniswapV2OracleLibrary.sol";
import "./lib/FixedPoint.sol";
import "./Rebase.sol";


contract MarketOracle is Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;

    event LogPrice(
        uint256 indexed price,
        bool validity
    );

    // current averagePrice between uniswap and biki
    uint256 public price;
    // last updated price time in seconds
    uint256 public lastPriceUpdated;
    // min accepted updated time to fetch an average price
    uint256 public minPriceTime;

    uint256 private constant DECIMALS = 18;
    // address for get price in uniswap
    address public liquidityPool;


    uint public constant PERIOD = 24 hours;


    function initialize(address owner_, uint256 price_)
    public
    initializer
    {
        Ownable.initialize(owner_);
        lastPriceUpdated = 0;
        minPriceTime = 86400;
        priceUpdater = owner_;
        price = price_;
    }

    address public priceUpdater;

    modifier onlyPriceUpdater() {
        require(msg.sender == priceUpdater);
        _;
    }


    function getUniswapPrice()
    public
    returns (uint256)
    {

        bool isToken0 = false;
        (uint priceCumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentPrice(liquidityPool, isToken0);
        FixedPoint.uq112x112 memory priceFixedPoint = FixedPoint.uq112x112(uint224(priceCumulative));
        return FixedPoint.decode144(FixedPoint.mul(priceFixedPoint, 10**18));


    }

    function setLiquidityPool(address liquidityPool_)
    public
    onlyOwner
    {
        liquidityPool = liquidityPool_;
    }

    function setPriceUpdater(address priceUpdater_)
    public
    onlyOwner
    {
        priceUpdater = priceUpdater_;
    }

    function getData()
    external
    returns (uint256, bool)
    {
        bool validity = now  - lastPriceUpdated < minPriceTime ;
        emit LogPrice(price,validity);
        return (price, validity);
    }


    function setPrice(uint256 data)
    public
    onlyPriceUpdater
    {
        price = data;
        lastPriceUpdated = now;
    }

    function setMinPriceTime(uint256 data)
    public
    onlyOwner
    {
        minPriceTime = data;
    }



}
