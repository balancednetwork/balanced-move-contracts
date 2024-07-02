
**Balanced SUI spoke contracts**

This document outlines the major changes in the implementation of Balanced in the Sui blockchain and the rationale behind these changes. Key updates include modifications to the execution process of calls and rollbacks, the introduction of forced rollback mechanisms, Token registration, Token contract of balanced dollar split from Balanced dollar contract.

For more details on each spoke contracts see: [Balanced Crosschain Docs](https://github.com/balancednetwork/balanced-java-contracts/blob/420-balanced-docs/docs/crosschain.md)

For more details on the Balanced Protocol see: [Balanced Docs](https://github.com/balancednetwork/balanced-java-contracts/blob/420-balanced-docs/docs/docs.md)

1. **Execution of incoming calls and rollbacks**

   **Change:** The regular flow for the incoming messages that xCall calls the Balanced `handleCallMessage` method is replaced with the new flow: Balanced `execute_call` and `execute_rollback` methods call the xCall `execute_call` method.

   **Process:**
   1. Balanced each contract registers as a dApp to the xCall and receives the registration ID while configured.
   2. **Initiate Call from Balanced:** Balanced initiates a call to xCall with the registration ID and receives a ticket containing execution data and protocol information.
   3. **Retrieve Execution Data:** Balanced retrieves execution data from the ticket.
   4. **Execute Call within Balanced:** Balanced executes the call using its own state and data.
   5. **Report Execution Result:**
      * If successful, Balanced sends `true` to `execute_call_result` in xCall.
      * If failed, Balanced sends `false` to `execute_call_result` in xCall.

   **Rationale:**
   * Sui is a stateless blockchain, meaning it does not maintain the state of every dApp.
   * Executing calls from xCall would require accessing the data of each dApp, which is inefficient.
   * By executing calls from the dApps, each dApp has its own data and uses a common xCall, making the process more efficient and reducing the data management overhead for xCall.

2. **Handling Rollback Failures**

   **Change:** Introduced `execute_forced_rollback` in Balanced, which can be executed by an admin in case of a failure in `execute_call`.

   **Rationale:** There is no concept of exception handling in Sui, such as try-catch, making it impossible to rollback every message that fails in `execute_call`. Instead, it will fail the entire transaction if there is a configuration failure.

3. **Token Registration for Deposit**

   **Change:** Added a new feature to register the Sui tokens to be accepted in the Balanced platform.

   **Rationale:** Sui tokens implement the UTXO model, which involves transferring the actual coin rather than the value of the coin in Sui while depositing on Balanced. The coin needs to be identified by the contract to accept it. For this purpose, the coin is registered priorly.

4. **Balanced Dollar Token Contract Separation**

   **Change:** Token contract for Balanced Dollar is separated from the cross-chain features.

   **Rationale:** For each upgrade of the contract, SUI creates a new ID, and each new and old ID is accessible for communication. It is irrelevant to have multiple IDs for a token, and it's better for token contracts to be immutable. Therefore, the Balanced Dollar token contract is separated to avoid future upgrades, while the Balanced Dollar cross-chain contract can be upgraded in the future.

5. **Version Upgrade Feature**

   **Change:** Version upgrade feature is added to each Balanced contract except the Token contract.

   **Rationale:** Contract communication on the SUI blockchain is possible using each contract ID after upgrades. To restrict the communication to the latest upgrade only, the Balanced version upgrade feature is implemented.
