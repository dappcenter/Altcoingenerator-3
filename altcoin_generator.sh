#!/bin/bash -e
# This script is an experiment to clone litecoin into a 
# brand new coin + blockchain.
# The script will perform the following steps:
# 1) create first a docker image with ubuntu ready to build and run the new coin daemon
# 2) clone GenesisH0 and mine the genesis blocks of main, test and regtest networks in the container (this may take a lot of time)
# 3) clone litecoin
# 4) replace variables (keys, merkle tree hashes, timestamps..)
# 5) build new coin
# 6) run 4 docker nodes and connect to each other
# 
# By default the script uses the regtest network, which can mine blocks
# instantly. If you wish to switch to the main network, simply change the 
# CHAIN variable below

# change the following variables to match your new coin
COIN_NAME="SovolCoin"
COIN_UNIT="SVC"
COIN_UNIT_DENOMINATION_1="TYVM"
COIN_UNIT_DENOMINATION_2="YW"

# 21 million coins at total (litecoin total supply is 84000000)
TOTAL_SUPPLY=21000000
MAINNET_PORT="56743"
TESTNET_PORT="56744"
PHRASE="Social Volonteer service is important"

# First letter of the wallet address. Check https://en.bitcoin.it/wiki/Base58Check_encoding
PUBKEY_CHAR="25"

# number of blocks to wait to be able to spend coinbase UTXO's
COINBASE_MATURITY=100

# leave CHAIN empty for main network, -regtest for regression network and -testnet for test network
CHAIN=""

# this is the amount of coins to get as a reward of mining the block of height 1. if not set this will default to 50
#PREMINED_AMOUNT=10000

# warning: change this to your own pubkey to get the genesis block mining reward
GENESIS_REWARD_PUBKEY=04AD1CBC6EE226091EB8ECF84BF0ADD4F77A9D2D91511386D5703DC2AF756E8E110119A91DC86A342C33B6780E880C8B3FD87AA3917C4D403E76E2C026B541DD2D

#dont change the following variables unless you know what you are doing
LITECOIN_BRANCH=master
GENESISHZERO_REPOS=https://github.com/lhartikk/GenesisH0
LITECOIN_REPOS=https://github.com/litecoin-project/litecoin.git
LITECOIN_PUB_KEY=040184710fa689ad5023690c80f3a49c8f13f8d45b8c857fbcbc8bc4a8e4d3eb4b10f4d4604fa08dce601aaf0f470216fe1b51850b4acf21b179c45070ac7b03a9
LITECOIN_MERKLE_HASH=97ddfbbae6be97fd6cdf3e7ca13232a3afff2353e29badfab7f73011edd4ced9
LITECOIN_MAIN_GENESIS_HASH=12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2
LITECOIN_TEST_GENESIS_HASH=4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0
LITECOIN_REGTEST_GENESIS_HASH=530827f38f93b43ed12af0b3ad25a288dc02ed74d6d7857862df51fc56c416f9
MINIMUM_CHAIN_WORK_MAIN=0x00000000000000000000000000000000000000000000002ebcfe2dd9eff82666
MINIMUM_CHAIN_WORK_TEST=0x0000000000000000000000000000000000000000000000000007d006a402163e
COIN_NAME_LOWER=$(echo $COIN_NAME | tr '[:upper:]' '[:lower:]')
COIN_NAME_UPPER=$(echo $COIN_NAME | tr '[:lower:]' '[:upper:]')
DIRNAME=$(dirname $0)
DOCKER_IMAGE_LABEL="sovolcoin-env"
OSVERSION="$(uname -s)"

#config file
CONFIG_FILE_NAME=sovolcoin.conf
ADD_NODE_ADDRESS=203.141.143.8
ADD_NODE_PORT=56743
PAY_TX_FEE=0.001

#you must change this if you is gonna RPC_API 
ENABLE_SERVER=0
#RPC_USER=sovol
#PRC_PASSPHRASE=socialvolunteer
#RPC_PORT=sovolcoinport


