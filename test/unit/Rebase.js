const Rebase = artifacts.require('Rebase.sol');
const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);
const BigNumber = web3.BigNumber;
const encodeCall = require('zos-lib/lib/helpers/encodeCall').default;

require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

function toUFrgDenomination (x) {
  return new BigNumber(x).mul(10 ** DECIMALS);
}
const DECIMALS = 9;
const INTIAL_SUPPLY = toUFrgDenomination(3.025 * 10 ** 6);
const transferAmount = toUFrgDenomination(10);
const unitTokenAmount = toUFrgDenomination(1);
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

let reBase, b, r, deployer, user, initialSupply;
async function setupContracts () {
  const accounts = await chain.getUserAccounts();
  deployer = accounts[0];
  user = accounts[1];
  reBase = await Rebase.new();
  r = await reBase.sendTransaction({
    data: encodeCall('initialize', ['address'], [deployer]),
    from: deployer
  });
  initialSupply = await reBase.totalSupply.call();
}

contract('Rebase', function (accounts) {
  before('setup Rebase contract', setupContracts);

  it('should reject any ether sent to it', async function () {
    expect(
      await chain.isEthException(reBase.sendTransaction({ from: user, value: 1 }))
    ).to.be.true;
  });
});

contract('Rebase:Initialization', function (accounts) {
  before('setup Rebase contract', setupContracts);

  it('should transfer 50M reBase to the deployer', async function () {
    (await reBase.balanceOf.call(deployer)).should.be.bignumber.eq(INTIAL_SUPPLY);
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('Transfer');
    expect(log.args.from).to.eq(ZERO_ADDRESS);
    expect(log.args.to).to.eq(deployer);
    log.args.value.should.be.bignumber.eq(INTIAL_SUPPLY);
  });

  it('should set the totalSupply to 50M', async function () {
    initialSupply.should.be.bignumber.eq(INTIAL_SUPPLY);
  });

  it('should set the owner', async function () {
    expect(await reBase.owner.call()).to.eq(deployer);
  });

  it('should set detailed ERC20 parameters', async function () {
    expect(await reBase.name.call()).to.eq('REBASE');
    expect(await reBase.symbol.call()).to.eq('REBASE');
    (await reBase.decimals.call()).should.be.bignumber.eq(DECIMALS);
  });

  it('should have 9 decimals', async function () {
    const decimals = await reBase.decimals.call();
    decimals.should.be.bignumber.eq(DECIMALS);
  });

  it('should have REBASE symbol', async function () {
    const symbol = await reBase.symbol.call();
    symbol.should.be.eq('REBASE');
  });
});

contract('Rebase:setMonetaryPolicy', function (accounts) {
  const policy = accounts[1];

  before('setup Rebase contract', setupContracts);

  it('should set reference to policy contract', async function () {
    await reBase.setMonetaryPolicy(policy, { from: deployer });
    expect(await reBase.monetaryPolicy.call()).to.eq(policy);
  });

  it('should emit policy updated event', async function () {
    const r = await reBase.setMonetaryPolicy(policy, { from: deployer });
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogMonetaryPolicyUpdated');
    expect(log.args.monetaryPolicy).to.eq(policy);
  });
});

contract('Rebase:setMonetaryPolicy:accessControl', function (accounts) {
  const policy = accounts[1];

  before('setup Rebase contract', setupContracts);

  it('should be callable by owner', async function () {
    expect(
      await chain.isEthException(reBase.setMonetaryPolicy(policy, { from: deployer }))
    ).to.be.false;
  });
});

contract('Rebase:setMonetaryPolicy:accessControl', function (accounts) {
  const policy = accounts[1];
  const user = accounts[2];

  before('setup Rebase contract', setupContracts);

  it('should NOT be callable by non-owner', async function () {
    expect(
      await chain.isEthException(reBase.setMonetaryPolicy(policy, { from: user }))
    ).to.be.true;
  });
});


contract('Rebase:setRewardAddress:accessControl', function (accounts) {
  const rewardAddress = accounts[4];

  before('setup Rebase contract', setupContracts);

  it('should be callable by owner', async function () {
    expect(
        await chain.isEthException(reBase.setRewardAddress(rewardAddress, { from: deployer }))
    ).to.be.false;
  });
});

