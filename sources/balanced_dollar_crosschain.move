module balanced::balanced_dollar_crosschain {
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
    use balanced_dollar::balanced_dollar::{Self, BALANCED_DOLLAR};

    const EAmountLessThanMinimumAmount: u64 = 1;
    const UnknownMessageType: u64 = 4;
    const ENotUpgrade: u64 = 6;
    const EWrongVersion: u64 = 7;
    const EAmountNotEqualToIconAmount: u64 = 8;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";
    const CURRENT_VERSION: u64 = 4;
    const DIVISOR: u128 = 1000000000;

    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    public struct AdminCap has key, store{
        id: UID 
    }

    public struct Config has key, store{
        id: UID, 
        icon_bnusd: String,
        version: u64,
        id_cap: IDCap,
        xcall_manager_id: ID, 
        xcall_id: ID,
        balanced_treasury_cap: TreasuryCap<BALANCED_DOLLAR>
    }

    fun init(ctx: &mut TxContext) {
       
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());

        transfer::transfer(
            WitnessCarrier { id: object::new(ctx), witness:REGISTER_WITNESS{} },
            ctx.sender()
        );
        
    }

    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    public fun get_config_id(config: &Config): ID{
        enforce_version(config);
        config.id.to_inner()
    }

    entry fun configure(_: &AdminCap, treasury_cap: TreasuryCap<BALANCED_DOLLAR>, xcall_manager_config: &XcallManagerConfig, storage: &XCallState, witness_carrier: WitnessCarrier, icon_bnusd: String, version: u64, ctx: &mut TxContext ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        let xcall_manager_id = xcall_manager::get_id(xcall_manager_config);
        let xcall_id = xcall_state::get_id_cap_xcall(&id_cap);

        transfer::share_object(Config {
            id: object::new(ctx),
            icon_bnusd: icon_bnusd,
            version: version,
            id_cap: id_cap,
            xcall_manager_id: xcall_manager_id,
            xcall_id: xcall_id,
            balanced_treasury_cap: treasury_cap
        });
    }

    public(package) fun get_idcap(config: &Config): &IDCap {
        enforce_version(config);
        &config.id_cap
    }

    public fun get_xcall_manager_id(config: &Config): ID{
        config.xcall_manager_id
    }

    public fun get_xcall_id(config: &Config): ID{
        config.xcall_id
    }

    entry fun cross_transfer(
        config: &mut Config,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<BALANCED_DOLLAR>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        enforce_version(config);
        let messageData = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount>0, EAmountLessThanMinimumAmount);
        balanced_dollar::burn(get_treasury_cap_mut(config), token);
        let from = ctx.sender();

        let fromAddress = address_to_hex_string(&from);

        let xcallMessageStruct = wrap_cross_transfer(
            fromAddress,
            to,
            translate_outgoing_amount(amount),
            messageData
        );

        let rollbackStruct = wrap_cross_transfer_revert(
            from,
            amount
        );

        let (sources, destinations) = xcall_manager::get_protocals(xcall_manager_config);

        let xcallMessage = cross_transfer::encode(&xcallMessageStruct, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&rollbackStruct, CROSS_TRANSFER_REVERT);
        
        let envelope = envelope::wrap_call_message_rollback(xcallMessage, rollback, sources, destinations);
        xcall::send_call(xcall_state, fee, get_idcap(config), config.icon_bnusd, envelope::encode(&envelope), ctx);
    }

    entry fun cross_transfer_exact(
        config: &mut Config,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<BALANCED_DOLLAR>,
        icon_bnusd_amount: u128,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        enforce_version(config);
        let messageData = option::get_with_default(&data, b"");
        let (amount, cross_transfer_value) = if(icon_bnusd_amount > 0){
            let mut amount = (icon_bnusd_amount / DIVISOR) as u64;
            if(icon_bnusd_amount % DIVISOR > 0){
                amount = amount+1
            };
            assert!(amount == coin::value(&token), EAmountNotEqualToIconAmount);
            (amount, icon_bnusd_amount)
        }else{
            let amount = coin::value(&token);
            (amount, translate_outgoing_amount(amount))
        };

        assert!(amount>0, EAmountLessThanMinimumAmount);
        balanced_dollar::burn(get_treasury_cap_mut(config), token);
        let from = ctx.sender();

        let fromAddress = address_to_hex_string(&from);

        let xcallMessageStruct = wrap_cross_transfer(
            fromAddress,
            to,
            cross_transfer_value,
            messageData
        );

        let rollbackStruct = wrap_cross_transfer_revert(
            from,
            amount
        );

        let (sources, destinations) = xcall_manager::get_protocals(xcall_manager_config);

        let xcallMessage = cross_transfer::encode(&xcallMessageStruct, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&rollbackStruct, CROSS_TRANSFER_REVERT);
        
        let envelope = envelope::wrap_call_message_rollback(xcallMessage, rollback, sources, destinations);
        xcall::send_call(xcall_state, fee, get_idcap(config), config.icon_bnusd, envelope::encode(&envelope), ctx);
    }

    entry fun get_execute_call_params(config: &Config): (ID, ID){
        (get_xcall_manager_id(config), get_xcall_id(config))
    }

    entry fun get_execute_params(config: &Config, _msg:vector<u8>): ExecuteParams{
        let type_args:vector<String> = vector::empty();

        let mut result:vector<String> = vector::empty();
        result.push_back(xcall_utils::id_to_hex_string(&get_config_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_manager_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_id(config)));
        result.push_back(b"coin".to_string());  
        result.push_back(b"request_id".to_string());
        result.push_back(b"data".to_string());        
        create_execute_params(type_args, result)
    }

    entry fun get_rollback_params(config: &Config, _msg:vector<u8>): ExecuteParams{
        let type_args:vector<String> = vector::empty();

        let mut result:vector<String> = vector::empty();
        result.push_back(xcall_utils::id_to_hex_string(&get_config_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_id(config)));
        result.push_back(b"sn".to_string());        
        create_execute_params(type_args, result)
    }

    entry fun execute_call(config: &mut Config, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        enforce_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = xcall_manager::verify_protocols(xcall_manager_config, &protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if (verified && method == CROSS_TRANSFER && from == network_address::from_string(config.icon_bnusd)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to = network_address::addr(&network_address::from_string(string_to));
            let amount: u64 = translate_incoming_amount(cross_transfer::value(&message));

            balanced_dollar::mint(get_treasury_cap_mut(config), address_from_hex_string(&to),  amount, ctx);
            xcall::execute_call_result(xcall,ticket,true,fee,ctx);
        } else{
            xcall::execute_call_result(xcall,ticket,false,fee,ctx);
        }
    }

    //Called by admin when execute call fails without a rollback
    entry fun execute_force_rollback(config: &Config, _: &AdminCap,  xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        enforce_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

    entry fun execute_rollback(config: &mut Config, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
        enforce_version(config);
        let ticket = xcall::execute_rollback(xcall, get_idcap(config), sn, ctx);
        let msg = rollback_ticket::rollback(&ticket);
        let method: vector<u8> = cross_transfer::get_method(&msg);
        assert!(
            method == CROSS_TRANSFER_REVERT,
            UnknownMessageType
        );

        let message: XCrossTransferRevert = cross_transfer_revert::decode(&msg);
        let to = cross_transfer_revert::to(&message);
        let amount: u64 = cross_transfer_revert::value(&message);
        balanced_dollar::mint(get_treasury_cap_mut(config), to, amount,  ctx);
        xcall::execute_rollback_result(xcall,ticket,true)
    }

    entry fun set_icon_bnusd(config: &mut Config, _: &AdminCap, icon_bnusd: String ){
        enforce_version(config);
        config.icon_bnusd = icon_bnusd
    }
    
    fun get_treasury_cap_mut(config: &mut Config): &mut TreasuryCap<BALANCED_DOLLAR>{
        &mut config.balanced_treasury_cap
    }

    fun set_version(config: &mut Config, version: u64 ){
        config.version = version
    }

    public fun get_version(config: &mut Config): u64{
        config.version
    }

    fun enforce_version(self: &Config){
        assert!(self.version==CURRENT_VERSION, EWrongVersion);
    }

    entry fun migrate(self: &mut Config, _: &UpgradeCap) {
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }
    
    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = math::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

    fun translate_incoming_amount(amount: u128): u64 {
        (amount / ( math::pow(10, 9) as u128 ) ) as u64
    }

     #[test_only]
    public fun get_treasury_cap_for_testing(config: &mut Config): &mut TreasuryCap<BALANCED_DOLLAR> {
        &mut config.balanced_treasury_cap
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(ctx)
    }

}
