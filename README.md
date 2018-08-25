# Altcoin Generator
Easiest way to create your own cryptocurrency.

This product is based on [tiagosh/AltcoinGenerator](https://github.com/tiagosh/AltcoinGenerator), made some updates to accept litecoin version 0.16.


## What does this script do?

This script is an experiment to generate new cryptocurrencies (altcoins) based on litecoin.
It will help you creating a git repository with minimal required changes to start your new coin and blockchain.

## What do I have to do?

You need to make sure you have at least docker and git installed in any Linux distribution or MacOS.
If you are using MacOS, then you also need to install gnu-sed using 'brew install gnu-sed'

The other requirements will be installed automatically in a docker container by the script.

Simply open the script and edit the first variables to match your coin requirements (total supply, coin unit, coin name, tcp ports..)
Then simply run the script like this:

```
bash altcoin_generator.sh start
```

To see all possible options run the script like this:

```
bash altcoin_generator.sh
```

## What will happen then?

The script will perform a couple of actions:

  * Create a docker image ready to build and run your new coin nodes
  * Clone GenesisH0 and mine the genesis blocks of main, test and regtest networks in the container (this might take a lot of time)
  * Clone litecoin
  * Rename files and replace variables in litecoin code (genesis hashes, merkle tree hashes, tcp ports, coin name, supply...)
  * The GENESIS_REWARD_PUBKEY will be used in the UTXO of the genesis block. If you don't change it to your own before mining the genesis block you are agreeing to pay me the genesis block reward in case your coin succeeds (Thanks! :p)
  
## How to build new coin?

See document for building litecoin.[https://github.com/litecoin-project/litecoin.git]

## What can I do next?

You can first check if your nodes are running and then ask them to generate some blocks.

Instructions on how to do it will be printed once the script execution is done.

## Is there anything I must be aware of?

Yes.

  * This is a very simple script to help you bootstrap. More changes will be needed to launch a cryptocurrency for real.
  * You have to manually change the pictures in mycoin/share/pixmaps.
  * Consider adding a seed node and add it to src/chainparams.cpp as well.
    * Currently all seeds are getting disabled.
  
  
## I think something went wrong!

Then you can clean up the mess with:

```
bash altcoin_generator.sh reset
```
All files will be removed, and You can simply start again!


