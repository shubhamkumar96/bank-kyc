pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract KYC {

    //  Declaring admin
    address admin;

    //  Bank Type: It defines a custom type to be used for referencing Banks.
    struct Bank {
        string bankName;
        address bankAddress;
        uint256 rating;
        uint256 upvotes;    //  Adding this to track the number of upvotes for a particular Bank.
        uint256 KYC_count;
        string regNumber;
    }

    //  Customer Type: It defines a custom type to be used for referencing Customers.
    struct Customer {
        string userName;
        string dataHash;
        uint256 rating; //  Note that rating is multiplied by 100.
        uint256 upvotes;
        address bankAddress;
        string password;    //  Adding this to store password for that particular customer.
    }

    //  KYCRequest Type: It defines a custom type to be used for referencing KYCRequests.
    struct KYCRequest {
        string userName;
        address bankAddress;
        string dataHash;
        bool isAllowed;
    }

    // Mapping containing upvotes for each customer, here userName is 'key' & address of Bank who upvoted is 'value'.
    mapping(string => mapping(address => uint256)) public customerUpvotes;

    // Mapping containing upvotes for each bank, here address of bank being upvoted is 'key' & address of Bank who upvoted is 'value'.
    mapping(address => mapping(address => uint256)) public bankUpvotes;

    //  Mapping to store request, here address of bank is 'key' & Bank struct is 'value'.
    mapping(address => Bank ) public bankList;
    uint256 public numberOfBanks;  //  To store the count of Banks added.

    //  Mapping to store request, here hash of customer's ID  is 'key' & KYCRequest is 'value'.
    mapping(string => KYCRequest ) public kycRequestList;

    //  Mapping to store request, here bank address is 'key' & KYCRequest[] is 'value'.
    mapping(address => KYCRequest[] ) public kycRequestListByBank;

    //  Mapping to store verified customer, here userName is 'key' & Customer is 'value'.
    mapping(string => Customer ) public customerList;

    //  Mapping to store final verified customer, here userName is 'key' & Customer is 'value'.
    //  This list will contain the customers whose rating are more than 50(0.5*100)
    mapping(string => Customer ) public finalCustomerList;

    //  Defining the Constructor.
    constructor() public {
        admin = msg.sender; //  Making the deployer of the contract as Admin.
    }
    //  Modifier for validating if the call is made by an 'Admin' of the contract or not.
    modifier isAdmin {
        require(msg.sender == admin, "Only Admin is allowed.");
        _;
    }

    //  Method used by 'admin' to add Banks to bankList.
    function addBank(string memory _bankName, address _bankAddress, string memory _regNumber) public isAdmin returns(bool) {
        require(bankList[_bankAddress].bankAddress == address(0), "Bank is already added");
        Bank memory _bank;
        _bank.bankName = _bankName;
        _bank.bankAddress = _bankAddress;
        _bank.regNumber = _regNumber;
        _bank.KYC_count = 0;
        _bank.rating = 0;
        bankList[_bankAddress] = _bank;
        numberOfBanks++;
        return true;
    }

    //  Method used by 'admin' to remove Banks from bankList.
    function removeBank(address _bankAddress) public isAdmin returns(bool) {
        require(bankList[_bankAddress].bankAddress != address(0), "Bank is not present/added to KYC Contract");
        delete bankList[_bankAddress];
        numberOfBanks--;
        return true;
    }

    // Called By Bank for adding KYC request to 'Request List'.
    function addRequest(string memory _userName, string memory _dataHash) public returns(uint256) {
        require(kycRequestList[_dataHash].bankAddress == address(0), "A KYC Request for this user is already present");
        KYCRequest memory kycRequest;
        kycRequest.userName = _userName;
        kycRequest.dataHash = _dataHash;
        kycRequest.bankAddress = msg.sender;
        //  Rating are multiplied by 100, as solidity not support floating point numbers.
        if(bankList[msg.sender].rating <= 50){
            kycRequest.isAllowed = false;
        } else {
            kycRequest.isAllowed = true;
        }
        kycRequestList[_dataHash] = kycRequest; //  Adding Kyc Request with '_dataHash' as key
        (kycRequestListByBank[msg.sender]).push(kycRequest);  //  Adding Kyc Request with 'bank address' as key
        bankList[msg.sender].KYC_count++;   //  To track count of KYC Request raised by a bank.
        return 1;
    }

    //  Called By Bank for adding Customer to 'Customer List' after Validation Completes.
    function addCustomer(string memory _userName, string memory _dataHash) public returns(uint256) {
        //  To check if the customer is not already present in CustomerLsit.
        require(customerList[_userName].bankAddress == address(0), "Customer is already verified, call modifyCustomer to edit customer data");

        //  We should not process a request unless we have KYC Request present for that customer in KYCRequestList.
        require(kycRequestList[_dataHash].bankAddress != address(0), "KYC Request for the customer is not present in KYC Request List");

        //  We should not process a request unless we have KYC Request present for that customer in KYCRequestList.
        require(kycRequestList[_dataHash].isAllowed == true, "KYC Request is added by untrusted Bank, so not processing this request");

        Customer memory customer;
        customer.userName = _userName;
        customer.dataHash = _dataHash;
        customer.upvotes = customer.upvotes + 1;
        customer.bankAddress = msg.sender;
        customer.password = "0";
        customerList[_userName] = customer;
        removeRequest(_userName, _dataHash);    //  Removing the KYC Request for the customer from kycRequestList.
        return 1;
    }

    //  Called By Bank for removing Request from 'Request List'.
    function removeRequest(string memory _userName, string memory _dataHash) public returns(uint256) {
        delete kycRequestList[_dataHash];
        return 1;
    }

    //  Called By Bank for removing Customer from 'Customer List'.
    function removeCustomer(string memory _userName) public returns(uint256) {
        delete customerList[_userName];
        return 1;
    }

    //  Called By Bank for viewing Customer details.
    function viewCustomer(string memory _userName, string memory _password) public view returns(string memory) {
        //  To validate the entered password.
        require(isStringsEqual(customerList[_userName].password, _password), "Password Entered is Incorrect");
        return customerList[_userName].dataHash;
    }

    //  Called By Bank for upvoting the KYC done for a particular Customer.
    function upvote(string memory _userName) public returns(uint256) {
        require(customerUpvotes[_userName][msg.sender] == 0, "Customer is already upvoted by this Bank");
        customerUpvotes[_userName][msg.sender] = 1;
        customerList[_userName].upvotes++;
        //  Multiplied by 100, as float datatype is not supported by Solidity.
        uint _rating = (customerList[_userName].upvotes) * 100 / numberOfBanks;
        if(_rating > 50){
            finalCustomerList[_userName] = customerList[_userName];
        }
        return 1;
    }

     //  Called By Bank for modifying the existing Customer details on Blockchain.
    function modifyCustomer(string memory _userName, string memory _newDataHash, string memory _password) public returns(uint256) {
        //  To check if the customer is present in CustomerLsit.
        require(customerList[_userName].bankAddress != address(0), "Customer is not verified yet");
        //  To validate the entered password.
        require(isStringsEqual(customerList[_userName].password, _password), "Password Entered is Incorrect");
        if(finalCustomerList[_userName].bankAddress != address(0)){
            delete finalCustomerList[_userName];
        }
        customerList[_userName].upvotes = 0;    //  Reset upvotes for that Bank in Customer List.
        customerList[_userName].rating = 0;     //  Reset ratings for that Bank in Customer List.
        delete customerUpvotes[_userName][msg.sender];  //  Delete the upvotes for that Bank from 'upvotes' mapping.
        customerList[_userName].dataHash = _newDataHash;    //  Updating the Hash value for that user with new Hash.
        customerList[_userName].bankAddress = msg.sender;   //  Updating the bank address for this customer.
        return 1;
    }

    //  Method to get list of KYC Request raised by a particular Bank.
    function getBankRequests(address _bankAddress) public view returns(KYCRequest[] memory) {
        return kycRequestListByBank[_bankAddress];
    }

    //  Method used by bank to upvote other Banks and also to update its rating 
    function upvoteBank(address _bankAddress) public returns(uint256) {
        require(bankUpvotes[_bankAddress][msg.sender] == 0, "Bank has already been upvoted by this bank");
        bankUpvotes[_bankAddress][msg.sender] = 1;
        bankList[_bankAddress].upvotes++;
        bankList[_bankAddress].rating = (bankList[_bankAddress].upvotes) * 100 / numberOfBanks;
        return 1;
    }

    //  Method to get Customer rating
    function getCustomerRating(string memory _userName) public view returns(uint256) {
        return customerList[_userName].rating;
    }

    //  Method to get Bank rating
    function getBankRating(address _bankAddress) public view returns(uint256) {
        return bankList[_bankAddress].rating;
    }

    //  Method to get address of bank which last updated the customer data.
    function getAccessHistory(string memory _userName) public view returns(address) {
        return customerList[_userName].bankAddress;
    }

    //  Method to set Password for a particular Customer.
    function setPassword(string memory _userName, string memory _password) public returns(bool) {
        customerList[_userName].password = _password;
        return true;
    }

    //  Method to get Bank details
    function getBankDetails(address _bankAddress) public view returns(Bank memory) {
        return bankList[_bankAddress];
    }

    //  Utility method to compare two Strings.
    function isStringsEqual(string memory _a, string memory _b) internal pure returns (bool) {
        return ( keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b)) );
    }


}