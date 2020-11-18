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
    // current biki price
    uint256 public bPrice;
    // last updated biki price time in seconds
    uint256 public lastBPriceUpdated;
    // min accepted updated biki time to fetch an average price
    uint256 public minBPriceTime;

    uint256 private constant DECIMALS = 18;
    // address for get price in uniswap
    address public liquidityPool;


    function initialize(address owner_)
    public
    initializer
    {
        Ownable.initialize(owner_);
        lastBPriceUpdated = 0;
        minBPriceTime = 3600;
    }


    function getUniswapPrice()
    public
    returns (uint256)
    {

        uint256 exchangeRate;
        bool isToken0 = false;
        (uint priceCumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentPrice(liquidityPool, isToken0);
        FixedPoint.uq112x112 memory priceFixedPoint = FixedPoint.uq112x112(uint224(priceCumulative));
        exchangeRate =  FixedPoint.decode144(FixedPoint.mul(priceFixedPoint, 10**18));
        return exchangeRate;


    }

    function getUniswapPriceReverse()
    external
    returns (uint256)
    {

        uint256 exchangeRate;
        bool isToken0 = true;
        (uint priceCumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentPrice(liquidityPool, isToken0);
        FixedPoint.uq112x112 memory priceFixedPoint = FixedPoint.uq112x112(uint224(priceCumulative));
        exchangeRate =  FixedPoint.decode144(FixedPoint.mul(priceFixedPoint, 10**18));
        return exchangeRate;


    }


    function setLiquidityPool(address liquidityPool_)
    public
    onlyOwner
    {
        liquidityPool = liquidityPool_;
    }

    function getData()
    external
    returns (uint256, bool)
    {
        bool validity = now  - lastBPriceUpdated < minBPriceTime ;
        price = getUniswapPrice().add(bPrice).div(2);
        emit LogPrice(price,validity);
        return (price, validity);
    }


    function setBPrice(uint256 data)
    public
    onlyOwner
    {
        bPrice = data;
        lastBPriceUpdated = now;
    }

    function setMinBPriceTime(uint256 data)
    public
    onlyOwner
    {
        minBPriceTime = data;
    }



}
