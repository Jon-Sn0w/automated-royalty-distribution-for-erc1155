# Automated Royalty Distribution for ERC-1155

This contract can be applied as a royalty collection wallet on NFT marketplaces, enabling automated distribution of royalties to registered wallet addresses. This is an early version of the system, which has seen initial success in distributing royalties to multiple registered wallet addresses for ERC-1155 collections with a low number of token IDs.

Upon deployment, you will set the collection contract address to be scanned during distribution. After public verification on-chain, users can manually register wallet addresses to be included in royalty collections. Feel free to create a custom user interface for interaction with the system.

This is an experimental version. Future upgrades will include a more comprehensive system, allowing pre-registration of wallet addresses via a snapshot of contract address holders from any NFT project that wishes to deploy the system.

Please note that this version has not been tested with a large number of wallet addresses. We encourage you to experiment and provide feedback.

This repository is entirely open source, and anyone is welcome to use and build upon it.
