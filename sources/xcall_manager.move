#[allow(unused_const)]
module balanced::xcall_manager{
    use std::string::{Self, String};
    use std::vector;
    use std::debug;

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    

    const CONFIGURE_PROTOCOLS_NAME: vector<u8> = b"ConfigureProtocols";
    const EXECUTE_NAME: vector<u8> = b"Execute";

    const NoProposalForRemovalExists: u64 = 0;
    const ProtocolMismatch: u64 = 1;
    const OnlyICONBalancedgovernanceIsAllowed: u64 = 2;

    public struct Config has key, store {
        id: UID, 
        iconGovernance: String,
        admin: address,
        sources: vector<String>,
        destinations: vector<String>,
        proposedProtocolToRemove: String
    }

    public struct AdminCap has key {
        id: UID, 
    }

    public struct CallServiceCap has key {
        id: UID, 
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    entry fun configure(_: &AdminCap, _iconGovernance: String,  _admin: address, _sources: vector<String>, _destinations: vector<String>, ctx: &mut TxContext ){
        transfer::share_object(Config {
            id: object::new(ctx),
            iconGovernance: _iconGovernance,
            admin: _admin,
            sources: _sources,
            destinations: _destinations,
            proposedProtocolToRemove: string::utf8(b"")
        });
    }

    public fun getProtocals(config: &Config):(vector<String>, vector<String>){
        (config.sources, config.destinations)
    }

    entry fun proposeRemoval(_: &AdminCap, config: &mut Config, protocol: String) {
        config.proposedProtocolToRemove = protocol;
    }

    public fun handleCallMessage(
        config: &Config,
        from: String,
        data: vector<vector<u8>>,
        protocols: vector<String>,
    
    )  {
        assert!(
            from == config.iconGovernance,
            OnlyICONBalancedgovernanceIsAllowed
        );
        
        //string memory method = data.getMethod();
        let mut method = CONFIGURE_PROTOCOLS_NAME; //read methdo from data

        if (!verifyProtocolsUnordered(&protocols, &config.sources)) {
            assert!(
                method == CONFIGURE_PROTOCOLS_NAME,
                ProtocolMismatch
            );
            verifyProtocolRecovery(protocols, config);
        };

        method = EXECUTE_NAME;
        assert!(
                method == CONFIGURE_PROTOCOLS_NAME || method == EXECUTE_NAME,
                ProtocolMismatch
            );
        if (method == EXECUTE_NAME) {
            // Messages.Execute memory message = data.decodeExecute();
            // (bool _success, ) = message.contractAddress.call(message.data);
            // require(_success, "Failed to excute message");
        } else if (method == CONFIGURE_PROTOCOLS_NAME) {
            // Messages.ConfigureProtocols memory message = data
            //     .decodeConfigureProtocols();
            // sources = message.sources;
            // destinations = message.destinations;
        };
    }
    
    public fun verifyProtocols(
       config: &Config, protocols: vector<String>
    ): bool {
         verifyProtocolsUnordered(&protocols, &config.sources)
    }

    fun verifyProtocolRecovery(protocols: vector<String>, config: &Config) {
        assert!(
            verifyProtocolsUnordered(&getModifiedProtocols(config), &protocols),
            ProtocolMismatch
        );
    }

    fun verifyProtocolsUnordered(
        array1: &vector<String>,
        array2: &vector<String>
    ):bool {
        let len1 = vector::length(array1);
        if(len1!=vector::length(array2)){
            false
        }else{
            let mut matched = true;
            let mut i = 0;
            while(i < len1){
                if(!vector::contains(array2, vector::borrow(array1, i))){
                    matched = false;
                    break
                };
                i = i+1;
            };
            matched
        }
    }

    public fun getModifiedProtocols(config: &Config): vector<String> {
        assert!(config.proposedProtocolToRemove != string::utf8(b""), NoProposalForRemovalExists);

        let mut modifiedProtocols = vector::empty<String>();
        let sourceLen = vector::length(&config.sources);
        let mut i = 0;
        while(i < sourceLen) {
            let protocol = *vector::borrow(&config.sources, i);
            if(config.proposedProtocolToRemove != protocol){
                vector::push_back(&mut modifiedProtocols, protocol);
            };
            i = i+1;
        };
        modifiedProtocols
    }

    #[test_only]
    public fun shareConfig(iconGovernance: String, admin: address, sources: vector<String>, destinations: vector<String>, proposedProtocolToRemove: String, ctx: &mut TxContext  ) {
         transfer::share_object(Config {
            id: object::new(ctx),
            iconGovernance: iconGovernance,
            admin: admin,
            sources: sources,
            destinations: destinations,
            proposedProtocolToRemove: proposedProtocolToRemove
        });
    }

    #[test]
    fun test_config() {
        use sui::test_scenario;

        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            configure(&adminCap, string::utf8(b"icon:hx734"), admin, sources, destinations,  test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            assert!(config.iconGovernance == string::utf8(b"icon:hx734"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_verify_protocols() {
        use sui::test_scenario;

        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            configure(&adminCap, string::utf8(b"icon:hx734"), admin, sources, destinations,  test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Act & Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let (verified) = verifyProtocols(&config, sources);
            assert!(verified, 1);
            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }


}