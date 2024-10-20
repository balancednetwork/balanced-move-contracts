module balanced::sicx_crosschain {
    use std::string::{String};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::math;
    use sui::package::UpgradeCap;

    use xcall::{main as xcall};
    use xcall::xcall_utils;
    use xcall::xcall_state::{Self, Storage as XCallState, IDCap};
    use xcall::envelope::{Self};
    use xcall::network_address::{Self};
    use xcall::execute_ticket::{Self};
    use xcall::rollback_ticket::{Self};

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::cross_transfer::{Self, wrap_cross_transfer, XCrossTransfer};
    use balanced::cross_transfer_revert::{Self, wrap_cross_transfer_revert, XCrossTransferRevert};
    use balanced::balanced_utils::{address_to_hex_string, address_from_hex_string, create_execute_params, ExecuteParams};
    use sicx::sicx::{Self, SICX};
    use balanced::crosschain_adapter::{Self,WitnessCarrier,Config};

    const EAmountLessThanMinimumAmount: u64 = 1;
    const UnknownMessageType: u64 = 4;
    const ENotUpgrade: u64 = 6;
    const EWrongVersion: u64 = 7;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";
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

    public fun get_config_id(config: &Config<SICX>): ID{
         enforce_version(config);
        crosschain_adapter::get_config_id<SICX>(config)
    }

    entry fun configure(_: &AdminCap, treasury_cap: TreasuryCap<SICX>, xcall_manager_config: &XcallManagerConfig, storage: &XCallState, witness_carrier: WitnessCarrier<REGISTER_WITNESS>, icon_sicx: String, version: u64, ctx: &mut TxContext ){
        crosschain_adapter::configure<SICX,REGISTER_WITNESS>(treasury_cap,xcall_manager_config,storage,witness_carrier,icon_sicx,version,ctx);
    }

    public(package) fun get_idcap(config: &Config<SICX>): &IDCap {
         enforce_version(config);
       crosschain_adapter::get_idcap(config)
    }

    public fun get_xcall_manager_id(config: &Config<SICX>): ID{
         enforce_version(config);
        crosschain_adapter::get_xcall_manager_id(config)
    }

    public fun get_xcall_id(config: &Config<SICX>): ID{
         enforce_version(config);
        crosschain_adapter::get_xcall_id(config)
    }

    entry fun cross_transfer(
        config: &mut Config<SICX>,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<SICX>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        enforce_version(config);

       crosschain_adapter::cross_transfer(config, xcall_state, xcall_manager_config, fee, token, to, data, ctx);
       
    }

    entry fun get_execute_call_params(config: &Config<SICX>): (ID, ID){
         enforce_version(config);
        crosschain_adapter::get_execute_call_params(config)
    }

    entry fun get_execute_params(config: &Config<SICX>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
        crosschain_adapter::get_execute_params(config,_msg)
    }

    entry fun get_rollback_params(config: &Config<SICX>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
       crosschain_adapter::get_rollback_params(config, _msg)
    }

    entry fun execute_call(config: &mut Config<SICX>, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
       enforce_version(config);
       crosschain_adapter::execute_call(config, xcall_manager_config, xcall, fee, request_id, data, ctx);
       
    }

    //Called by admin when execute call fails without a rollback
    entry fun execute_force_rollback(config: &Config<SICX>, _: &AdminCap,  xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        enforce_version(config);
        crosschain_adapter::execute_force_rollback(config, xcall, fee, request_id, data, ctx);
    }

    entry fun execute_rollback(config: &mut Config<SICX>, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
        enforce_version(config);
        crosschain_adapter::execute_rollback(config, xcall, sn, ctx);
        
    }

    fun enforce_version(self: &Config<SICX>){
        crosschain_adapter::enforce_version(self, CURRENT_VERSION);
    }


    entry fun migrate(self: &mut Config<SICX>, _: &UpgradeCap) {
       crosschain_adapter::migrate(self, _, CURRENT_VERSION)
    }


     #[test_only]
    public fun get_treasury_cap_for_testing(config: &mut Config<SICX>): &mut TreasuryCap<SICX> {
        crosschain_adapter::get_treasury_cap_for_testing(config)
    }

}