contract('Rebase:setRewardAddress:accessControl', function (accounts) {
  const rewardAddress = accounts[4];
  const user = accounts[2];

  before('setup Rebase contract', setupContracts);

  it('should NOT be callable by non-owner', async function () {
    expect(
        await chain.isEthException(reBase.setRewardAddress(rewardAddress, { from: user }))
    ).to.be.true;
  });
});


contract('Rebase:setBlockHashWinners:accessControl', function (accounts) {

  before('setup Rebase contract', setupContracts);

  it('should be callable by owner', async function () {
    expect(
        await chain.isEthException(reBase.setBlockHashWinners( { from: deployer }))
    ).to.be.false;
  });
});

contract('Rebase:setBlockHashWinners:accessControl', function (accounts) {
  const user = accounts[2];

  before('setup Rebase contract', setupContracts);

  it('should NOT be callable by non-owner', async function () {
    expect(
        await chain.isEthException(reBase.setBlockHashWinners( { from: user }))
    ).to.be.true;
  });
});

contract('Rebase:isRewardWinner', function (accounts) {
  const user = accounts[2];

  before('setup Rebase contract', setupContracts);

  it('should NOT be winner', async function () {

    await  reBase.setBlockHashWinners( { from: deployer})
    const winner = await  reBase.isRewardWinner( user, { from: deployer });
    expect(winner.logs[0].args.winner).to.be.false;
  });


  it('should be winner', async function () {

    await  reBase.setBlockHashWinners( { from: deployer})
    const blockHash  = await reBase.currentBlockWinner.call();
    const winnerUser = (user+"").slice(0,-2) + (blockHash + "").slice(-2)
    const winner = await  reBase.isRewardWinner( winnerUser, { from: deployer })
    expect(winner.logs[0].args.winner).to.be.true;
  });
});

contract('Rebase:PauseRebase', function (accounts) {
  const policy = accounts[1];
  const rewardAddress = accounts[4];
  const A = accounts[2];
  const B = accounts[3];

  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(policy, {from: deployer});
    await reBase.setRewardAddress(rewardAddress, {from: deployer});
    r = await reBase.setRebasePaused(true);
  });

  it('should emit pause event', async function () {
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogRebasePaused');
    expect(log.args.paused).to.be.true;
  });

  it('should not allow calling rebase', async function () {
    expect(
      await chain.isEthException(reBase.rebase(1, toUFrgDenomination(500), { from: policy }))
    ).to.be.true;
  });

  it('should allow calling transfer', async function () {
    await reBase.transfer(A, transferAmount, { from: deployer });
  });

  it('should allow calling approve', async function () {
    await reBase.approve(A, transferAmount, { from: deployer });
  });

  it('should allow calling allowance', async function () {
    await reBase.allowance.call(deployer, A);
  });

  it('should allow calling transferFrom', async function () {
    await reBase.transferFrom(deployer, B, transferAmount, {from: A});
  });

  it('should allow calling increaseAllowance', async function () {
    await reBase.increaseAllowance(A, transferAmount, {from: deployer});
  });

  it('should allow calling decreaseAllowance', async function () {
    await reBase.decreaseAllowance(A, 10, {from: deployer});
  });

  it('should allow calling balanceOf', async function () {
    await reBase.balanceOf.call(deployer);
  });

  it('should allow calling totalSupply', async function () {
    await reBase.totalSupply.call();
  });
});

contract('Rebase:PauseRebase:accessControl', function (accounts) {
  before('setup Rebase contract', setupContracts);

  it('should be callable by owner', async function () {
    expect(
      await chain.isEthException(reBase.setRebasePaused(true, { from: deployer }))
    ).to.be.false;
  });

  it('should NOT be callable by non-owner', async function () {
    expect(
      await chain.isEthException(reBase.setRebasePaused(true, { from: user }))
    ).to.be.true;
  });
});

