// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract UmiverseVerifyV2 {
    function isValidERC1271Signature(address signer, bytes32 hash, bytes memory signature) public view returns (bool){
        return SignatureChecker.isValidERC1271SignatureNow(signer, hash, signature);
    }
    function isValidSignature(address signer, bytes32 hash, bytes memory signature) public view returns (bool){
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }
}
