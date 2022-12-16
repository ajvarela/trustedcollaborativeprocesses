// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract AbstractCLA {
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
        uint256[][] monetisation; // the value at each row matches the consumer (the payer) at the same position in the array "consumersBusinessProcess", each column matches the provider (the payee) at
                                    // the same position in "providersBusinessProcess", example: [[10, 20], [30, 40]] -> the first consumer has to pay 10 wei to the first provider and 20 wei to the second
        uint256[] gasLimit; // the value at each position matches the consumer (who pays gas to consume data) at the same position in the array "consumersBusinessProcess"
        bool closed;
        bool created;
        uint256 creationTime;
    }

    CLA cla;
    mapping(address => bool) signed;

    constructor(
        string[] memory _partners,
        address[] memory _providersBusinessProcess,
        address[] memory _consumersBusinessProcess,
        string memory _ontology,
        string[] memory _collaborativeFunctions,
        string[] memory _sharedData,
        string[] memory _sharedDataTypes,
        string[] memory _sharedPrivacyData,
        string[] memory _sharedPrivacyDataTypes,
        string memory _privacyAlgorithm,
        string[] memory _privacySalt,
        uint256 _collaborationStartTime,
        uint256 _collaborationEndTime,
        uint256[][] memory _monetisation,
        uint256[] memory _gasLimit
    ) {
        bool validAddress = checkSenderIfPartner(_providersBusinessProcess, _consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a partner can create the CLA"); }

        string memory errorMessage = validateAttributes(_partners, _providersBusinessProcess, _consumersBusinessProcess, _sharedData, _sharedDataTypes, _sharedPrivacyData,
            _sharedPrivacyDataTypes, _privacyAlgorithm, _collaborationStartTime, _collaborationEndTime, _monetisation);

        if (keccak256(bytes(errorMessage)) != keccak256(bytes(""))) { revert(errorMessage); }

        cla = CLA(_partners, _providersBusinessProcess, _consumersBusinessProcess, _ontology, _collaborativeFunctions, _sharedData, _sharedDataTypes, _sharedPrivacyData,
            _sharedPrivacyDataTypes, _privacyAlgorithm, _privacySalt, _collaborationStartTime, _collaborationEndTime, _monetisation, _gasLimit, false, true, block.timestamp);
    }

    function getCLAInfo() public view returns(CLA memory) {
        if (!cla.created) { revert("The CLA has not yet been created"); }

        bool validAddress = checkSenderIfPartner(cla.providersBusinessProcess, cla.consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a partner can get the data of the CLA"); }

        return cla;
    }

    function updateCLA(string[] memory _partners, address[] memory _providersBusinessProcess, address[] memory _consumersBusinessProcess, string memory _ontology, string[] memory _collaborativeFunctions,
        string[] memory _sharedData, string[] memory _sharedDataTypes, string[] memory _sharedPrivacyData, string[] memory _sharedPrivacyDataTypes, string memory _privacyAlgorithm, string[] memory _privacySalt,
        uint256 _collaborationStartTime, uint256 _collaborationEndTime, uint256[][] memory _monetisation, uint256[] memory _gasLimit) public {

        if (!cla.created) { revert("The CLA has not yet been created"); }

        bool validAddress = checkSenderIfPartner(cla.providersBusinessProcess, cla.consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a partner can update the CLA"); }

        if (cla.closed) { revert("The CLA cannot be updated as all partners have signed it."); }

        string memory errorMessage = validateAttributes(_partners, _providersBusinessProcess, _consumersBusinessProcess, _sharedData, _sharedDataTypes, _sharedPrivacyData,
            _sharedPrivacyDataTypes, _privacyAlgorithm, _collaborationStartTime, _collaborationEndTime, _monetisation);

        if (keccak256(bytes(errorMessage)) != keccak256(bytes(""))) { revert(errorMessage); }

        cla.partners = _partners;
        cla.providersBusinessProcess = _providersBusinessProcess;
        cla.consumersBusinessProcess = _consumersBusinessProcess;
        cla.ontology = _ontology;
        cla.collaborativeFunctions = _collaborativeFunctions;
        cla.sharedData = _sharedData;
        cla.sharedDataTypes = _sharedDataTypes;
        cla.sharedPrivacyData = _sharedPrivacyData;
        cla.sharedPrivacyDataTypes = _sharedPrivacyDataTypes;
        cla.privacyAlgorithm = _privacyAlgorithm;
        cla.privacySalt = _privacySalt;
        cla.collaborationStartTime = _collaborationStartTime;
        cla.collaborationEndTime = _collaborationEndTime;
        cla.monetisation = _monetisation;
        cla.gasLimit = _gasLimit;

        for (uint index = 0; index < _providersBusinessProcess.length; index++) {
            signed[_providersBusinessProcess[index]] = false;
        }

        for (uint index = 0; index < _consumersBusinessProcess.length; index++) {
            signed[_consumersBusinessProcess[index]] = false;
        }
    }

    function signCLA() public {
        if (!cla.created) { revert("The CLA has not yet been created"); }

        bool validAddress = checkSenderIfPartner(cla.providersBusinessProcess, cla.consumersBusinessProcess, tx.origin);

        if (!validAddress) { revert("Only a partner can sign the CLA"); }

        signed[tx.origin] = true;

        bool allSigned = checkIfAllSigned(cla.providersBusinessProcess, cla.consumersBusinessProcess);

        if (allSigned) {
            cla.closed = true;
        }
    }

    function validateAttributes(string[] memory _partners, address[] memory _providersBusinessProcess, address[] memory _consumersBusinessProcess, string[] memory _sharedData,
        string[] memory _sharedDataTypes, string[] memory _sharedPrivacyData, string[] memory _sharedPrivacyDataTypes, string memory _privacyAlgorithm, uint256 _collaborationStartTime,
        uint256 _collaborationEndTime, uint256[][] memory _monetisation) internal view returns(string memory errorMessage) {

        errorMessage = "";

        if (_partners.length != _providersBusinessProcess.length + _consumersBusinessProcess.length) { errorMessage = "The number of partners does not match in the different arrays"; }

        else if (_sharedData.length != _sharedDataTypes.length) { errorMessage = "The number of shared data does not match with the number of data types indicated"; }

        else if (_sharedPrivacyData.length != _sharedPrivacyDataTypes.length) { errorMessage = "The number of shared privacy data does not match with the number of data types indicated"; }

        else if (
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("SHA-3")) &&
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("SHA-256")) &&
            keccak256(bytes(_privacyAlgorithm)) != keccak256(bytes("RIPEMD"))
        ) { errorMessage = "The indicated privacy algorithm has to be among the three available options: SHA-3, SHA-256 and RIPEMD"; }

        else if (block.timestamp > _collaborationStartTime) { errorMessage = "The CLA' start date must be after the current date"; }

        else if (_collaborationStartTime > _collaborationEndTime) { errorMessage = "The start date cannot be later than the end date"; }

        else if (_monetisation.length != _consumersBusinessProcess.length) { errorMessage = "The number of consumers must be equal to the number of rows in the monetisation matrix"; }

        else if (_monetisation[0].length != _providersBusinessProcess.length) { errorMessage = "The number of providers must be equal to the number of columns in the monetisation matrix"; }

        return errorMessage;
    }

    function checkSenderIfPartner(address[] memory _providersBusinessProcess, address[] memory _consumersBusinessProcess, address _sender) internal pure returns(bool validAddress) {
        validAddress = false;

        for (uint index = 0; index < _providersBusinessProcess.length; index++) {
            if (_providersBusinessProcess[index] == _sender) {
                validAddress = true;
                break;
            }
        }

        if (validAddress == false) {
            for (uint index = 0; index < _consumersBusinessProcess.length; index++) {
                if (_consumersBusinessProcess[index] == _sender) {
                    validAddress = true;
                    break;
                }
            }
        }

        return validAddress;
    }

    function checkIfAllSigned(address[] memory _providersBusinessProcess, address[] memory _consumersBusinessProcess) internal view returns(bool allSigned) {
        allSigned = false;
        uint signCount = 0;

        for (uint index = 0; index < _providersBusinessProcess.length; index++) {
            if (signed[_providersBusinessProcess[index]] == true) {
                signCount++;
            }
        }

        for (uint index = 0; index < _consumersBusinessProcess.length; index++) {
            if (signed[_consumersBusinessProcess[index]] == true) {
                signCount++;
            }
        }

        if (signCount == _providersBusinessProcess.length + _consumersBusinessProcess.length) {
            allSigned = true;
        }

        return allSigned;
    }

    fallback() external {
        revert("An available function has not been called");
    }

}
