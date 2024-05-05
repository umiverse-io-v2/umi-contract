    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/Strings.sol";
import "./lib/Signature.sol";

contract UmiverseVerify {
    using Signature for uint256;

    function getMessageHash(
        uint256 _timestamp
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _timestamp
                )
            );
    }

    function verify(
        address _signer,
        uint256 _timestamp,
        bytes memory _signature
    )public pure returns (bool) {
        bytes32 messageHash = getMessageHash(
            _timestamp
        );
        bytes32 ethSignedMessageHash = Signature.getEthSignedMessageHash(messageHash);
        return Signature.recoverSigner(ethSignedMessageHash, _signature) == _signer;
    }

    
}
