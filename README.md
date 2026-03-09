# Solidity Dividend Token

This project implements a mintable ERC20 token with a dividend distribution mechanism.

The dividend system uses a **dividend-per-token approach** to avoid looping through all token holders and reduce gas costs.

## Features
- Mint tokens by depositing ETH
- Burn tokens to redeem ETH
- Record and withdraw dividends
- Efficient dividend distribution using dividend-per-token

## Tech
Solidity 0.7.0  
Hardhat
