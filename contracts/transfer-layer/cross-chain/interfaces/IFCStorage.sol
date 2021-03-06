pragma solidity ^0.5.0;


/**
* @title Interface of the from chain transfers storage
*/
contract IFCStorage {
    /**
    * @notice Write info to the log when cross chain transfer was initiated
    * @param tokenAddress Token address
    * @param sender Tokens owner
    * @param txId Cross chain transaction id (defined by cross chain service in the current chain)
    * @param chain Target chain
    * @param targetAddress Recipient wallet in the other chain
    * @param value Amount of tokens || token id for the CAT-721 token
    */
    function emitSentToOtherChain(
        address tokenAddress,
        address sender,
        uint txId,
        bytes32 chain,
        bytes32 targetAddress,
        uint value
    )
        public;

    /**
    * @notice Set transaction id value
    * @param value New transaction id
    */
    function setTransactionId(uint value) public;

    /**
    * @notice Returns transaction id
    */
    function getTransactionId() public view returns (uint);
}