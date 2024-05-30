module balanced::balanced_dollar {
    use std::string::{String};
    use sui::url;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::math;

    use xcall::{main as xcall};
    use xcall::xcall_state::{Storage as XCallState, IDCap};
    use xcall::envelope::{Self};
    use xcall::network_address::{Self};
    use xcall::execute_ticket::{Self};
    use xcall::rollback_ticket::{Self};

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::cross_transfer::{Self, wrap_cross_transfer, XCrossTransfer};
    use balanced::cross_transfer_revert::{Self, wrap_cross_transfer_revert, XCrossTransferRevert};
    use balanced::balanced_utils::{address_to_hex_string, address_from_hex_string};

    const AmountLessThanMinimumAmount: u64  = 1;
    const ProtocolMismatch: u64 = 2;
    const OnlyICONBnUSD: u64 = 3;
    const UnknownMessageType: u64 = 4;
    const ENotTransferredAmount: u64 = 5;
    const ENotUpgrade: u64 = 6;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";
    const CURRENT_VERSION: u64 = 1;


    public struct BALANCED_DOLLAR has drop {}

    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    public struct AdminCap has key{
        id: UID 
    }
    
    public struct TreasuryCapCarrier<phantom BALANCED_DOLLAR> has key{
        id: UID,
        treasury_cap: TreasuryCap<BALANCED_DOLLAR>
    }

    public struct Config has key, store{
        id: UID, 
        icon_bnusd: String,
        version: u64,
        id_cap: IDCap
    }

    fun init(witness: BALANCED_DOLLAR, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BALANCED_DOLLAR>(
            witness, 
            9, 
            b"bnUSD", 
            b"Balanced Dollar", 
            b"A stable coin issued by Balanced", 
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/balancednetwork/assets/master/blockchains/icon/assets/cx88fd7df7ddff82f7cc735c871dc519838cb235bb/logo.png")),
            ctx
        );

        transfer::share_object(TreasuryCapCarrier{
            id: object::new(ctx),
            treasury_cap: treasury_cap
        });
        
        transfer::public_freeze_object(metadata);

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

    entry fun configure(_: &AdminCap, xcall_state: &XCallState, witness_carrier: WitnessCarrier, icon_bnusd: String, version: u64, ctx: &mut TxContext ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(xcall_state, w, ctx);

        transfer::share_object(Config {
            id: object::new(ctx),
            icon_bnusd: icon_bnusd,
            version: version,
            id_cap: id_cap
        });
    }

    public fun get_idcap(config: &Config): &IDCap {
        &config.id_cap
    }

    entry fun cross_transfer(
        xcall_state: &mut XCallState,
        config: &Config,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<BALANCED_DOLLAR>,
        carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>,
        to: String,
        amount: u64,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let messageData = option::get_with_default(&data, b"");
        assert!(amount > 0, AmountLessThanMinimumAmount);
        assert!(coin::value(&token) == amount, ENotTransferredAmount);
        coin::burn(get_treasury_cap_mut(carrier), token);
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

    entry fun execute_call(carier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>, config: &Config, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee: Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = xcall_manager::verify_protocols(xcall_manager_config, &protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        let method: vector<u8> = cross_transfer::get_method(&msg);

        assert!(
            method == CROSS_TRANSFER, 
            UnknownMessageType
        );

        assert!(from == network_address::from_string(config.icon_bnusd), OnlyICONBnUSD);
        let message: XCrossTransfer = cross_transfer::decode(&msg);
        let string_to = network_address::addr(&network_address::from_string(cross_transfer::to(&message)));
        let to = address_from_hex_string(&string_to);
        let amount: u64 = translate_incoming_amount(cross_transfer::value(&message));

        coin::mint_and_transfer(get_treasury_cap_mut(carier),  amount, to, ctx);
        xcall::execute_call_result(xcall,ticket,true,fee,ctx);
    }

    entry fun execute_rollback(carier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>, config: &Config, xcall:&mut XCallState, sn: u128, ctx:&mut TxContext){
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
        coin::mint_and_transfer(get_treasury_cap_mut(carier),  amount, to, ctx);
        xcall::execute_rollback_result(xcall,ticket,true)
    }


    fun get_treasury_cap_mut(treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>): &mut TreasuryCap<BALANCED_DOLLAR> {
        &mut treasury_cap_carrier.treasury_cap
    }

    entry fun set_icon_bnusd(_: &AdminCap, config: &mut Config, icon_bnusd: String ){
        config.icon_bnusd = icon_bnusd
    }

    fun set_version(config: &mut Config, version: u64 ){
        config.version = version
    }

    public fun get_version(config: &mut Config): u64{
        config.version
    }

    entry fun migrate(_: &AdminCap, self: &mut Config) {
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
    public fun get_treasury_cap_for_testing<BALANCED_DOLLAR>(treasury_cap_carrier: &mut TreasuryCapCarrier<BALANCED_DOLLAR>): &mut TreasuryCap<BALANCED_DOLLAR> {
        &mut treasury_cap_carrier.treasury_cap
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun init_test(ctx: &mut TxContext) {
        init(BALANCED_DOLLAR {}, ctx)
    }

}