contract('Rebase:PauseToken', function (accounts) {
  const policy = accounts[1];
  const rewardAddress = accounts[5];
  const A = accounts[2];
  const B = accounts[3];

  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(policy, {from: deployer});
    await reBase.setRewardAddress(rewardAddress, {from: deployer});
    r = await reBase.setTokenPaused(true);
  });

  it('should emit pause event', async function () {
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogTokenPaused');
    expect(log.args.paused).to.be.true;
  });

  it('should allow calling rebase', async function () {
    await reBase.rebase(1, toUFrgDenomination(500), { from: policy });
  });

  it('should not allow calling transfer', async function () {
    expect(
      await chain.isEthException(reBase.transfer(A, transferAmount, { from: deployer }))
    ).to.be.true;
  });

  it('should not allow calling approve', async function () {
    expect(
      await chain.isEthException(reBase.approve(A, transferAmount, { from: deployer }))
    ).to.be.true;
  });

  it('should allow calling allowance', async function () {
    await reBase.allowance.call(deployer, A);
  });

  it('should not allow calling transferFrom', async function () {
    expect(
      await chain.isEthException(reBase.transferFrom(deployer, B, transferAmount, {from: A}))
    ).to.be.true;
  });

  it('should not allow calling increaseAllowance', async function () {
    expect(
      await chain.isEthException(reBase.increaseAllowance(A, transferAmount, {from: deployer}))
    ).to.be.true;
  });

  it('should not allow calling decreaseAllowance', async function () {
    expect(
      await chain.isEthException(reBase.decreaseAllowance(A, transferAmount, {from: deployer}))
    ).to.be.true;
  });

  it('should allow calling balanceOf', async function () {
    await reBase.balanceOf.call(deployer);
  });

  it('should allow calling totalSupply', async function () {
    await reBase.totalSupply.call();
  });
});

contract('Rebase:PauseToken:accessControl', function (accounts) {
  before('setup Rebase contract', setupContracts);

  it('should be callable by owner', async function () {
    expect(
      await chain.isEthException(reBase.setTokenPaused(true, { from: deployer }))
    ).to.be.false;
  });

  it('should NOT be callable by non-owner', async function () {
    expect(
      await chain.isEthException(reBase.setTokenPaused(true, { from: user }))
    ).to.be.true;
  });
});

contract('Rebase:Rebase:accessControl', function (accounts) {
  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(user, {from: deployer});
  });

  it('should be callable by monetary policy', async function () {
    expect(
      await chain.isEthException(reBase.rebase(1, transferAmount, { from: user }))
    ).to.be.false;
  });

  it('should not be callable by others', async function () {
    expect(
      await chain.isEthException(reBase.rebase(1, transferAmount, { from: deployer }))
    ).to.be.true;
  });
});

contract('Rebase:Rebase:Expansion', function (accounts) {
  // Rebase +302,500 (10%), with starting balances A:10 and B:20.
  const A = accounts[2];
  const B = accounts[3];
  const policy = accounts[1];
  const rewardAddress = accounts[5];
  const rebaseAmt = INTIAL_SUPPLY / 10;

  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(policy, {from: deployer});
    await reBase.setRewardAddress(rewardAddress, {from: deployer});
    await reBase.transfer(A, toUFrgDenomination(10), { from: deployer });
    await reBase.transfer(B, toUFrgDenomination(20), { from: deployer });
    r = await reBase.rebase(1, rebaseAmt, {from: policy});
  });

  it('should increase the totalSupply', async function () {
    b = await reBase.totalSupply.call();
    b.should.be.bignumber.eq(initialSupply.plus(rebaseAmt));
  });

  it('should increase individual balances', async function () {
    b = await reBase.balanceOf.call(A);
    const fee = parseInt( await reBase._txFee.call());
    b.should.be.bignumber.eq(toUFrgDenomination(11-11/fee));

    b = await reBase.balanceOf.call(B);
    b.should.be.bignumber.eq(toUFrgDenomination(22-22/fee));
  });

  it('should emit Rebase', async function () {
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogRebase');
    log.args.epoch.should.be.bignumber.eq(1);
    log.args.totalSupply.should.be.bignumber.eq(initialSupply.plus(rebaseAmt));
  });

  it('should return the new supply', async function () {
    const returnVal = await reBase.rebase.call(2, rebaseAmt, {from: policy});
    await reBase.rebase(2, rebaseAmt, {from: policy});
    const supply = await reBase.totalSupply.call();
    returnVal.should.be.bignumber.eq(supply);
  });
});

