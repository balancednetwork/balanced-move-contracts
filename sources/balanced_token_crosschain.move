module balanced::balanced_token_crosschain {
    use std::string::{String};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::package::UpgradeCap;
    use xcall::xcall_state::{Self, Storage as XCallState, IDCap};

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::balanced_utils::{ExecuteParams};
    use balanced_token::balanced_token::{BALANCED_TOKEN};
    use balanced::crosschain_adapter::{Self,WitnessCarrier,Config};


    const EWrongVersion: u64 = 7;
    const CURRENT_VERSION: u64 = 1;

    public struct REGISTER_WITNESS has drop, store {}


    public struct AdminCap has key, store{
        id: UID 
    }

    

    //This function is equivalent to init, but since this module is added after package publish, need to create this, NEED TO CALL ONLY ONCE
    entry fun initialize(_: &UpgradeCap, ctx: &mut TxContext) {
        assert!(CURRENT_VERSION==1, EWrongVersion);
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());

       crosschain_adapter::transfer_witness(REGISTER_WITNESS{}, ctx);
    }

    public fun get_config_id(config: &Config<BALANCED_TOKEN>): ID{
         enforce_version(config);
        crosschain_adapter::get_config_id<BALANCED_TOKEN>(config)
    }

    entry fun configure(_: &AdminCap, treasury_cap: TreasuryCap<BALANCED_TOKEN>, xcall_manager_config: &XcallManagerConfig, storage: &XCallState, witness_carrier: WitnessCarrier<REGISTER_WITNESS>, icon_BALANCED_TOKEN: String, version: u64, ctx: &mut TxContext ){
        crosschain_adapter::configure<BALANCED_TOKEN,REGISTER_WITNESS>(treasury_cap,xcall_manager_config,storage,witness_carrier,icon_BALANCED_TOKEN,version,ctx);
    }

    public(package) fun get_idcap(config: &Config<BALANCED_TOKEN>): &IDCap {
         enforce_version(config);
       crosschain_adapter::get_idcap(config)
    }

    public fun get_xcall_manager_id(config: &Config<BALANCED_TOKEN>): ID{
         enforce_version(config);
        crosschain_adapter::get_xcall_manager_id(config)
    }

    public fun get_xcall_id(config: &Config<BALANCED_TOKEN>): ID{
         enforce_version(config);
        crosschain_adapter::get_xcall_id(config)
    }

    entry fun cross_transfer(
        config: &mut Config<BALANCED_TOKEN>,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<BALANCED_TOKEN>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        enforce_version(config);

       crosschain_adapter::cross_transfer(config, xcall_state, xcall_manager_config, fee, token, to, data, ctx);
       
    }

    entry fun get_execute_call_params(config: &Config<BALANCED_TOKEN>): (ID, ID){
         enforce_version(config);
        crosschain_adapter::get_execute_call_params(config)
    }

    entry fun get_execute_params(config: &Config<BALANCED_TOKEN>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
        crosschain_adapter::get_execute_params(config,_msg)
    }

    entry fun get_rollback_params(config: &Config<BALANCED_TOKEN>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
       crosschain_adapter::get_rollback_params(config, _msg)
    }

    entry fun execute_call(config: &mut Config<BALANCED_TOKEN>, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
       enforce_version(config);
       crosschain_adapter::execute_call(config, xcall_manager_config, xcall, fee, request_id, data, ctx);
       
    }

    //Called by admin when execute call fails without a rollback
    entry fun execute_force_rollback(config: &Config<BALANCED_TOKEN>, _: &AdminCap,  xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        enforce_version(config);
        crosschain_adapter::execute_force_rollback(config, xcall, fee, request_id, data, ctx);
    }

    entry fun execute_rollback(config: &mut Config<BALANCED_TOKEN>, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
        enforce_version(config);
        crosschain_adapter::execute_rollback(config, xcall, sn, ctx);
        
    }

    fun enforce_version(self: &Config<BALANCED_TOKEN>){
        crosschain_adapter::enforce_version(self, CURRENT_VERSION);
    }


    entry fun migrate(self: &mut Config<BALANCED_TOKEN>, _: &UpgradeCap) {
       crosschain_adapter::migrate(self, _, CURRENT_VERSION)
    }


     #[test_only]
    public fun get_treasury_cap_for_testing(config: &mut Config<BALANCED_TOKEN>): &mut TreasuryCap<BALANCED_TOKEN> {
        crosschain_adapter::get_treasury_cap_for_testing(config)
    }

}
