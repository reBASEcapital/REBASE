# reB∆SE

 <a href="https://discord.gg/jBg5ZAz">
        <img src="https://img.shields.io/discord/734242135523459103?logo=discord"
            alt="chat on Discord"></a>

[![Build Status](https://travis-ci.com/ampleforth/uFragments.svg?token=xxNsLhLrTiyG3pc78i5v&branch=master)](https://travis-ci.com/ampleforth/uFragments)&nbsp;&nbsp;[![Coverage Status](https://coveralls.io/repos/github/frgprotocol/uFragments/badge.svg?branch=master&t=GiWi8p)](https://coveralls.io/github/frgprotocol/uFragments?branch=master)

reB∆SE, pronounced "rebase" is a decentralized elastic supply protocol. It is forked from Ampleforth which operates under the codename "UFragments". This monetary protocol maintains a stable unit price by adjusting supply directly to and from wallet holders.

This repository is a collection of smart contracts that implement the reB∆SE protocol on the Ethereum blockchain.

The official contract addresses are:
- ERC-20 Token:  TBD
- Supply Policy: TBD
- Market Oracle: TBD
- CPI Oracle:    TBD

## Table of Contents
- [Install](#install)
- [Testing](#testing)
- [Contribute](#contribute)
- [License](#license)

## Install

```bash
# Install project dependencies
npm install

# Install ethereum local blockchain(s) and associated dependencies
npx setup-local-chains
```

## Testing

``` bash
# You can use the following command to start a local blockchain instance
npx start-chain [ganacheUnitTest|gethUnitTest]

# Run all unit tests
npm test

# Run unit tests in isolation
npx truffle --network ganacheUnitTest test test/unit/uFragments.js
```

## Contribute

To report bugs within this package, please create an issue in this repository.
When submitting code ensure that it is free of lint errors and has 100% test coverage.

``` bash
# Lint code
npm run lint

# View code coverage
npm run coverage
```

## License

[GNU General Public License v3.0](./LICENSE)
