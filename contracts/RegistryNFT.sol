// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

struct Service {
    uint256[] tokenIds;
    address eoa;
}

contract RegistryNFT is ERC721URIStorage {
    using Counters for Counters.Counter;

    event ContractCreated(address indexed contractAddress);
    event Executed(uint256 indexed operation, address indexed to, uint256 indexed value, bytes data);

    uint256 constant OPERATION_CALL = 0;
    uint256 constant OPERATION_DELEGATECALL = 1;
    uint256 constant OPERATION_CREATE2 = 2;
    uint256 constant OPERATION_CREATE = 3;

    string private _baseTokenURI;

    Counters.Counter private _tokenIdTracker;

    mapping(string => Service) _services;

    constructor() ERC721("RegistryNFT", "RNFT")
    {
        _baseTokenURI = "https://ipfs.io/ipfs/";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function mintNFT(string memory fileHash) external returns (uint256)
    {
        uint256 id = _tokenIdTracker.current();
        _mint(_msgSender(), id + 1);
        _setTokenURI(id + 1, fileHash);
        _tokenIdTracker.increment();
        return id;
    }

    function registerService(string memory name, address eoa, uint256[] memory tokenIds) external
    {
        require(bytes(name).length > 0, 'RNFT: Invalid service name');
        require(eoa != address(0), 'RNFT: Invalid eoa address');
        for (uint256 i; i < tokenIds.length; i++) {
            require(tokenIds[i] <= _tokenIdTracker.current(), 'RNFT: Invalid token Id');
        }
        require(_services[name].eoa == address(0), 'RNFT: Service already exist');

        _services[name].eoa = eoa;
        _services[name].tokenIds = tokenIds;
    }

    function execute(uint256 operation, address to, uint256 value, bytes memory data, string memory service, bytes memory signature)
    external payable
    {
        require(bytes(service).length > 0, 'RNFT: Invalid service name');
        require(_services[service].eoa != address(0), 'RNFT: Service does not exist');
        require(verify(_services[service].eoa, operation, to, value, data, signature) == true, 'RNFT: Invalid signature');

        uint256 txGas = gasleft() - 2500;

        // CALL
        if (operation == OPERATION_CALL) {
            executeCall(to, value, data, txGas);

        // DELEGATE CALL
        } else if (operation == OPERATION_DELEGATECALL) {
            executeDelegateCall(to, data, txGas);

        // CREATE
        } else if (operation == OPERATION_CREATE) {
            performCreate(value, data);

        // CREATE2
        } else if (operation == OPERATION_CREATE2) {
            bytes32 salt = BytesLib.toBytes32(data, data.length - 32);
            bytes memory data_ = BytesLib.slice(data, 0, data.length - 32);

            address contractAddress = Create2.deploy(value, salt, data_);

            emit ContractCreated(contractAddress);
        } else {
            revert("Wrong operation type");
        }
    }


    /* Functions for verifying signature */

    function verify(address signer, uint256 operation, address to, uint256 value, bytes memory data, bytes memory signature)
    public pure returns (bool)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(operation, to, value, data));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }

    function getEthSignedMessageHash(bytes32 messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) public pure returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        // implicitly return (r, s, v)
    }

    /* Internal functions for ERC725X */

    function executeCall(address to, uint256 value, bytes memory data, uint256 txGas)
    internal returns (bool success)
    {
        assembly {
            success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function executeDelegateCall(address to, bytes memory data, uint256 txGas)
    internal returns (bool success)
    {
        assembly {
            success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function performCreate(uint256 value, bytes memory deploymentData)
    internal returns (address newContract)
    {
        assembly {
            newContract := create(value, add(deploymentData, 0x20), mload(deploymentData))
        }
        require(newContract != address(0), "Could not deploy contract");
        emit ContractCreated(newContract);
    }
}