docker_build_image()
{
    IMAGE=$(docker images -q $DOCKER_IMAGE_LABEL)
    if [ -z $IMAGE ]; then
        echo Building docker image
        if [ ! -f $DOCKER_IMAGE_LABEL/Dockerfile ]; then
            mkdir -p $DOCKER_IMAGE_LABEL
            cat <<EOF > $DOCKER_IMAGE_LABEL/Dockerfile
FROM ubuntu:16.04
RUN echo deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D46F45428842CE5E
RUN apt-get update
RUN apt-get -y install ccache git libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 libssl1.0.0 libevent-pthreads-2.0-5 libevent-2.0-5 build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev python-pip
RUN pip install construct==2.5.2 scrypt
EOF
        fi 
        docker build --label $DOCKER_IMAGE_LABEL --tag $DOCKER_IMAGE_LABEL $DIRNAME/$DOCKER_IMAGE_LABEL/
    else
        echo Docker image already built
    fi
}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_run()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 -v $DIRNAME/.ccache:/root/.ccache -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$1"

}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_generate_genesis_block()
{
    if [ ! -d GenesisH0 ]; then
        git clone $GENESISHZERO_REPOS
        pushd GenesisH0
    else
        pushd GenesisH0
        git pull
    fi

    if [ ! -f ${COIN_NAME}-main.txt ]; then
        echo "Mining genesis block... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-main.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-main.txt
    fi

    if [ ! -f ${COIN_NAME}-test.txt ]; then
        echo "Mining genesis block of test network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py  -t 1486949366 -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-test.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-test.txt
    fi

    if [ ! -f ${COIN_NAME}-regtest.txt ]; then
        echo "Mining genesis block of regtest network... this procedure can take many hours of cpu work.."
        docker_run_genesis "python /GenesisH0/genesis.py -t 1296688602 -b 0x207fffff -n 0 -a scrypt -z \"$PHRASE\" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee /GenesisH0/${COIN_NAME}-regtest.txt"
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-regtest.txt
    fi

    MAIN_PUB_KEY=$(cat ${COIN_NAME}-main.txt | grep "^pubkey:" | $SED 's/^pubkey: //')
    MERKLE_HASH=$(cat ${COIN_NAME}-main.txt | grep "^merkle hash:" | $SED 's/^merkle hash: //')
    TIMESTAMP=$(cat ${COIN_NAME}-main.txt | grep "^time:" | $SED 's/^time: //')
    BITS=$(cat ${COIN_NAME}-main.txt | grep "^bits:" | $SED 's/^bits: //')

    MAIN_NONCE=$(cat ${COIN_NAME}-main.txt | grep "^nonce:" | $SED 's/^nonce: //')
    TEST_NONCE=$(cat ${COIN_NAME}-test.txt | grep "^nonce:" | $SED 's/^nonce: //')
    REGTEST_NONCE=$(cat ${COIN_NAME}-regtest.txt | grep "^nonce:" | $SED 's/^nonce: //')

    MAIN_GENESIS_HASH=$(cat ${COIN_NAME}-main.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    TEST_GENESIS_HASH=$(cat ${COIN_NAME}-test.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    REGTEST_GENESIS_HASH=$(cat ${COIN_NAME}-regtest.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')

    popd
}

newcoin_replace_vars()
{
    if [ -d $COIN_NAME_LOWER ]; then
        echo "Warning: $COIN_NAME_LOWER already existing. Not replacing any values"
        return 0
    fi
    if [ ! -d "litecoin-master" ]; then
        # clone litecoin and keep local cache
        git clone -b $LITECOIN_BRANCH $LITECOIN_REPOS litecoin-master
    else
        echo "Updating master branch"
        pushd litecoin-master
        git pull
        popd
    fi

    git clone -b $LITECOIN_BRANCH litecoin-master $COIN_NAME_LOWER

    pushd $COIN_NAME_LOWER

    # first rename all directories
    for i in $(find . -type d | grep -v "^./.git" | grep litecoin); do
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # then rename all files
    for i in $(find . -type f | grep -v "^./.git" | grep litecoin); do
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # now replace all litecoin references to the new coin name
    for i in $(find . -type f | grep -v "^./.git"); do
        $SED -i "s/Litecoin/$COIN_NAME/g" $i
        $SED -i "s/litecoin/$COIN_NAME_LOWER/g" $i
        $SED -i "s/LITECOIN/$COIN_NAME_UPPER/g" $i
        $SED -i "s/LTC/$COIN_UNIT/g" $i
        $SED -i "s/lites/$COIN_UNIT_DENOMINATION1/g" $i
        $SED -i "s/photons/$COIN_UNIT_DENOMINATION2/g" $i
    done

    $SED -i "s/84000000/$TOTAL_SUPPLY/" src/amount.h

    # overwrite base58Prefixes
    $SED -i "s/1,48/1,$PUBKEY_CHAR/" src/chainparams.cpp
    $SED -i "s/1,176/1,25/" src/chainparams.cpp
    $SED -i "/base58Prefixes\[EXT_PUBLIC_KEY\] =/s/0x04/0xff/" src/chainparams.cpp
    $SED -i "/base58Prefixes\[EXT_SECRET_KEY\] =/s/0x04/0xff/" src/chainparams.cpp

    $SED -i "s/1317972665/$TIMESTAMP/" src/chainparams.cpp

    $SED -i "s;NY Times 05/Oct/2011 Steve Jobs, Apple’s Visionary, Dies at 56;$PHRASE;" src/chainparams.cpp

    $SED -i "s/= 9333;/= $MAINNET_PORT;/" src/chainparams.cpp
    $SED -i "s/= 19335;/= $TESTNET_PORT;/" src/chainparams.cpp

    $SED -i "s/$LITECOIN_PUB_KEY/$MAIN_PUB_KEY/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/qt/test/rpcnestedtests.cpp

    $SED -i "0,/$LITECOIN_MAIN_GENESIS_HASH/s//$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_TEST_GENESIS_HASH/s//$TEST_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_REGTEST_GENESIS_HASH/s//$REGTEST_GENESIS_HASH/" src/chainparams.cpp

    $SED -i "0,/2084524493/s//$MAIN_NONCE/" src/chainparams.cpp
    $SED -i "0,/293345/s//$TEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/1296688602, 0/s//1296688602, $REGTEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/0x1e0ffff0/s//$BITS/" src/chainparams.cpp
    
    # comment out dnsseeds
    $SED -i "s,vSeeds.emplace_back,//vSeeds.emplace_back,g" src/chainparams.cpp

    # remove seednodes and add some example seeds 
    $SED -i -n -e "/static SeedSpec6 pnSeed6_main\[\] = {/{" -e "p" -e ":a" -e "N" -e "/};/!ba" -e "s/.*\n//" -e "}" -e "p" src/chainparamsseeds.h
    $SED -i -n -e "/static SeedSpec6 pnSeed6_test\[\] = {/{" -e "p" -e ":a" -e "N" -e "/};/!ba" -e "s/.*\n//" -e "}" -e "p" src/chainparamsseeds.h
    # when creating your own altcoin, you must change this addresses
    $SED -i -e "/static SeedSpec6 pnSeed6_main\[\] = {/a\        {{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xcb,0x8d,0x8f,0x08}, 56743}" src/chainparamsseeds.h 
    $SED -i -e "/static SeedSpec6 pnSeed6_test\[\] = {/a\        {{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xcb,0x8d,0x8f,0x08}, 56743}" src/chainparamsseeds.h

    if [ -n "$PREMINED_AMOUNT" ]; then
        $SED -i "s/CAmount nSubsidy = 50 \* COIN;/if \(nHeight == 1\) return COIN \* $PREMINED_AMOUNT;\n    CAmount nSubsidy = 50 \* COIN;/" src/validation.cpp
    fi

    $SED -i "s/COINBASE_MATURITY = 100/COINBASE_MATURITY = $COINBASE_MATURITY/" src/consensus/consensus.h

    # reset minimum chain work to 0
    $SED -i "s/$MINIMUM_CHAIN_WORK_MAIN/0x00/" src/chainparams.cpp
    $SED -i "s/$MINIMUM_CHAIN_WORK_TEST/0x00/" src/chainparams.cpp

    # change bip activation heights
    # bip 34
    $SED -i "s/710000/0/" src/chainparams.cpp
    # bip 65
    $SED -i "s/918684/0/" src/chainparams.cpp
    # bip 66
    $SED -i "s/811879/0/" src/chainparams.cpp
    
    # reset checkpoint
    $SED -i -n -e "/checkpointData = {/{" -e "p" -e ":a" -e "N" -e "/};/!ba" -e "s/.*\n//" -e "}" -e "p" src/chainparams.cpp
    $SED -i '/checkpointData = {/a\            {{0, uint256S("x0")}}' src/chainparams.cpp
    $SED -i -n -e "/chainTxData = ChainTxData/{" -e "p" -e ":a" -e "N" -e "/};/!ba" -e "s/.*\n//" -e "}" -e "p"  src/chainparams.cpp
    $SED -i '/chainTxData = ChainTxData/a\            0,0,0' src/chainparams.cpp

    # overwrite pchMessageStart
    $SED -i -e '/pchMessageStart\[0\] =/s/0xfd/0x53/g' src/chainparams.cpp
    $SED -i -e '/pchMessageStart\[1\] =/s/0xd2/0x56/g' src/chainparams.cpp
    $SED -i -e '/pchMessageStart\[2\] =/s/0xc8/0x4C/g' src/chainparams.cpp
    $SED -i -e '/pchMessageStart\[3\] =/s/0xf1/0x43/g' src/chainparams.cpp

    popd
}

generate_config_file()
{
    if [[ ( -d $COIN_NAME_LOWER ) && ( ! -f $COIN_NAME_LOWER/$CONFIG_FILE_NAME ) ]]; then
        touch $COIN_NAME_LOWER/$CONFIG_FILE_NAME
        echo "generating $CONFIG_FILE_NAME ..."
        echo "addnode=$ADD_NODE_ADDRESS:$ADD_NODE_PORT\n\n" \
             "paytxfee=$PAY_TX_FEE\n\n" >> $COIN_NAME_LOWER/$CONFIG_FILE_NAME
        if [ $ENABLE_SERVER=1]; then
            echo "server=$ENABLE_SERVER\nrpcuser=$RPC_USER\nrpcpassword=$PRC_PASSPHRASE\nrpcport=$RPC_PORT" \
            >> $COIN_NAME_LOWER/$CONFIG_FILE_NAME
        fi
    fi
}

remove_no_used_files()
{
    if [ -d "litecoin-master" ]; then
        rm -rf "litecoin-master"
    fi
}


reset_environment()
{
    if [ -d "GenesisH0" ]; then
        rm -rf "GenesisH0/"
    fi

    if [ -d "litecoin-master" ]; then
        rm -rf "litecoin-master/"
    fi

    if [ -d $COIN_NAME_LOWER ]; then
        rm -rf $COIN_NAME_LOWER/
    fi
}

if [ $DIRNAME =  "." ]; then
    DIRNAME=$PWD
fi

cd $DIRNAME

# sanity check

case $OSVERSION in
    Linux*)
        SED=sed
    ;;
    Darwin*)
        SED=$(which gsed 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "please install gnu-sed with 'brew install gnu-sed'"
            exit 1
        fi
        SED=gsed
    ;;
    *)
        echo "This script only works on Linux and MacOS"
        exit 1
    ;;
esac

if ! which docker &>/dev/null; then
    echo Please install docker first
    exit 1
fi

if ! which git &>/dev/null; then
    echo Please install git first
    exit 1
fi

case $1 in
    start)
	docker_build_image
	docker_generate_genesis_block
	newcoin_replace_vars
    generate_config_file
    remove_no_used_files

    exit 0
    ;;
    reset)
    reset_environment

    exit 0

    ;;
    *)
        cat <<EOF
Usage: $0 (start|reset)
 - start: bootstrap environment, build and run your new coin
 - reset: remove all images and related files
EOF
    ;;
esac

