module balanced_crosschain::balanced_crosschain{
    use std::string::{String};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
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

    const EAmountLessThanMinimumAmount: u64 = 1;
    const UnknownMessageType: u64 = 4;
    const ENotUpgrade: u64 = 6;
    const EWrongVersion: u64 = 7;
    const EAmountNotEqualToIconAmount: u64 = 9;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";
    const DIVISOR: u128 = 1000000000;

    public struct WitnessCarrier<T:drop> has key { 
        id: UID, 
        witness: T
    }

    public(package) fun transfer_witness<T:drop+store>(witness:T,ctx:&mut TxContext){
        
        transfer::transfer(
            WitnessCarrier { id:object::new(ctx), witness},
            ctx.sender()
        );

    }

    public struct Config<phantom T> has key, store{
        id: UID, 
        icon_token_address: String,
        version: u64,
        id_cap: IDCap,
        xcall_manager_id: ID, 
        xcall_id: ID,
        balanced_treasury_cap: TreasuryCap<T>
    }

    

    fun get_witness<W:store+drop>(carrier: WitnessCarrier<W>): W {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    public(package) fun get_config_id<T>(config: &Config<T>): ID{
        config.id.to_inner()
    }

    public(package) fun configure<T,W:store+drop>(treasury_cap: TreasuryCap<T>, xcall_manager_config: &XcallManagerConfig, storage: &XCallState, witness_carrier: WitnessCarrier<W>, icon_token_address: String, version: u64, ctx: &mut TxContext ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        let xcall_manager_id = xcall_manager::get_id(xcall_manager_config);
        let xcall_id = xcall_state::get_id_cap_xcall(&id_cap);

        transfer::share_object(Config<T> {
            id: object::new(ctx),
            icon_token_address: icon_token_address,
            version: version,
            id_cap: id_cap,
            xcall_manager_id: xcall_manager_id,
            xcall_id: xcall_id,
            balanced_treasury_cap: treasury_cap
        });
    }

    public(package) fun get_idcap<T>(config: &Config<T>): &IDCap {
    
        &config.id_cap
    }

    public(package) fun get_xcall_manager_id<T>(config: &Config<T>): ID{
        config.xcall_manager_id
    }

    public(package) fun get_xcall_id<T>(config: &Config<T>): ID{
        config.xcall_id
    }

    public(package) fun cross_transfer<T>(
        config: &mut Config<T>,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<T>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        
        let amount = coin::value(&token);
        let cross_transfer_value = translate_outgoing_amount(amount);
        cross_transfer_internal(config, xcall_state, xcall_manager_config, fee, token, cross_transfer_value, amount, to, data, ctx);
    }

    public(package) fun cross_transfer_exact<T>(
        config: &mut Config<T>,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<T>,
        icon_amount: u128,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        
        let (amount, cross_transfer_value) = if(icon_amount > 0){
            let mut amount = (icon_amount / DIVISOR) as u64;
            if(icon_amount % DIVISOR > 0){
                amount = amount+1
            };
            assert!(amount == coin::value(&token), EAmountNotEqualToIconAmount);
            (amount, icon_amount)
        }else{
            let amount = coin::value(&token);
            (amount, translate_outgoing_amount(amount))
        };
        cross_transfer_internal(config, xcall_state, xcall_manager_config, fee, token, cross_transfer_value, amount, to, data, ctx);
    }

    fun cross_transfer_internal<T>(
        config: &mut Config<T>,
        xcall_state: &mut XCallState,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<T>,
        cross_transfer_value: u128,
        amount: u64,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let messageData = option::get_with_default(&data, b"");
        assert!(amount>0, EAmountLessThanMinimumAmount);
        coin::burn(get_treasury_cap_mut(config),token);
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
        xcall::send_call(xcall_state, fee, get_idcap(config), config.icon_token_address, envelope::encode(&envelope), ctx);
    }
    

    public(package) fun get_execute_call_params<T>(config: &Config<T>): (ID, ID){
        (get_xcall_manager_id(config), get_xcall_id(config))
    }

    public(package) fun get_execute_params<T>(config: &Config<T>, _msg:vector<u8>): ExecuteParams{
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

    public(package) fun get_rollback_params<T>(config: &Config<T>, _msg:vector<u8>): ExecuteParams{
        let type_args:vector<String> = vector::empty();

        let mut result:vector<String> = vector::empty();
        result.push_back(xcall_utils::id_to_hex_string(&get_config_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_id(config)));
        result.push_back(b"sn".to_string());        
        create_execute_params(type_args, result)
    }

    public(package) fun execute_call<T>(config: &mut Config<T>, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = xcall_manager::verify_protocols(xcall_manager_config, &protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if (verified && method == CROSS_TRANSFER && from == network_address::from_string(config.icon_token_address)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to = network_address::addr(&network_address::from_string(string_to));
            let amount: u64 = translate_incoming_amount(cross_transfer::value(&message));
            coin::mint_and_transfer(get_treasury_cap_mut(config), amount, address_from_hex_string(&to), ctx);
            xcall::execute_call_result(xcall,ticket,true,fee,ctx);
            
        } else{
            xcall::execute_call_result(xcall,ticket,false,fee,ctx);
            
        }
    }

    //Called by admin when execute call fails without a rollback
    public(package) fun execute_force_rollback<T>(config: &Config<T>, xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

    public(package) fun execute_rollback<T>(config: &mut Config<T>, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
        
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
        coin::mint_and_transfer(get_treasury_cap_mut(config), amount, to, ctx);
        xcall::execute_rollback_result(xcall,ticket,true);
    }
    
    public(package) fun get_treasury_cap_mut<T>(config: &mut Config<T>): &mut TreasuryCap<T>{
        &mut config.balanced_treasury_cap
    }

    fun set_version<T>(config: &mut Config<T>, version: u64 ){
        config.version = version
    }

    public fun get_version<T>(config: &mut Config<T>): u64{
        config.version
    }

    public(package) fun enforce_version<T>(self: &Config<T>,version:u64){
        std::debug::print(&self.version);
        std::debug::print(&version);
        assert!(self.version==version, EWrongVersion);
    }

    public(package) fun migrate<T>(self: &mut Config<T>, _: &UpgradeCap,current_version:u64) {
        assert!(get_version(self) < current_version, ENotUpgrade);
        set_version(self, current_version);
    }
    
    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = std::u64::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

    fun translate_incoming_amount(amount: u128): u64 {
        (amount / ( std::u64::pow(10, 9) as u128 ) ) as u64
    }

    
    public(package) fun get_treasury_cap_for_testing<T>(config: &mut Config<T>): &mut TreasuryCap<T> {
        &mut config.balanced_treasury_cap
    }

}
