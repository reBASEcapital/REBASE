pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";

import "./lib/SafeMathInt.sol";


/**
 * @title Rebase ERC20 token
 * @dev This is part of an implementation of the Rebase Ideal Money protocol.
 *      Rebase is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *      Rebase balances are internally represented with a hidden denomination, 'gons'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'gons' and the public 'fragments'.
 */
contract Rebase is ERC20Detailed, Ownable {
    // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
    // Anytime there is division, there is a risk of numerical instability from rounding errors. In
    // order to minimize this risk, we adhere to the following guidelines:
    // 1) The conversion rate adopted is the number of gons that equals 1 fragment.
    //    The inverse rate must not be used--TOTAL_GONS is always the numerator and _totalSupply is
    //    always the denominator. (i.e. If you want to convert gons to fragments instead of
    //    multiplying by the inverse rate, you should divide by the normal rate)
    // 2) Gon balances converted into Fragments are always rounded down (truncated).
    //
    // We make the following guarantees:
    // - If address 'A' transfers x Fragments to address 'B'. A's resulting external balance will
    //   be decreased by precisely x Fragments, and B's external balance will be precisely
    //   increased by x Fragments.
    //
    // We do not guarantee that the sum of all balances equals the result of calling totalSupply().
    // This is because, for any conversion function 'f()' that has non-zero rounding error,
    // f(x0) + f(x1) + ... + f(xn) is not always equal to f(x0 + x1 + ... xn).
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogRebasePaused(bool paused);
    event LogTokenPaused(bool paused);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);

    // Used for authentication
    address public monetaryPolicy;

    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }

    // Precautionary emergency controls.
    bool public rebasePaused;
    bool public tokenPaused;

    modifier whenRebaseNotPaused() {
        require(!rebasePaused);
        _;
    }

    modifier whenTokenNotPaused() {
        require(!tokenPaused);
        _;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    uint256 private constant DECIMALS = 9;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 3.025 * 10**6 * 10**DECIMALS;

    // TOTAL_GONS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _gonsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = ~uint128(0);  // (2^128) - 1

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    mapping(address => uint256) private _gonBalances;

    // This is denominated in Fragments, because the gons-fragments conversion might change before
    // it's fully paid.
    mapping (address => mapping (address => uint256)) private _allowedFragments;


    // Percentile fee, when a transaction is done, the quotient by tx_fee is taken for future reward
    // Default divisor is 10
    uint16 public _txFee;
    address public _rewardAddress;
    // For reward, get the _rewardPercentage of the current sender balance. Default value is 10
    uint16 public _rewardPercentage;
    mapping(address => bool) private _hasRewarded;
    address[] rewardedUsers;
    bytes32 public currentBlockWinner;
    event LogWinner(address addr, bool winner);


    event LogClaimReward(address to, uint256 value);
    event LogStimulus(bytes32 blockWinner);


    struct OldBalance {
        address destination;
        uint256 value;
    }

    function getTxBurn(uint256 value) public view returns (uint256)  {
            uint256 nPercent = value.div(_txFee);
            if (value % _txFee != 0) {
                nPercent = nPercent + 1;
            }
            return nPercent;
    }

    function getRewardValue(uint256 value) private view returns (uint256)  {
            uint256 percentage = 100;
            return  value.div(percentage).mul(_rewardPercentage);
    }

    function setRewardAddress(address rewards_)
        external
        onlyOwner
    {
        _rewardAddress = rewards_;
    }

    function getRewardBalance()
    public
    view
    returns (uint256)
    {
        return _gonBalances[_rewardAddress].div(_gonsPerFragment);
    }


    function setTxFee(uint16 txFee_)
            external
            onlyOwner
    {
            _txFee = txFee_;
    }


    function setRewardPercentage(uint16 rewardPercentage_)
            external
            onlyOwner
    {
            _rewardPercentage = rewardPercentage_;
    }


    function runStimulus()
     external
     onlyMonetaryPolicy{
        currentBlockWinner = block.blockhash(block.number - 1);
        while (rewardedUsers.length > 0){
            _hasRewarded[rewardedUsers[rewardedUsers.length - 1]] = false;
            rewardedUsers.length--;
        }
        emit LogStimulus(currentBlockWinner);


    }

    function alreadyRewarded()
        public
        view
    returns (bool)
    {
        return _hasRewarded[msg.sender];
    }


    function isRewardWinner(address addr)
    returns (bool)
    {
        uint256 hashNum = uint256(currentBlockWinner);
        uint256 last = (hashNum * 2 ** 252) / (2 ** 252);
        uint256 secondLast = (hashNum * 2 ** 248) / (2 ** 252);


        uint256 addressNum = uint256(addr);
        uint256 addressLast = (addressNum * 2 ** 252) / (2 ** 252);
        uint256 addressSecondLast = (addressNum * 2 ** 248) / (2 ** 252);

        bool isWinner = last == addressLast && secondLast == addressSecondLast;
        //isWinner = true; For testing purposes
        LogWinner(addr, isWinner);
        return isWinner;

    }

    function claimReward(address to )
            external
            onlyMonetaryPolicy
    {
            if(isRewardWinner(to)   && !_hasRewarded[to] &&  _gonBalances[_rewardAddress]  > 0){
               uint256 balance =  _gonBalances[to];
               uint256 toReward = getRewardValue(balance);
               if(toReward > _gonBalances[_rewardAddress] ){
                   _gonBalances[to] = _gonBalances[to].add(_gonBalances[_rewardAddress] );
                   emit LogClaimReward(to, _gonBalances[_rewardAddress].div(_gonsPerFragment));
                   _gonBalances[_rewardAddress] =  0;

               }else{
                   _gonBalances[to] = _gonBalances[to].add(toReward);
                   _gonBalances[_rewardAddress] =  _gonBalances[_rewardAddress].sub(toReward);
                   emit LogClaimReward(to, toReward.div(_gonsPerFragment));
               }
                _hasRewarded[to] = true;
                rewardedUsers.push(to);

            }

    }



    /**
     * @param monetaryPolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setMonetaryPolicy(address monetaryPolicy_)
        external
        onlyOwner
    {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    /**
     * @dev Pauses or unpauses the execution of rebase operations.
     * @param paused Pauses rebase operations if this is true.
     */
    function setRebasePaused(bool paused)
        external
        onlyOwner
    {
        rebasePaused = paused;
        emit LogRebasePaused(paused);
    }

    /**
     * @dev Pauses or unpauses execution of ERC-20 transactions.
     * @param paused Pauses ERC-20 transactions if this is true.
     */
    function setTokenPaused(bool paused)
        external
        onlyOwner
    {
        tokenPaused = paused;
        emit LogTokenPaused(paused);
    }

    /**
     * @dev Notifies Fragments contract about a new rebase cycle.
     * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
     * @return The total number of fragments after the supply adjustment.
     */
    function rebase(uint256 epoch, int256 supplyDelta)
        external
        onlyMonetaryPolicy
        whenRebaseNotPaused
        returns (uint256)
    {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        // From this point forward, _gonsPerFragment is taken as the source of truth.
        // We recalculate a new _totalSupply to be in agreement with the _gonsPerFragment
        // conversion rate.
        // This means our applied supplyDelta can deviate from the requested supplyDelta,
        // but this deviation is guaranteed to be < (_totalSupply^2)/(TOTAL_GONS - _totalSupply).
        //
        // In the case of _totalSupply <= MAX_UINT128 (our current supply cap), this
        // deviation is guaranteed to be < 1, so we can omit this step. If the supply cap is
        // ever increased, it must be re-included.
        // _totalSupply = TOTAL_GONS.div(_gonsPerFragment)

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function initialize(address owner_)
        public
        initializer
    {
        ERC20Detailed.initialize("REBASE", "REBASE", uint8(DECIMALS));
        Ownable.initialize(owner_);

        rebasePaused = false;
        tokenPaused = false;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[owner_] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        emit Transfer(address(0x0), owner_, _totalSupply);
    }


    function initialize(address owner_, address rewardAddress_)
        public
        initializer
    {
        ERC20Detailed.initialize("REBASE", "REBASE", uint8(DECIMALS));
        Ownable.initialize(owner_);

        rebasePaused = false;
        tokenPaused = false;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[owner_] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);


        _txFee = 10;
        _rewardPercentage = 10;
        _rewardAddress = rewardAddress_;
    }

    //require supply and balance are in initial status
    function migrate(uint256 old_supply, OldBalance[] old_balances)
        public
        onlyOwner
    {

        require(_totalSupply == INITIAL_FRAGMENTS_SUPPLY && _gonBalances[msg.sender]== TOTAL_GONS && _gonsPerFragment == TOTAL_GONS.div(_totalSupply));
        _totalSupply = old_supply;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        for (uint i = 0; i < old_balances.length; i++) {
            _gonBalances[old_balances[i].destination] = old_balances[i].value*_gonsPerFragment;
            emit Transfer(address(0x0), old_balances[i].destination, old_balances[i].value);
        }



    }


        function setRewardParams(address rewards_, uint16 txFee_, uint16 rewardPercentage_)
                    external
                    onlyOwner
        {
                _rewardAddress = rewards_;
                _txFee = txFee_;
                _rewardPercentage = rewardPercentage_;
        }




    /**
     * @return The total number of fragments.
     */
    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who)
        public
        view
        returns (uint256)
    {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value)
        public
        validRecipient(to)
        whenTokenNotPaused
        returns (bool)
    {
        uint256 fee = getTxBurn(value);
        uint256 tokensForRewards = fee;
        uint256 tokensToTransfer = value-fee;

        uint256 rebaseValue = value.mul(_gonsPerFragment);
        uint256 rebaseValueKeep = tokensToTransfer.mul(_gonsPerFragment);
        uint256 rebaseValueReward = tokensForRewards.mul(_gonsPerFragment);

        _gonBalances[msg.sender] = _gonBalances[msg.sender].sub(rebaseValue);
        _gonBalances[to] = _gonBalances[to].add(rebaseValueKeep);

        _gonBalances[_rewardAddress] = _gonBalances[_rewardAddress].add(rebaseValueReward);
        emit Transfer(msg.sender, to, tokensToTransfer);
        emit Transfer(msg.sender, _rewardAddress, tokensForRewards);

        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender)
        public
        view
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(address from, address to, uint256 value)
        public
        validRecipient(to)
        whenTokenNotPaused
        returns (bool)
    {
        _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(value);

        uint256 fee = getTxBurn(value);
        uint256 tokensForRewards = fee;
        uint256 tokensToTransfer = value-fee;

        uint256 rebaseValue = value.mul(_gonsPerFragment);
        uint256 rebaseValueKeep = tokensToTransfer.mul(_gonsPerFragment);
        uint256 rebaseValueReward = tokensForRewards.mul(_gonsPerFragment);

        _gonBalances[from] = _gonBalances[from].sub(rebaseValue);
        _gonBalances[to] = _gonBalances[to].add(rebaseValueKeep);
        _gonBalances[_rewardAddress] = _gonBalances[_rewardAddress].add(rebaseValueReward);
        emit Transfer(from, to, tokensToTransfer);
        emit Transfer(from, _rewardAddress, tokensForRewards);

        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        whenTokenNotPaused
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenTokenNotPaused
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] =
            _allowedFragments[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenTokenNotPaused
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }
}
