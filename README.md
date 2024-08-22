# Balanced Package Structure

## Overview

The Balanced package within the Sui blockchain ecosystem is designed to manage various aspects of the decentralized application (dApp) including asset management, cross-chain communication, and stablecoin operations. This structure ensures efficient handling of these operations through well-defined modules and unique identifiers.

## Modules

The Balanced package is divided into three main modules, each responsible for specific functionalities:

### 1. Asset Manager: asset_manager
- **Purpose**: Manages assets within the Balanced ecosystem.
  
### 2. xCall Manager: xcall_manager
- **Purpose**: Facilitates cross-chain administration from the icon side.

### 3. Balanced Dollar: balanced_dollar_crosschain
- **Purpose**: Manages the crosschain bnUSD operations within the Balanced ecosystem.

## Identifiers

### Package ID
- **Definition**: A unique identifier for the entire Balanced package within the Sui blockchain.
- **Usage**: Used for function calls and interactions with the Balanced package from the Sui side.

### Cap IDs
- **Definition**: Unique identifiers for each module within the Balanced package, akin to contract addresses in other blockchain ecosystems.
- **Usage**:
  - Each module (Asset Manager, xCall Manager, Balanced Dollar) has its own Cap ID.
  - Cap IDs are used for configuring the Balanced package in other chains.
  - They enable specific interactions and operations within each module, ensuring modular and isolated management of functionalities.

## Usage in Cross-Chain Configuration

- **Configuration**: Cap IDs are critical for setting up Balanced in cross-chain environments. They ensure that each module can be independently addressed and interacted with from other chains.
- **Function Calls**: While the Package ID is used for function calls from the Sui blockchain, module-name allow for precise targeting of module-specific operations in the following way like

```shell
sui client call --package <package_id> --module <module_name> --function <function name> --args <argument_lists> 
```

## Frontend Integration Interfaces

This guide provides an overview of the key functions for interacting with the Sui blockchain within your frontend application. These functions are part of the Asset Manager, Balanced Dollar, and XCall modules, which allow for token deposits, cross-chain transfers, and cross-chain calls.

### Important Note: Statelessness in Sui

Sui is a stateless blockchain, which means that unlike stateful blockchains, it does not automatically keep track of states between transactions. Due to this, when interacting with Sui, you need to provide certain storage IDs manually to manage the state. This is why additional parameters like `config`, `xcallState`, `xcall_manager_config`, and others are required when calling functions.

---

### Asset Manager Module

The Asset Manager module handles depositing sui tokens in balanced.

#### `deposit`

Deposits a specified amount of a token into the Sui blockchain.

```typescript
function deposit<T>(
    config: Config,            // Represents the asset manager's state.
    xcallState: XCallState,    // Represents xcall state.
    xcall_manager_config: XcallManagerConfig,  // Configuration for the xcall manager.
    fee: Coin<SUI>,            // A fee in SUI tokens for the transaction.
    token: Coin<T>,            // The token being deposited. Make sure to split the token into      
                               //the desired amount before sending it.
    to?: string,               // (Optional) The recipient's address if needed.
    data?: Uint8Array,         // (Optional) Any additional data you want to attach to the deposit.
    ctx: TxContext             // The transaction context for handling the transaction.
);
```

### Understanding the Generic Type `<T>` in `deposit` Function

In the `deposit` function within the Asset Manager module, the generic type parameter `<T>` represents the specific type of token that you are going to deposit. This type is crucial because it defines the exact token being used in the transaction.

#### Type Argument Format

The type argument for `<T>` should follow the format:

```bash
<package_id>::<module_name>::<token_name>
```

For instance, if you want to deposit SUI tokens, you would specify the type as:
`0x2::sui::SUI`

---

### Balanced Dollar Module

The Balanced Dollar module facilitates the transfer of `BALANCED_DOLLAR` tokens across chains.

#### `cross_transfer`

Transfers `BALANCED_DOLLAR` tokens across chains.

```typescript
function cross_transfer(
    config: Config,            // Represents the asset manager's state.
    xcall_state: XCallState,   // Represents the xcall state.
    xcall_manager_config: XcallManagerConfig,  // Represents for the xcall manager state.
    fee: Coin<SUI>,            // A fee in SUI tokens for the transaction.
    token: Coin<BALANCED_DOLLAR>,  // The BALANCED_DOLLAR token to transfer. The token object will be destroyed, so split it to the needed amount.
    to: string,                // The recipient's address on the destination chain.
    data?: Uint8Array,         // (Optional) Any additional data to attach to the transfer.
    ctx: TxContext             // The transaction context for handling the transaction.
);
```

### XCallManager Module

#### get_protocols
The `get_protocols` function retrieves the sources and destinations associated with a given configuration. 

```typescript
function get_protocols(
    config: Config               // Represents for the xcall manager state
): [string[], string[]];        // Returns a tuple containing two arrays: sources and destinations.
```

---

### XCall Module

#### `send_call_ua`

Sends a cross-chain call to a specified address.

```typescript
function send_call_ua(
    storage: Storage,          // The storage object that holds the state of the xcall.
    fee: Coin<SUI>,            // A fee in SUI tokens for the transaction.
    to: string,                // The recipient's address.
    envelope_bytes: Uint8Array,  // The data needed for the cross-chain call.
    ctx: TxContext             // The transaction context for handling the transaction.
);
```

#### `get_fee`

The `get_fee` function calculates and returns the fee required for a cross-chain transaction.

```typescript
function get_fee(
    storage: Storage,                 // The storage object that holds the state of the xcall.
    netId: string,                    // The network ID where the transaction is headed.
    rollback: boolean,                // A boolean flag indicating whether the transaction is a rollback.
    sources?: string[]                // An optional array of source connections.
): number
```

