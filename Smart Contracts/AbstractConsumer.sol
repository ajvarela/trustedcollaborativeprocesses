// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract AbstractConsumer {
    uint count = 0;
    address owner;

    struct Collaboration {
        address[] providersBusinessProcess;
        address[] consumersBusinessProcess;
        uint[][] dataIndexes; // the value at each row is a condition of the DMN and the value at each column is the data's index of the provider in the same position in "providersBusinessProcess"
        uint[] dataModes; // the value at each position matches with the condition in "dataIndexes"
                          // mode "0" is equal, mode "1" is greater than, mode "2" is greater or equal than, mode "3" is less than and mode "4" is less or equal than
        address claAddress;
    }

    struct DecisionData {
        string attribute1;
        address attribute2;
        uint attribute3;
        uint256 blockTime;
    }

    Collaboration collaboration;
    DecisionData[] allDecisionData;

    constructor(
        address[] memory _providersBusinessProcess,
        address[] memory _consumersBusinessProcess,
        uint[][] memory _dataIndexes,
        uint[] memory _dataModes,
        address _claAddress
    ) {
        bool validAddress = checkSenderIfPartner(_consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a consumer can create a consumer's Smart Contract"); }

        string memory errorMessage = validateAttributes(_dataIndexes, _dataModes);

        if (keccak256(bytes(errorMessage)) != keccak256(bytes(""))) { revert(errorMessage); }

        owner = tx.origin;

        collaboration = Collaboration(_providersBusinessProcess, _consumersBusinessProcess, _dataIndexes, _dataModes, _claAddress);
    }

    function getProviderData(uint _providerIndex) internal returns(bytes[][] memory response) {
        if (tx.origin != owner) {revert("Only the owner can add a collaboration"); }

        address providerAddress = collaboration.providersBusinessProcess[_providerIndex];

        Provider providerContract = Provider(providerAddress);

        response = providerContract.getCollaborationData();

        return response;
    }

    function makeDecisions() public returns(DecisionData[] memory) {
        if (tx.origin != owner) { revert("Only the owner can call to make decisions"); }

        bytes[][] memory providerData1 = getProviderData(0);
        bytes[][] memory providerData2 = getProviderData(1);

        for (uint i = 0; i < providerData1.length; i++) {
            bytes[] memory element1 = providerData1[i];

            for (uint j = 0; j < providerData2.length; j++) {
                bytes[] memory element2 = providerData2[j];

                bool decision = checkDecision(element1, element2);

                if (decision == true) {
                    createDecisionObject(element1, element2);
                }
            }
        }

        return allDecisionData;
    }

    function checkDecision(bytes[] memory element1, bytes[] memory element2) internal view returns(bool decision) {
        decision = true;
        bool condition;

        for (uint i = 0; i < collaboration.dataIndexes.length; i++) {
            uint[] memory indexes = collaboration.dataIndexes[i];
            bytes32 attribute1 = keccak256(element1[indexes[0]]);
            bytes32 attribute2 = keccak256(element2[indexes[1]]);

            if (collaboration.dataModes[i] == 0) {
                condition = attribute1 == attribute2;
            }
            else if (collaboration.dataModes[i] == 1) {
                condition = attribute1 > attribute2;
            }
            else if (collaboration.dataModes[i] == 2) {
                condition = attribute1 >= attribute2;
            }

            if (condition == false) {
                decision = false;
                break;
            }
        }

        return decision;
    }

    function createDecisionObject(bytes[] memory element1, bytes[] memory element2) internal {
        string memory attribute1 = abi.decode(element1[0], (string));
        address attribute2 = abi.decode(element1[1], (address));
        uint attribute3 = abi.decode(element2[0], (uint));

        DecisionData memory newDecisionData = DecisionData(attribute1, attribute2, attribute3, block.timestamp);

        allDecisionData[count] = newDecisionData;

        count++;
    }

    function getCLA() public view returns(SignedCLA.CLA memory cla) {
        if (tx.origin != owner) { revert("Only the owner can get the CLA data"); }

        SignedCLA claContract = SignedCLA(collaboration.claAddress);

        cla = claContract.getCLAInfo();
    }

    function validateAttributes(uint[][] memory _dataIndexes, uint[] memory _dataModes)
        internal pure returns(string memory errorMessage) {

        errorMessage = "";

        if (_dataIndexes.length != _dataModes.length) { errorMessage = "The number of data's indexes must be equal to the number of data's modes"; }

        return errorMessage;
    }

    function checkSenderIfPartner(address[] memory _partnersAddresses, address _sender) internal pure returns(bool validAddress) {
        validAddress = false;

        for (uint index = 0; index < _partnersAddresses.length; index++) {
            if (_partnersAddresses[index] == _sender) {
                validAddress = true;
                break;
            }
        }

        return validAddress;
    }

    fallback() external {
        revert("An available function has not been called");
    }

}

interface Provider {
    function getCollaborationData() external payable returns(bytes[][] memory response);
}

interface SignedCLA {
    struct CLA {
        string[] partners;
        address[] providersBusinessProcess;
        address[] consumersBusinessProcess;
        string ontology;
        string[] collaborativeFunctions;
        string[] sharedData;
        string[] sharedDataTypes;
        string[] sharedPrivacyData;
        string[] sharedPrivacyDataTypes;
        string privacyAlgorithm;
        string[] privacySalt;
        uint256 collaborationStartTime;
        uint256 collaborationEndTime;
        uint256[][] monetisation;
        uint256[] gasLimit;
        bool closed;
        bool created;
        uint256 creationTime;
    }

    function getCLAInfo() external pure returns(CLA memory cla);
}