contract('Rebase:Rebase:Expansion', function (accounts) {
  const policy = accounts[1];
  const rewardAddress = accounts[5];
  const MAX_SUPPLY = new BigNumber(2).pow(128).minus(1);

  describe('when totalSupply is less than MAX_SUPPLY and expands beyond', function () {
    before('setup Rebase contract', async function () {
      await setupContracts();
      await reBase.setMonetaryPolicy(policy, {from: deployer});
      await reBase.setRewardAddress(rewardAddress, {from: deployer});
      const totalSupply = await reBase.totalSupply.call();
      await reBase.rebase(1, MAX_SUPPLY.minus(totalSupply).minus(toUFrgDenomination(1)), {from: policy});
      r = await reBase.rebase(2, toUFrgDenomination(2), {from: policy});
    });

    it('should increase the totalSupply to MAX_SUPPLY', async function () {
      b = await reBase.totalSupply.call();
      b.should.be.bignumber.eq(MAX_SUPPLY);
    });

    it('should emit Rebase', async function () {
      const log = r.logs[0];
      expect(log).to.exist;
      expect(log.event).to.eq('LogRebase');
      expect(log.args.epoch.toNumber()).to.eq(2);
      log.args.totalSupply.should.be.bignumber.eq(MAX_SUPPLY);
    });
  });

  describe('when totalSupply is MAX_SUPPLY and expands', function () {
    before(async function () {
      b = await reBase.totalSupply.call();
      b.should.be.bignumber.eq(MAX_SUPPLY);
      r = await reBase.rebase(3, toUFrgDenomination(2), {from: policy});
    });

    it('should NOT change the totalSupply', async function () {
      b = await reBase.totalSupply.call();
      b.should.be.bignumber.eq(MAX_SUPPLY);
    });

    it('should emit Rebase', async function () {
      const log = r.logs[0];
      expect(log).to.exist;
      expect(log.event).to.eq('LogRebase');
      expect(log.args.epoch.toNumber()).to.eq(3);
      log.args.totalSupply.should.be.bignumber.eq(MAX_SUPPLY);
    });
  });
});

contract('Rebase:Rebase:NoChange', function (accounts) {
  // Rebase (0%), with starting balances A:750 and B:250.
  const A = accounts[2];
  const B = accounts[3];
  const policy = accounts[1];
  const rewardAddress = accounts[5];

  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(policy, {from: deployer});
    await reBase.setRewardAddress(rewardAddress, {from: deployer});
    await reBase.transfer(A, toUFrgDenomination(750), { from: deployer });
    await reBase.transfer(B, toUFrgDenomination(250), { from: deployer });
    r = await reBase.rebase(1, 0, {from: policy});
  });

  it('should NOT CHANGE the totalSupply', async function () {
    b = await reBase.totalSupply.call();
    b.should.be.bignumber.eq(initialSupply);
  });

  it('should NOT CHANGE individual balances', async function () {
    b = await reBase.balanceOf.call(A);
    const fee = parseInt( await reBase._txFee.call());
    b.should.be.bignumber.eq(toUFrgDenomination(750-750/fee));

    b = await reBase.balanceOf.call(B);
    b.should.be.bignumber.eq(toUFrgDenomination(250-250/fee));
  });

  it('should emit Rebase', async function () {
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogRebase');
    log.args.epoch.should.be.bignumber.eq(1);
    log.args.totalSupply.should.be.bignumber.eq(initialSupply);
  });
});

contract('Rebase:Rebase:Contraction', function (accounts) {
  // Rebase -302500 (-10%), with starting balances A:10 and B:20.
  const A = accounts[2];
  const B = accounts[3];
  const policy = accounts[1];
  const rewardAddress = accounts[5];
  const rebaseAmt = INTIAL_SUPPLY / 10;

  before('setup Rebase contract', async function () {
    await setupContracts();
    await reBase.setMonetaryPolicy(policy, {from: deployer});
    await reBase.setRewardAddress(rewardAddress, {from: deployer});
    await reBase.transfer(A, toUFrgDenomination(10), { from: deployer });
    await reBase.transfer(B, toUFrgDenomination(20), { from: deployer });
    r = await reBase.rebase(1, -rebaseAmt, {from: policy});
  });

  it('should decrease the totalSupply', async function () {
    b = await reBase.totalSupply.call();
    b.should.be.bignumber.eq(initialSupply.minus(rebaseAmt));
  });

  it('should decrease individual balances', async function () {
    const fee = parseInt( await reBase._txFee.call());
    b = await reBase.balanceOf.call(A);
    b.should.be.bignumber.eq(toUFrgDenomination(9-9/fee));

    b = await reBase.balanceOf.call(B);
    b.should.be.bignumber.eq(toUFrgDenomination(18-18/fee));
  });

  it('should emit Rebase', async function () {
    const log = r.logs[0];
    expect(log).to.exist;
    expect(log.event).to.eq('LogRebase');
    log.args.epoch.should.be.bignumber.eq(1);
    log.args.totalSupply.should.be.bignumber.eq(initialSupply.minus(rebaseAmt));
  });
});

