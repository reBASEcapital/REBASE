pragma solidity 0.4.24;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";

import "./lib/SafeMathInt.sol";
import "./lib/UInt256Lib.sol";
import "./lib/UniswapV2OracleLibrary.sol";
import "./lib/FixedPoint.sol";
import "./Rebase.sol";


contract MarketOracleV1 is Ownable {
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


    uint public constant PERIOD = 24 hours;

    uint[]    public priceCumulativeLast;
    uint32[]  public blockTimestampLast;
    uint256[] public priceAverage;


    function initialize(address owner_, address liquidityPool_)
    public
    initializer
    {
        Ownable.initialize(owner_);
        lastBPriceUpdated = 0;
        minBPriceTime = 3600;
        liquidityPool = liquidityPool_;
        initializeUniswapTwap();
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

    function initializeUniswapTwap()
    public
    onlyOwner
    {
        bool isToken0 = false;
        (uint priceCumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(liquidityPool, isToken0);
        uint256 avgIni = getUniswapPrice();
        if(priceCumulativeLast.length == 0){
            for (uint i = 0; i < 24; i++) {
                priceCumulativeLast.push(priceCumulative);
                blockTimestampLast.push(blockTimestamp);
                priceAverage.push(avgIni);
            }
        } else{
            for (uint j = 0; j < 24; j++) {
                priceCumulativeLast[j] = priceCumulative;
                blockTimestampLast[j] = blockTimestamp;
                priceAverage[j] = avgIni;
            }
        }

    }


    function updateUniswapTwap()
    public
    returns (uint256)
    {
        bool isToken0 = false;
        (uint priceCumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(liquidityPool, isToken0);
        uint hourRate = uint8((now / 60 / 60) % 24);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast[hourRate]; // overflow is desired
        if (timeElapsed >= PERIOD ){
            priceAverage[hourRate] = FixedPoint.decode144(FixedPoint.mul(FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast[hourRate]) / timeElapsed)), 10**18));
            blockTimestampLast[hourRate]=blockTimestamp;
            priceCumulativeLast[hourRate] = priceCumulative;
        }
        return priceAverage[hourRate];
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
        price = updateUniswapTwap().add(bPrice).div(2);
        emit LogPrice(price,validity);
        return (price, validity);
    }


    function setBPrice(uint256 data)
    public
    onlyOwner
    {
        bPrice = data;
        lastBPriceUpdated = now;
        updateUniswapTwap();
    }

    function setMinBPriceTime(uint256 data)
    public
    onlyOwner
    {
        minBPriceTime = data;
    }



}
