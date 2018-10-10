pragma solidity ^0.4.24;

import "./interfaces/ISymbolRegistry.sol";
import "./SymbolRegistryMetadata.sol";
import "../../common/libraries/BytesHelper.sol";
import "../../request-verification-layer/permission-module/Protected.sol";
import "../../common/component/SystemComponent.sol";
import "../../registry-layer/components-registry/getters/TokensFactoryAddress.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Symbol Registry
*/
contract SymbolRegistry is ISymbolRegistry, Protected, SystemComponent, TokensFactoryAddress, SymbolRegistryMetadata {
    // define libraries
    using SafeMath for uint256;
    using BytesHelper for bytes;

    // Interval for symbol expiration
    uint public exprationInterval = 604800;

    // Write info to the log when was transferred symbol ownership
    event TransferedOwnership(
        address oldOwner,
        address newOwner,
        bytes symbol,
        bytes issuerName
    );

    // Write info to the log when was registered new symbol
    event RegisteredSymbol(
        address owner,
        bytes symbol,
        bytes issuerName
    );

    // Write info to the log about symbol renewal
    event Renewal(bytes symbol);

    // Write info to the log when expiration interval was updated
    event ExpirationIntervalUpdated(uint interval);

    // Write info to the log when token was registered
    event RegisteredToken(address tokenAddress, bytes symbol);

    // Describe symbol struct
    struct Symbol {
        address owner;
        address tokenAddress;
        bytes issuerName;
        uint registeredAt;
        uint expiredAt;
    }

    // Declare storage for registered tokens symbols
    mapping(bytes => Symbol) registeredSymbols;

    /**
    * @notice Verify symbol
    * @param symbol Symbol
    */
    modifier verifySymbol(bytes symbol) {
        require(
            symbol.length > 0 && symbol.length < 6, 
            "Symbol length should always between 0 & 6"
        );
        _;
    }

    /**
    * @notice Verify symbol owner
    * @param symbol Symbol
    * @param sender Address to verify
    */
    modifier onlySymbolOwner(bytes symbol, address sender) {
        require(
            isSymbolOwner(symbol, sender), 
            "Allowed only for an owner."
        );
        _;
    }

    /**
    * @notice Initialize contract
    */
    constructor(address componentsRegistry) 
        public 
        WithComponentsRegistry(componentsRegistry)
    {
        componentName = SYMBOL_REGISTRY_NAME;
        componentId = SYMBOL_REGISTRY_ID;

        registeredSymbols["ETH"] = Symbol({
            owner: address(0),
            tokenAddress: msg.sender,
            issuerName: "",
            registeredAt: now,
            expiredAt: now + 86400 * 30 * 365 * 1000
        });
    } 

    /**
    * @notice Register new symbol in the registry
    * @param symbol Symbol
    * @param issuerName Name of the issuer
    */
    function registerSymbol(bytes symbol, bytes issuerName) 
        public 
        verifySymbol(symbol) 
        verifyPermission(msg.sig, msg.sender) 
    {
        symbol = symbol.toUpperBytes();

        require(
            registeredSymbols[symbol].tokenAddress == address(0),
            "The symbol is busy."
        );
        require(
            registeredSymbols[symbol].expiredAt < now,
            "The symbol is busy. Please wait when it will be available."
        );

        Symbol memory symbolStruct = Symbol({
            owner: msg.sender,
            tokenAddress: address(0),
            issuerName: issuerName,
            registeredAt: now,
            expiredAt: now.add(exprationInterval)
        });

        registeredSymbols[symbol] = symbolStruct;

        emit RegisteredSymbol(msg.sender, symbol, issuerName);
    }

    /**
    * @notice Renew symbol
    * @param symbol Symbol which will be renewed
    */
    function renewSymbol(bytes symbol) public onlySymbolOwner(symbol, msg.sender) {
        symbol = symbol.toUpperBytes();

        registeredSymbols[symbol].expiredAt = registeredSymbols[symbol].expiredAt.add(exprationInterval);

        emit Renewal(symbol);
    }

    /**
    * @notice Change symbol owner
    * @param newOwner Address of the new symbol owner
    * @param issuerName Name of the issuer
    */
    function transferOwnership(bytes symbol, address newOwner, bytes issuerName) 
        public
        onlySymbolOwner(symbol, msg.sender)
    {
        require(newOwner != address(0), "Invalid new owner address.");
        
        symbol = symbol.toUpperBytes();

        emit TransferedOwnership(
            registeredSymbols[symbol].owner,
            newOwner,
            symbol,
            issuerName
        );

        registeredSymbols[symbol].owner = newOwner;
        registeredSymbols[symbol].issuerName = issuerName;
    }

    /**
    * @notice Register symbol for the token
    * @param sender Token issuer address
    * @param symbol Created token symbol
    * @param tokenAddress Address of the registered token
    */
    function registerTokenToTheSymbol(
        address sender, 
        bytes symbol, 
        address tokenAddress
    ) 
        public
        onlySymbolOwner(symbol, sender)
    {
        address tokensFactory = getTokensFactoryAddress();
        require(tokenAddress != address(0), "Invalid token address");
        require(msg.sender == tokensFactory, "Allowed only for the tokens factory.");

        symbol = symbol.toUpperBytes();

        registeredSymbols[symbol].tokenAddress = tokenAddress;

        emit RegisteredToken(tokenAddress, symbol);
    }

    /**
    * @notice Update symbols expiration interval
    * @param interval New expiration interval
    */
    function updateExpirationInterval(uint interval) 
        public 
        verifyPermission(msg.sig, msg.sender)
    {
        require(interval != 0, "Invalid expiration interval.");

        exprationInterval = interval;

        emit ExpirationIntervalUpdated(interval);
    }

    /**
    * @notice Checks symbol in system 
    */
    function symbolIsAvailable(bytes symbol)
        public
        verifySymbol(symbol)
        view 
        returns (bool) 
    {
        symbol = symbol.toUpperBytes();

        return registeredSymbols[symbol].tokenAddress == address(0)
            && registeredSymbols[symbol].expiredAt < now;
    }

    /**
    * @notice Checks owner
    * @param symbol Symbol
    * @param owner Address for verification
    */
    function isSymbolOwner(bytes symbol, address owner) 
        public 
        view 
        returns (bool) 
    {
        symbol = symbol.toUpperBytes();

        return registeredSymbols[symbol].owner == owner;
    }

    /**
    * @notice Return token registred on the symbol
    */
    function getTokenBySymbol(bytes symbol) public view returns (address) {
        return registeredSymbols[symbol].tokenAddress;
    }

    /**
    * @notice Return symbol expire date
    */
    function getSymbolExpireDate(bytes symbol) public view returns (uint) {
        return registeredSymbols[symbol].expiredAt;
    }

    /**
    * @notice Return issuer name
    */
    function getIssuerNameBySymbol(bytes symbol) public view returns (bytes) {
        return registeredSymbols[symbol].issuerName;
    }
}