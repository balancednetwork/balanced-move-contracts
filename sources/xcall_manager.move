#[allow(unused_const)]
module balanced::xcall_manager{
    use std::string::{Self, String};
    use std::vector;

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    

    const CONFIGURE_PROTOCOLS_NAME: vector<u8> = b"ConfigureProtocols";
    const EXECUTE_NAME: vector<u8> = b"Execute";

    const NoProposalForRemovalExists: u64 = 0;
    const ProtocolMismatch: u64 = 1;
    const OnlyICONBalancedgovernanceIsAllowed: u64 = 2;

    struct XcallManagerVars has key, store{
        id: UID, 
        xCall: address,
        iconGovernance: String,
        admin: address,
        sources: vector<String>,
        destinations: vector<String>,
        proposedProtocolToRemove: String
    }

    struct AdminCap has key{
        id: UID, 
    }

    struct CallServiceCap has key{
        id: UID, 
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    entry fun configure(_: &AdminCap, _iconGovernance: String, _xCall: address, _admin: address, _sources: vector<String>, _destinations: vector<String>, ctx: &mut TxContext ){
        transfer::share_object(XcallManagerVars{
            id: object::new(ctx),
            xCall: _xCall,
            iconGovernance: _iconGovernance,
            admin: _admin,
            sources: _sources,
            destinations: _destinations,
            proposedProtocolToRemove: string::utf8(b"")
        });
        transfer::transfer(CallServiceCap{
            id: object::new(ctx)
        }, _xCall);
    }

    public fun getProtocals(self: &XcallManagerVars):(vector<String>, vector<String>){
        (self.sources, self.destinations)
    }

    entry fun proposeRemoval(_: &AdminCap, vars: &mut XcallManagerVars, protocol: String) {
        vars.proposedProtocolToRemove = protocol;
    }

    public fun handleCallMessage(
        vars: &XcallManagerVars,
        from: String,
        data: vector<vector<u8>>,
        protocols: vector<String>,
    
    )  {
        assert!(
            from == vars.iconGovernance,
            OnlyICONBalancedgovernanceIsAllowed
        );
        
        //string memory method = data.getMethod();
        let method = CONFIGURE_PROTOCOLS_NAME; //read methdo from data

        if (!verifyProtocolsUnordered(&protocols, &vars.sources)) {
            assert!(
                method == CONFIGURE_PROTOCOLS_NAME,
                ProtocolMismatch
            );
            verifyProtocolRecovery(protocols, vars);
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
       vars: &XcallManagerVars, protocols: vector<String>
    ): bool {
         verifyProtocolsUnordered(&protocols, &vars.sources)
    }

    fun verifyProtocolRecovery(protocols: vector<String>, vars: &XcallManagerVars) {
        assert!(
            verifyProtocolsUnordered(&getModifiedProtocols(vars), &protocols),
            ProtocolMismatch
        );
    }

    public fun verifyProtocolsUnordered(
        array1: &vector<String>,
        array2: &vector<String>
    ):bool {
        let len1 = vector::length(array1);
        if(len1!=vector::length(array2)){
            false
        }else{
            let match = true;
            let i = 0;
            while(i < len1){
                if(!vector::contains(array2, vector::borrow(array1, i))){
                    match = false;
                    break
                };
                i = i+1;
            };
            match
        }
    }

    public fun getModifiedProtocols(vars: &XcallManagerVars): vector<String> {
        assert!(vars.proposedProtocolToRemove != string::utf8(b""), NoProposalForRemovalExists);

        let v = vector::empty<String>();
        let sourceLen = vector::length(&vars.sources);
        let i = 0;
        while(i < sourceLen) {
            let protocol = *vector::borrow(&vars.sources, i);
            if(vars.proposedProtocolToRemove != protocol){
                vector::push_back(&mut v, protocol);
            };
            i = i+1;
        };
        v
    }

     #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }


}