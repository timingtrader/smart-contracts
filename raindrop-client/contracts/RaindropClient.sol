pragma solidity ^0.4.21;

import "./StringUtils.sol";
import "./Withdrawable.sol";


contract RaindropClient is Withdrawable {
    // Events for when a user signs up for Raindrop Client and when their account is deleted
    event UserSignUp(string userName, address userAddress, bool official);
    event UserDeleted(string userName, address userAddress, bool official);
    // Events for when an application signs up for Raindrop Client and when their account is deleted
    event ApplicationSignUp(string applicationName, bool official);
    event ApplicationDeleted(string applicationName, bool official);

    using StringUtils for string;

    // Fees that unofficial users/applications must pay to sign up for Raindrop Client
    uint public unofficialUserSignUpFee;
    uint public unofficialApplicationSignUpFee;

    // User accounts
    struct User {
        string userName;
        address userAddress;
        bool official;
        bool _initialized;
    }

    // Application accounts
    struct Application {
        string applicationName;
        bool official;
        bool _initialized;
    }

    // Internally, users and applications are identified by the hash of their names
    mapping (bytes32 => User) internal userDirectory;
    mapping (bytes32 => Application) internal officialApplicationDirectory;
    mapping (bytes32 => Application) internal unofficialApplicationDirectory;

    // Allows the Hydro API to sign up official users with their app-generated address
    function officialUserSignUp(string userName, address userAddress) public onlyOwner {
        _userSignUp(userName, userAddress, true);
    }

    // Allows anyone to sign up as an unofficial user with their own address
    function unofficialUserSignUp(string userName) public payable {
        require(bytes(userName).length < 100);
        require(msg.value >= unofficialUserSignUpFee);

        return _userSignUp(userName, msg.sender, false);
    }

    // Allows the Hydro API to delete official users iff they've signed keccak256("Delete") with their public key
    function deleteUserForUser(string userName, uint8 v, bytes32 r, bytes32 s) public onlyOwner {
        bytes32 userNameHash = keccak256(userName);
        require(userNameHashTaken(userNameHash));
        address userAddress = userDirectory[userNameHash].userAddress;
        require(isSigned(userAddress, keccak256("Delete"), v, r, s));

        delete userDirectory[userNameHash];

        emit UserDeleted(userName, userAddress, true);
    }

    // Allows unofficial users to delete their account
    function deleteUser(string userName) public {
        bytes32 userNameHash = keccak256(userName);
        require(userNameHashTaken(userNameHash));
        address userAddress = userDirectory[userNameHash].userAddress;
        require(userAddress == msg.sender);

        delete userDirectory[userNameHash];

        emit UserDeleted(userName, userAddress, true);
    }

    // Allows the Hydro API to sign up official applications
    function officialApplicationSignUp(string applicationName) public onlyOwner {
        bytes32 applicationNameHash = keccak256(applicationName);
        require(!applicationNameHashTaken(applicationNameHash, true));
        officialApplicationDirectory[applicationNameHash] = Application(applicationName, true, true);

        emit ApplicationSignUp(applicationName, true);
    }

    // Allows anyone to sign up as an unofficial application
    function unofficialApplicationSignUp(string applicationName) public payable {
        require(bytes(applicationName).length < 100);
        require(msg.value >= unofficialApplicationSignUpFee);
        require(applicationName.allLower());

        bytes32 applicationNameHash = keccak256(applicationName);
        require(!applicationNameHashTaken(applicationNameHash, false));
        unofficialApplicationDirectory[applicationNameHash] = Application(applicationName, false, true);

        emit ApplicationSignUp(applicationName, false);
    }

    // Allows the Hydro API to delete applications unilaterally
    function deleteApplication(string applicationName, bool official) public onlyOwner {
        bytes32 applicationNameHash = keccak256(applicationName);
        require(applicationNameHashTaken(applicationNameHash, official));
        if (official) {
            delete officialApplicationDirectory[applicationNameHash];
        } else {
            delete unofficialApplicationDirectory[applicationNameHash];
        }

        emit ApplicationDeleted(applicationName, official);
    }

    // Allows the Hydro API to changes the unofficial user fee
    function setUnofficialUserSignUpFee(uint newFee) public onlyOwner {
        unofficialUserSignUpFee = newFee;
    }

    // Allows the Hydro API to changes the unofficial application fee
    function setUnofficialApplicationSignUpFee(uint newFee) public onlyOwner {
        unofficialApplicationSignUpFee = newFee;
    }

    // Indicates whether a given user name has been claimed
    function userNameTaken(string userName) public view returns (bool taken) {
        bytes32 userNameHash = keccak256(userName);
        return userDirectory[userNameHash]._initialized;
    }

    // Indicates whether a given application name has been claimed for official and unofficial applications
    function applicationNameTaken(string applicationName)
        public
        view
        returns (bool officialTaken, bool unofficialTaken)
    {
        bytes32 applicationNameHash = keccak256(applicationName);
        return (
            officialApplicationDirectory[applicationNameHash]._initialized,
            unofficialApplicationDirectory[applicationNameHash]._initialized
        );
    }

    // Returns user details by user name
    function getUserByName(string userName) public view returns (address userAddress, bool official) {
        bytes32 userNameHash = keccak256(userName);
        require(userNameHashTaken(userNameHash));
        User storage _user = userDirectory[userNameHash];

        return (_user.userAddress, _user.official);
    }

    // Checks whether the provided (v, r, s) signature was created by the private key associated with _address
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return ecrecover(messageHash, v, r, s) == _address;
    }

    // Common internal logic for all user signups
    function _userSignUp(string userName, address userAddress, bool official) internal {
        bytes32 userNameHash = keccak256(userName);
        require(!userNameHashTaken(userNameHash));
        userDirectory[userNameHash] = User(userName, userAddress, official, true);

        emit UserSignUp(userName, userAddress, official);
    }

    // Internal check for whether a user name has been taken
    function userNameHashTaken(bytes32 userNameHash) internal view returns (bool) {
        return userDirectory[userNameHash]._initialized;
    }

    // Internal check for whether an application name has been taken
    function applicationNameHashTaken(bytes32 applicationNameHash, bool official) internal view returns (bool) {
        if (official) {
            return officialApplicationDirectory[applicationNameHash]._initialized;
        } else {
            return unofficialApplicationDirectory[applicationNameHash]._initialized;
        }
    }
}