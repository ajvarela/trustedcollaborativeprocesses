// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract AbstractProviderWithBlock {
    uint count = 0;
    address owner;
    address businessContractAddress;

    struct Collaboration {
        address[] providersBusinessProcess;
        address[] consumersBusinessProcess;
        string[] sharedData;
        string[] sharedPrivacyData;
        string privacyAlgorithm;
        string[] privacySalt;
        uint256 collaborationStartTime;
        uint256 collaborationEndTime;
        uint256[] monetisation; // the value at each position matches the consumer (who pays wei to consume data) at the same position in the array "consumersBusinessProcess"
        uint256[] gasLimit; // the value at each position matches the consumer (who pays gas to consume data) at the same position in the array "consumersBusinessProcess"
        address claAddress;
    }

    struct BusinessData {
        mapping(bytes => bytes) businessData;
        mapping(string => string) types;
    }

    mapping (string => Collaboration) collaborations;
    mapping(uint => BusinessData) allBusinessData;

    constructor(
        address _businessContractAddress,
        string memory _collaborationName,
        address[] memory _providersBusinessProcess,
        address[] memory _consumersBusinessProcess,
        string[] memory _sharedData,
        string[] memory _sharedPrivacyData,
        string memory _privacyAlgorithm,
        string[] memory _privacySalt,
        uint256 _collaborationStartTime,
        uint256 _collaborationEndTime,
        uint256[] memory _monetisation,
        uint256[] memory _gasLimit,
        address _claAddress
    ) {
        bool validAddress = checkSenderIfPartner(_providersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a provider can create a provider's Smart Contract"); }

        string memory errorMessage = validateAttributes(_consumersBusinessProcess, _privacyAlgorithm, _collaborationStartTime, _collaborationEndTime, _monetisation);

        if (keccak256(bytes(errorMessage)) != keccak256(bytes(""))) { revert(errorMessage); }

        owner = tx.origin;
        businessContractAddress = _businessContractAddress;

        addCollaboration(_collaborationName, _providersBusinessProcess, _consumersBusinessProcess, _sharedData, _sharedPrivacyData, _privacyAlgorithm,
            _privacySalt, _collaborationStartTime, _collaborationEndTime, _monetisation, _gasLimit, _claAddress);
    }

    function addCollaboration(string memory _collaborationName, address[] memory _providersBusinessProcess, address[] memory _consumersBusinessProcess, string[] memory _sharedData,
        string[] memory _sharedPrivacyData, string memory _privacyAlgorithm, string[] memory _privacySalt, uint256 _collaborationStartTime, uint256 _collaborationEndTime,
        uint256[] memory _monetisation, uint256[] memory _gasLimit, address _claAddress) public {

        if (tx.origin != owner) { revert("Only the owner can add a collaboration"); }

        Collaboration memory newCollaboration = Collaboration(_providersBusinessProcess, _consumersBusinessProcess, _sharedData, _sharedPrivacyData,
            _privacyAlgorithm, _privacySalt, _collaborationStartTime, _collaborationEndTime, _monetisation, _gasLimit, _claAddress);

        collaborations[_collaborationName] = newCollaboration;
    }

    function getCollaborationData(string memory _collaborationName) public payable returns(bytes[][] memory response) {
        uint256 initialGasLeft = gasleft();
        uint256 gasLimit;

        Collaboration memory collaboration = collaborations[_collaborationName];

        bool validAddress = checkSenderIfPartner(collaboration.consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a consumer can get the data of the collaboration"); }

        if (block.timestamp < collaboration.collaborationStartTime) { revert("The collaboration has not yet started"); }

        if (block.timestamp > collaboration.collaborationEndTime) { revert("The collaboration has already ended"); }

        if (msg.value >= 2^256 ether) { revert("The maximum amount of Ether allowed to be sent has been exceeded"); }

        for (uint index = 0; index < collaboration.consumersBusinessProcess.length; index++) {
            if (collaboration.consumersBusinessProcess[index] == tx.origin) {
                gasLimit = collaboration.gasLimit[index];

                if (collaboration.monetisation[index] < msg.value) { revert("The price paid to obtain the data is lower than the agreed price"); }

                break;
            }
        }

        getBusinessData();

        for (uint i = 0; i <= count; i++) {
            bytes[] memory actualObject = new bytes[](collaboration.sharedData.length + collaboration.sharedPrivacyData.length);

            for (uint j = 0; j < collaboration.sharedData.length; j++) {
                bytes memory attributeName = bytes(collaboration.sharedData[j]);

                actualObject[j] = allBusinessData[i].businessData[attributeName];
            }

            bytes32 hashedData;
            bytes memory salt;

            for (uint j = 0; j < collaboration.privacySalt.length; j++) {
                bytes memory attributeName = bytes(collaboration.privacySalt[j]);

                salt = bytes.concat(salt, allBusinessData[i].businessData[attributeName]);
            }

            for (uint j = 0; j < collaboration.sharedPrivacyData.length; j++) {
                bytes memory attributeName = bytes(collaboration.sharedPrivacyData[j]);
                bytes memory dataToHash = bytes.concat(allBusinessData[i].businessData[attributeName], salt);

                if (keccak256(bytes(collaboration.privacyAlgorithm)) == keccak256(bytes("SHA-3"))) {
                    hashedData = keccak256(dataToHash);
                }
                else if (keccak256(bytes(collaboration.privacyAlgorithm)) == keccak256(bytes("SHA-256"))) {
                    hashedData = sha256(dataToHash);
                }
                else if (keccak256(bytes(collaboration.privacyAlgorithm)) == keccak256(bytes("RIPEMD"))) {
                    hashedData = ripemd160(dataToHash);
                }

                actualObject[j + collaboration.sharedData.length] = abi.encodePacked(hashedData);
            }

            response[i] = actualObject;
        }

        uint256 finalGasLeft = gasleft();

        for (uint index = 0; index < collaboration.consumersBusinessProcess.length; index++) {

        }

        if (finalGasLeft - initialGasLeft >= gasLimit) { revert("This transaction will exceed the gas limit"); }

        return response;
    }

    function getBusinessData() internal {
        BusinessContract businessContract = BusinessContract(businessContractAddress);

        BusinessContract.DataStruct[] memory data = businessContract.getBusinessData();

        for (uint i = 0; i < data.length; i++) {
            allBusinessData[count].businessData["attribute1"] = abi.encode(data[i].attribute1);
            allBusinessData[count].types["attribute1"] = "string";

            allBusinessData[count].businessData["attribute2"] = abi.encode(data[i].attribute2);
            allBusinessData[count].types["attribute2"] = "address";

            allBusinessData[count].businessData["attribute3"] = abi.encode(data[i].attribute3);
            allBusinessData[count].types["attribute3"] = "uint";

            allBusinessData[count].businessData["blockTime"] = abi.encode(data[i].blockTime);
            allBusinessData[count].types["blockTime"] = "uint256";

            count++;
        }
    }

    function getCLA(string memory _collaborationName) public view returns(SignedCLA.CLA memory cla) {
        if (tx.origin != owner) { revert("Only the owner can get the CLA data"); }

        Collaboration memory collaboration = collaborations[_collaborationName];

        SignedCLA claContract = SignedCLA(collaboration.claAddress);

        cla = claContract.getCLAInfo();
    }

    function validateAttributes(address[] memory _consumersBusinessProcess, string memory _privacyAlgorithm, uint256 _collaborationStartTime, uint256 _collaborationEndTime, uint256[] memory _monetisation)
        internal view returns(string memory errorMessage) {

        errorMessage = "";

        if (
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("SHA-3")) &&
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("SHA-256")) &&
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("RIPEMD"))
        ) { errorMessage = "The indicated privacy algorithm has to be among the three available options: SHA-3, SHA-256 and RIPEMD"; }

        else if (block.timestamp > _collaborationStartTime) { errorMessage = "The CLA' start date must be after the current date"; }

        else if (_collaborationStartTime > _collaborationEndTime) { errorMessage = "The start date cannot be later than the end date"; }

        else if (_consumersBusinessProcess.length != _monetisation.length) { errorMessage = "The number of consumers must be equal to the length of the monetisation array"; }

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

interface BusinessContract {
    struct DataStruct {
        uint id;
        string attribute1;
        address attribute2;
        uint attribute3;
        uint256 blockTime;
    }

    function getBusinessData() external pure returns(DataStruct[] memory data);
}

interface SignedCLA {
    struct CLA {
        string[] partners;
        address[] providersBusinessProcess;
        address[] consumersBusinessProcess;
        string ontology;
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
