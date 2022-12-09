# Trusted Collaborative Processes

## Content
- [Processes](#processes)
- [Deploy Smart Contracts](#deploy-smart-contracts)
- [Tests](#tests)

## Processes
In this folder you will find the BPMN diagrams and the abstract DMN of the collaborative processes described in the article, as well as the general process that contains all of them. The "Reporting CLA results" process does not have its own BPMN as it would depend on each company, according to the procedures they have to report the results to the corresponding entities. Specifically, the folder contains the following files:
- **GeneralProcess.bpmn:** Diagram of the overall process containing the four collaborative sub-processes.
- **GenerateCLA.bpmn:** Diagram describing the process of generating the collaboration's CLA.
- **MonitoringCLA.bpmn:** Diagram describing the process of providing and consuming the data as signed in the CLA.
- **MonitoringCLA-IoT.bpmn:** Diagram describing the process of providing and consuming the data as signed in the CLA, in the event that the data provider obtains its data from an IoT system.
- **DecisionMaking.dmn:** Abstract DMN table with an example of decision making agreed in the CLA.

## Deploy Smart Contracts
The "Smart Contracts" folder contains the Smart Contracts that have been developed as described in the article. In addition to the abstract Smart Contracts, the folder contains customised Smart Contracts for the bicycle rental organisation (data provider), for the health entity that manages sick leave periods (data provider) and for the company that checks health frauds (data consumer). In total, the Smart Contracts contained in the folder are the following:

- **AbstractCLA.sol:** Abstract CLA to be instantiated in any collaboration.
- **AbstractConsumer.sol:** Abstract Smart Contract for an organisation to consume data in a collaboration.
- **AbstractProviderWithBlock.sol:** Abstract Smart Contract for an organization that is going to provide its data in a collaboration and previously had its business data stored in Blockchain, so it has a separate Smart Contract to get this business data.
- **AbstractProviderWithoutBlock.sol:** Abstract Smart Contract for an organisation that is going to provide its data in a collaboration and has its business data stored in any traditional system, so this Smart Contract must also serve to obtain and store this business data in the Blockchain.
- **BicycleRenting.sol:** Customised Smart Contract for the bicycle rental organisation to obtain its business data from its IoT system, store it on the Blockchain and make it available to be obtained by the consumers of the collaboration (in this case, the fraud checking company).
- **HealthFrauds.sol:** Smart Contract customised for the health fraud checking company to obtain the data from the collaboration providers and apply the logic agreed in the DMN, as well as store the frauds found on the Blockchain.
- **SickLeavePeriods.sol:** Smart Contract customised for the health entity managing the sick leave periods to obtain its business data from its information system, store it in the Blockchain and make it available to be obtained by the consumers of the collaboration (in this case, the fraud checking company).

Any of these Smart Contracts can be deployed using different methods and tools to verify that they work correctly. In this case, we are going to explain how it has been deployed for the article, so that it could be used in a REST API created with Node.js. The steps are as follows:

1. Create a wallet and connect it to an Ethereum network (in this case Metamask and the test network called Goerli were used). Save the wallet secret phrase as it will be needed later.
2. Obtain the endpoint of a node that is in the selected Ethereum network, as it is through this node that transactions will be sent. At this point there are multiple options: you can use a single node or switch between a set, you can deploy your own node or use a public one, or you can make use of certain providers where they register you and enable a custom endpoint for you.
3. Create a Node.js project (you will need the "nodejs" and "npm" libraries, of course, in their most recent versions).
4. Install the "Truffle HDWalletProvider" library: ```npm install truffle-hdwallet-provider```.
5. Create a "truffle-config.js" file in the root of the Node.js project, which should contain the following, replacing ```<WALLET_MNEMONIC>``` with the secret phrase of your wallet (it is recommended to have it in a separate file) and ```<ETHEREUM_ENDPOINT_URL>``` with the URL of the Ethereum node you have chosen:

```
const path = require("path");
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
   contracts_build_directory: path.join(__dirname, "/build"),

  networks: {
    development: {
      host: "127.0.0.1", // LOCALHOST
      port: 7545, // YOU CAN CHANGE THE PORT
      network_id: "*"
     },
     goerli: {
        provider: function() {
          return new HDWalletProvider(<WALLET_MNEMONIC>, <ETHEREUM_ENDPOINT_URL>);
        },
        network_id: 5,
        nonce: 251,
     }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.13",
      settings: {
        optimizer: {
          enabled: true,
          runs: 20000
       },
       evmVersion: "byzantium"
      }
    }
  },
};
```

6. Get ETH tokens in your wallet, making use of any secure faucet you can find on the web (e.g. https://goerlifaucet.com).
7. Create a "contracts" folder containing a first Smart Contract called "Migrations.sol" with the following content:

```
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Migrations {
  address public owner = msg.sender;
  uint public last_completed_migration;

  modifier restricted() {
    require(
      msg.sender == owner,
      "This function is restricted to the contract's owner"
    );
    _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }
}
```

8. Add to this "contracts" folder the rest of the Smart Contracts to be deployed.

9. Create a "migrations" folder containing a file called "1_initial_migration.js" with the following content:

```
const Migrations = artifacts.require("Migrations");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};
```

10. Add to this "migrations" folder a new file for each of the Smart Contracts to be deployed. For example, the file "2_migrate_health_frauds.js" should contain the following:

```
var HealthFrauds = artifacts.require("./HealthFrauds.sol");

module.exports = function(deployer) {
    deployer.deploy(HealthFrauds);
};
```

11. Use the command ````truffle migrate --network goerli``` to deploy Smart Contracts on the Ethereum Goerli network. In this step, the different attributes received by the constructor of the Smart Contract being deployed must be inputted. The attributes will be the following, depending on the Smart Contract to be deployed:
- **AbstractCLA.sol:** partners, providersBusinessProcess, consumersBusinessProcess, ontology, sharedData, sharedDataTypes, sharedPrivacyData, sharedPrivacyDataTypes, privacyAlgorithm, privacySalt, collaborationStartTime, collaborationEndTime, monetisation, gasLimit.
- **AbstractConsumer.sol:** providersBusinessProcess, consumersBusinessProcess, dataIndexes, dataModes, privacyDataIndexes, privacyDataModes, claAddress.
- **AbstractProviderWithBlock.sol:** businessContractAddress, collaborationName, providersBusinessProcess, consumersBusinessProcess, sharedData, sharedPrivacyData, privacyAlgorithm, privacySalt, collaborationStartTime, collaborationEndTime, monetisation, gasLimit, claAddress.
- **AbstractProviderWithoutBlock.sol:** collaborationName, providersBusinessProcess, consumersBusinessProcess, sharedData, sharedPrivacyData, privacyAlgorithm, privacySalt, collaborationStartTime, collaborationEndTime, monetisation, gasLimit, claAddress.

12. If you want to have a REST API with Node.js to interact with any of the deployed Smart Contracts, you must create a file to start the Node.js server, called for example "server.js", with the following content:

```
require("dotenv").config({path: __dirname + "/.env"});
const express = require("express");
const app = express();
const cors = require("cors");
const routes = require("./routes");
const Web3 = require("web3");
const contract = require("@truffle/contract");
const artifacts = require("./build/HealthFrauds.json"); // HERE IS WHERE YOU INDICATE THE SMART CONTRACT TO INTERACT WITH
const HDWalletProvider = require("@truffle/hdwallet-provider");
const User = require("./database/user");

app.use(cors());
app.use(express.json());

async function start() {
    if (typeof web3 !== "undefined") {
        var web3 = new Web3(web3.currentProvider);

    } else {
        provider = new HDWalletProvider({
            mnemonic: <WALLET_MNEMONIC>,
            providerOrUrl: <ETHEREUM_ENDPOINT_URL>,
            addressIndex: 0,
            numberOfAddresses: 1
        });

        var web3 = new Web3(provider);
    }

    const LMS = contract(artifacts);
    LMS.setProvider(web3.currentProvider);

    const accounts = await web3.eth.getAccounts();

    const lms = await LMS.at(process.env.CONTRACT_ADDRESS.toString());

    routes(app, lms, accounts[0]);

    app.listen(process.env.PORT || 3003, () => {
        console.log("listening on port " + (process.env.PORT || 3003));
    });
}

start();
```

13. Create a "routes.js" file (which is imported into the above code) containing the various REST API calls to the deployed Smart Contract, for example:

```
app.get("/all_frauds", (req, res) => {
    lms.getAllFrauds().then(frauds => { // getAllFrauds() WOULD BE A FUNCTION IMPLEMENTED IN THE SMART CONTRACT TO GET ALL FRAUDS
        return res.send(frauds);
    })
    .catch(err => {
        console.log(err);
        return res.status(500).send(err);
    });
});
```

## Tests
The tests folder includes all the files related to the various tests that have been carried out on the IoT system and the Blockchain, as explained in the article. In the following, the different tests found in this folder will be discussed.

### Blockchain Gas and Time Tests
The file "Blockchain tests.xlsx" contains all the tests performed on the gas consumed and the time taken to check and update the health frauds, as shown in the article. This file contains 3 different sheets: in the first one, called "Tests", the results of the tests are shown in tables and line graphs, divided into the three sets of tests mentioned in the article. These tables have the following format:

- Day of the test (as it influences the gas to be consumed).
- Number of the subset of tests (as each set is composed of several subsets, between 3 and 5, and these in turn are composed of 4 tests).
- Number of bicycle rentals tested in the subset.
- Number of sick leave periods in the subset.
- Total number of transactions (rentals plus periods) in the subset.
- Time in seconds of each test.
- Average time in seconds of each subset of tests.
- Gas consumed in wei of each test.
- Average gas consumed in wei of each subset of tests.
- Ratio of gas consumed to total number of transactions for each subset of tests.

The second sheet, called "Creations time", as its name suggests, shows the time taken to create the transactions (both rentals and sick leave periods) necessary to carry out the tests. The results are shown first in total seconds, then in total minutes and finally in the ratio between the total seconds and the number of transactions created, in order to check that this value is practically stable (around 20-25 seconds).

Finally, the last sheet, called "Distribution", shows the distribution graph of the time in seconds required for each of the tests, gathered for each set of tests performed, as well as the total distribution considering all the times of all the tests.
