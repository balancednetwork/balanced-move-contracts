module balanced_crosschain::sicx_crosschain {
    use std::string::{String};
    use sui::coin::{Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::package::UpgradeCap;
    use xcall::xcall_state::{Storage as XCallState, IDCap};

    use balanced::xcall_manager::{Config as XcallManagerConfig};
    use balanced::balanced_utils::{ExecuteParams};
    use sicx::sicx::{SICX};
    use balanced_crosschain::balanced_crosschain::{Self,WitnessCarrier,Config};

    const CURRENT_VERSION: u64 = 1;

    public struct REGISTER_WITNESS has drop,store{}


    public struct AdminCap has key, store{
        id: UID 
    }

    
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());

       balanced_crosschain::transfer_witness(REGISTER_WITNESS{}, ctx);
    }

    public fun get_config_id(config: &Config<SICX>): ID{
         enforce_version(config);
        balanced_crosschain::get_config_id<SICX>(config)
    }

    entry fun configure(_: &AdminCap, treasury_cap: TreasuryCap<SICX>, xcall_manager_config: &XcallManagerConfig, storage: &XCallState, witness_carrier: WitnessCarrier<REGISTER_WITNESS>, icon_sicx: String, version: u64, ctx: &mut TxContext ){
        balanced_crosschain::configure<SICX,REGISTER_WITNESS>(treasury_cap,xcall_manager_config,storage,witness_carrier,icon_sicx,version,ctx);
    }

    public(package) fun get_idcap(config: &Config<SICX>): &IDCap {
         enforce_version(config);
       balanced_crosschain::get_idcap(config)
    }

    public fun get_xcall_manager_id(config: &Config<SICX>): ID{
         enforce_version(config);
        balanced_crosschain::get_xcall_manager_id(config)
    }

    public fun get_xcall_id(config: &Config<SICX>): ID{
         enforce_version(config);
        balanced_crosschain::get_xcall_id(config)
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

       balanced_crosschain::cross_transfer(config, xcall_state, xcall_manager_config, fee, token, to, data, ctx);
       
    }

    entry fun get_execute_call_params(config: &Config<SICX>): (ID, ID){
         enforce_version(config);
        balanced_crosschain::get_execute_call_params(config)
    }

    entry fun get_execute_params(config: &Config<SICX>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
        balanced_crosschain::get_execute_params(config,_msg)
    }

    entry fun get_rollback_params(config: &Config<SICX>, _msg:vector<u8>): ExecuteParams{
         enforce_version(config);
       balanced_crosschain::get_rollback_params(config, _msg)
    }

    entry fun execute_call(config: &mut Config<SICX>, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
       enforce_version(config);
       balanced_crosschain::execute_call(config, xcall_manager_config, xcall, fee, request_id, data, ctx);
       
    }

    //Called by admin when execute call fails without a rollback
    entry fun execute_force_rollback(config: &Config<SICX>, _: &AdminCap,  xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        enforce_version(config);
        balanced_crosschain::execute_force_rollback(config, xcall, fee, request_id, data, ctx);
    }

    entry fun execute_rollback(config: &mut Config<SICX>, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
        enforce_version(config);
        balanced_crosschain::execute_rollback(config, xcall, sn, ctx);
        
    }

    fun enforce_version(self: &Config<SICX>){
        balanced_crosschain::enforce_version(self, CURRENT_VERSION);
    }


    entry fun migrate(self: &mut Config<SICX>, _: &UpgradeCap) {
       balanced_crosschain::migrate(self, _, CURRENT_VERSION)
    }


     #[test_only]
    public fun get_treasury_cap_for_testing(config: &mut Config<SICX>): &mut TreasuryCap<SICX> {
        balanced_crosschain::get_treasury_cap_for_testing(config)
    }

}