contract('Rebase:Transfer', async function (accounts) {
  const A = accounts[2];
  const B = accounts[3];
  const C = accounts[4];
  const rewardAddress = accounts[5];

  before('setup Rebase contract', setupContracts);


  describe('deployer transfers 12 to A', function () {
    it('should have correct balances', async function () {
      const fee = parseInt( await reBase._txFee.call());
      await reBase.setRewardAddress(rewardAddress, {from: deployer});
      const deployerBefore = await reBase.balanceOf.call(deployer);
      await reBase.transfer(A, toUFrgDenomination(12), { from: deployer });
      b = await reBase.balanceOf.call(deployer);
      b.should.be.bignumber.eq(deployerBefore.minus(toUFrgDenomination(12)));
      b = await reBase.balanceOf.call(A);
      b.should.be.bignumber.eq(toUFrgDenomination(12-12/fee));
    });
  });

  describe('deployer transfers 15 to B', async function () {
    it('should have balances [973,15]', async function () {
      const fee = parseInt( await reBase._txFee.call());
      await reBase.setRewardAddress(rewardAddress, {from: deployer});
      const deployerBefore = await reBase.balanceOf.call(deployer);
      await reBase.transfer(B, toUFrgDenomination(15), { from: deployer });
      b = await reBase.balanceOf.call(deployer);
      b.should.be.bignumber.eq(deployerBefore.minus(toUFrgDenomination(15)));
      b = await reBase.balanceOf.call(B);
      b.should.be.bignumber.eq(toUFrgDenomination(15-15/fee));
    });
  });

  describe('deployer transfers the rest to C', async function () {
    it('should have balances [0,973]', async function () {
      await reBase.setRewardAddress(rewardAddress, {from: deployer});
      const fee = parseInt( await reBase._txFee.call());
      const deployerBefore = await reBase.balanceOf.call(deployer);
      await reBase.transfer(C, deployerBefore, { from: deployer });
      b = await reBase.balanceOf.call(deployer);
      b.should.be.bignumber.eq(0);
      b = await reBase.balanceOf.call(C);
      b.should.be.bignumber.eq(deployerBefore- deployerBefore/fee);
    });
  });

  describe('when the recipient address is the contract address',async  function () {
    const owner = A;

    it('reverts on transfer', async function () {
      expect(
        await chain.isEthException(reBase.transfer(reBase.address, unitTokenAmount, { from: owner }))
      ).to.be.true;
    });

    it('reverts on transferFrom', async function () {
      expect(
        await chain.isEthException(reBase.transferFrom(owner, reBase.address, unitTokenAmount, { from: owner }))
      ).to.be.true;
    });
  });

  describe('when the recipient is the zero address', function () {
    const owner = A;

    before(async function () {
      r = await reBase.approve(ZERO_ADDRESS, transferAmount, { from: owner });
    });
    it('emits an approval event', async function () {
      expect(r.logs.length).to.eq(1);
      expect(r.logs[0].event).to.eq('Approval');
      expect(r.logs[0].args.owner).to.eq(owner);
      expect(r.logs[0].args.spender).to.eq(ZERO_ADDRESS);
      r.logs[0].args.value.should.be.bignumber.eq(transferAmount);
    });

    it('transferFrom should fail', async function () {
      expect(
        await chain.isEthException(reBase.transferFrom(owner, ZERO_ADDRESS, transferAmount, { from: C }))
      ).to.be.true;
    });
  });
});
