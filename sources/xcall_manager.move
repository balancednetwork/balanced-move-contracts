#[allow(unused_const)]
module balanced::xcall_manager{
    use std::string::{Self, String};

    use sui::coin::{Coin};
    use sui::sui::{SUI};

    use xcall::{main as xcall};
    use xcall::xcall_state::{IDCap, Storage as XCallState};
    use xcall::network_address::{Self};
    use xcall::execute_ticket::{Self};

    use balanced::configure_protocol::{Self, ConfigureProtocol};

    const NoProposalForRemovalExists: u64 = 0;
    const ProtocolMismatch: u64 = 1;
    const OnlyICONBalancedgovernanceIsAllowed: u64 = 2;
    const UnknownMessageType: u64 = 3;
    const EIconAssetManagerRequired: u64 = 4;

    const EXECUTE_METHOD_NAME: vector<u8> = b"Execute";
    const CONFIGURE_PROTOCOLS_NAME: vector<u8> = b"ConfigureProtocols";

    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    public struct Config has key, store {
        id: UID, 
        iconGovernance: String,
        admin: address,
        sources: vector<String>,
        destinations: vector<String>,
        proposedProtocolToRemove: String
    }

    public struct XcallCap has key {
        id: UID,
        idCap: IDCap
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

        transfer::transfer(
            WitnessCarrier { id: object::new(ctx), witness:REGISTER_WITNESS{} },
            ctx.sender()
        );
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

    public fun register_xcall(xcallState: &XCallState, witnessCarrier: WitnessCarrier, ctx: &mut TxContext){
       let w = get_witness(witnessCarrier);
       let idCap =   xcall::register_dapp(xcallState, w, ctx);
       transfer::share_object(XcallCap {id: object::new(ctx), idCap: idCap});
    }

    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    public(package) fun get_idcap(xcallIdCap: &XcallCap): &IDCap {
        &xcallIdCap.idCap
    }

    public fun get_protocals(config: &Config):(vector<String>, vector<String>){
        (config.sources, config.destinations)
    }

    entry fun propose_removal(_: &AdminCap, config: &mut Config, protocol: String) {
        config.proposedProtocolToRemove = protocol;
    }

    entry public fun execute_call(xcallCap: &XcallCap, config: &mut Config, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        let ticket = xcall::execute_call(xcall, &xcallCap.idCap, request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = Self::verify_protocols(config, &protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        let method: vector<u8> = configure_protocol::get_method(&msg);
        assert!(
            method == CONFIGURE_PROTOCOLS_NAME || method == EXECUTE_METHOD_NAME,
            UnknownMessageType
        );

        if (method == CONFIGURE_PROTOCOLS_NAME) {
            assert!(from == network_address::from_string(config.iconGovernance), EIconAssetManagerRequired);
            let message: ConfigureProtocol = configure_protocol::decode(&msg);
            config.sources = configure_protocol::sources(&message);
            config.destinations = configure_protocol::destinations(&message);
            xcall::execute_call_result(xcall,ticket,true,fee,ctx)
        } else {
            xcall::execute_call_result(xcall,ticket,false,fee,ctx)
        }
    }

    public fun verify_protocols(
       config: &Config, protocols: &vector<String>
    ): bool {
        verify_protocol_recovery(protocols, config)
    }

    fun verify_protocol_recovery(protocols: &vector<String>, config: &Config): bool {
        assert!(
            verify_protocols_unordered(&get_modified_protocols(config), protocols),
            ProtocolMismatch
        );
        true
    }

    fun verify_protocols_unordered(
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

    public fun get_modified_protocols(config: &Config): vector<String> {
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
    public fun init_test(ctx: &mut TxContext) {
        init(ctx)
    }

}