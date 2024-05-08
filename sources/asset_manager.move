module balanced::asset_manager{
    use std::string::{Self, String};
    use std::type_name::{Self};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::bag::{Self, Bag};

    use xcall::{main as xcall};
    use xcall::xcall_state::{Storage as XCallState};
    use xcall::envelope::{Self};
    use xcall::network_address::{Self};
    use xcall::execute_ticket::{Self};

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig, XcallCap};
    use balanced::deposit::{Self};
    use balanced::deposit_revert::{Self, DepositRevert};
    use balanced::withdraw_to::{Self, WithdrawTo};
    use balanced::balanced_utils::{address_to_hex_string, address_from_hex_string};

    const DEPOSIT_NAME: vector<u8> = b"Deposit";
    const WITHDRAW_TO_NAME: vector<u8> = b"WithdrawTo";
    const DEPOSIT_REVERT_NAME: vector<u8> = b"DepositRevert";
    const WITHDRAW_NATIVE_TO_NAME: vector<u8> = b"WithdrawNativeTo";

    const POINTS: u64 = 1000;

    const EAmountLessThanMinimumAmount: u64 = 0;
    const ENotDepositedAmount: u64 = 1;
    const ProtocolMismatch: u64 = 2;
    const UnknownMessageType: u64 = 3;
    const EZeroAmountRequired: u64 = 4;
    const EExceedsWithdrawLimit: u64 = 5;
    const EIconAssetManagerRequired: u64 = 6;
    
    public struct AssetManager<phantom T> has key, store{
        id: UID,
        balance: Balance<T>
    }

    public struct Config has key {
        id: UID, 
        xcall_network_address: String,
        icon_asset_manager: String,
        assets: Bag
    }
    

    public struct RateLimit<phantom T> has key {
        id: UID,
        period: u64,
        percentage: u64,
        last_update: u64,
        current_limit: u64
    }

    public struct AdminCap has key {
        id: UID, 
    }

    fun init(ctx: &mut TxContext) {

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, ctx.sender());

    }

    entry fun configure(_: &AdminCap, icon_asset_manager: String, xcall_network_address: String, ctx: &mut TxContext ) {
        transfer::share_object(Config {
            id: object::new(ctx),
            icon_asset_manager: icon_asset_manager,
            xcall_network_address: xcall_network_address,
            assets: bag::new(ctx)
        });
    }

    entry fun register_token<T>(token: Coin<T>, config:&mut Config,  ctx: &mut TxContext) {
       assert!(coin::value(&token)==0, EZeroAmountRequired);
       let mut asset_manager = AssetManager<T> {
            id: object::new(ctx),
            balance: balance::zero<T>()
        };
        coin::put<T>(&mut asset_manager.balance, token);
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<T>()));
        config.assets.add(token_type, asset_manager);
    }

    entry fun configure_rate_limit<T: key+store> (
        _: &AdminCap,
        config: &Config,
        c: &Clock,
        period: u64,
        percentage: u64,
        ctx: &mut TxContext
    ) {
        let asset_manager = get_asset_manager<T>(config);
        transfer::share_object(RateLimit<T> {
            id: object::new(ctx),
            period: period,
            percentage: percentage,
            last_update: clock::timestamp_ms(c),
            current_limit: (balance::value(&asset_manager.balance) * percentage) / POINTS
        });
    }

    entry fun reset_limit<T> (
        _: &AdminCap,
        config: &Config,
        rateLimit: &mut RateLimit<T>
    ) 
    {
        let asset_manager = get_asset_manager<T>(config);
        rateLimit.current_limit = (balance::value(&asset_manager.balance) *rateLimit.percentage) / POINTS
    }

    public fun get_withdraw_limit<T>(config: &Config,
        rateLimit: &RateLimit<T>, c: &Clock): u64  {
        let asset_manager = get_asset_manager<T>(config);

        let tokenBalance = balance::value(&asset_manager.balance);
        calculate_limit(tokenBalance, rateLimit, c)
    }

    fun calculate_limit<T>(tokenBalance: u64, rateLimit: &RateLimit<T>, c: &Clock): u64 {
        let period = rateLimit.period;
        let percentage = rateLimit.percentage;
        if (period == 0) {
            return 0
        };

        let maxLimit = (tokenBalance * percentage) / POINTS;
        let maxWithdraw = tokenBalance - maxLimit;
        let mut timeDiff = clock::timestamp_ms(c) - rateLimit.last_update;
        timeDiff = if(timeDiff > period){ period } else { timeDiff };

        let addedAllowedWithdrawal = (maxWithdraw * timeDiff) / period;
        let mut limit = rateLimit.current_limit - addedAllowedWithdrawal;
        limit = if(tokenBalance > limit){ limit } else { tokenBalance };
        limit = if(limit > maxLimit){ limit } else { maxLimit };
        limit
    }

    entry fun verify_withdraw<T>(config: &Config, rateLimit: &mut RateLimit<T>, c: &Clock, amount: u64) {
        let asset_manager = get_asset_manager<T>(config);

        let tokenBalance = balance::value(&asset_manager.balance);
        let limit = calculate_limit(tokenBalance, rateLimit, c);
        assert!(tokenBalance - amount >= limit, EExceedsWithdrawLimit );

        rateLimit.current_limit = limit;
        rateLimit.last_update = clock::timestamp_ms(c);
    }

    public entry fun deposit<T>(
        xcallState: &mut XCallState, 
        xcallCap: &XcallCap, 
        config: &mut Config, 
        xcallManagerConfig: &XcallManagerConfig, 
        fee: Coin<SUI>,
        token: Coin<T>, 
        amount: u64, 
        to: Option<address>, 
        data: Option<vector<u8>>, 
        ctx: &mut TxContext
    ) {
        
        let sender = tx_context::sender(ctx);
        let string_from = address_to_hex_string(&tx_context::sender(ctx));
        let from_address = network_address::to_string(&network_address::create(config.xcall_network_address, string_from));
        let mut to_address = from_address;
        if(option::is_some(&to)){
            let string_to = address_to_hex_string(option::borrow(&to));
            to_address = network_address::to_string(&network_address::create(config.xcall_network_address, string_to));
        };
        let messageData = option::get_with_default(&data, b"");
        let self = get_asset_manager_mut<T>(config);
        
        assert!(amount >= 0, EAmountLessThanMinimumAmount);
        assert!(coin::value(&token) == amount, ENotDepositedAmount);
        coin::put<T>(&mut self.balance, token);

        let token_address = string::from_ascii(type_name::get_address(&type_name::get<T>()));
        let depositMessage = deposit::wrap_deposit(
            token_address,
            from_address,
            to_address,
            amount,
            messageData
        );
        let data = deposit::encode(&depositMessage, DEPOSIT_NAME);

        
        let rollbackMessage = deposit_revert::wrap_deposit_revert (
            token_address,
            sender,
            amount
        );
        let rollback = deposit_revert::encode(&rollbackMessage, DEPOSIT_REVERT_NAME);

       let(sources, destinations) = xcall_manager::get_protocals(xcallManagerConfig); 
       let idcap = xcall_manager::get_idcap(xcallCap);
       let envelope = envelope::wrap_call_message_rollback(data, rollback, sources, destinations);
       xcall::send_call(xcallState, fee, idcap, config.icon_asset_manager, envelope::encode(&envelope), ctx);
    }

    public fun get_withdraw_token_type(msg:vector<u8>): String{
        deposit::get_token_type(&msg)
    }

    entry public fun execute_call<T>(xcall_cap: &XcallCap, config: &mut Config, xcall_manager_config: &XcallManagerConfig, xcall:&mut XCallState, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        let idcap = xcall_manager::get_idcap(xcall_cap);
        let ticket = xcall::execute_call(xcall, idcap, request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = xcall_manager::verify_protocols(xcall_manager_config, &protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        let method: vector<u8> = deposit::get_method(&msg);
        assert!(
            method == WITHDRAW_TO_NAME || method == WITHDRAW_NATIVE_TO_NAME || method == DEPOSIT_REVERT_NAME,
            UnknownMessageType
        );
        
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<T>()));
        
        let message_token_type = deposit::get_token_type(&msg);
        if(token_type == message_token_type){
            if (method == WITHDRAW_TO_NAME || method == WITHDRAW_NATIVE_TO_NAME) {
                assert!(from == network_address::from_string(config.icon_asset_manager), EIconAssetManagerRequired);
                let message: WithdrawTo = withdraw_to::decode(&msg);
                let to_address = network_address::addr(&network_address::from_string(withdraw_to::to(&message)));
                let self = get_asset_manager_mut<T>(config);
                withdraw(
                    self,
                    address_from_hex_string(&to_address),
                    withdraw_to::amount(&message),
                    ctx
                );
            } else if (method == DEPOSIT_REVERT_NAME) {
                let self = get_asset_manager_mut<T>(config);
                let message: DepositRevert = deposit_revert::decode(&msg);
                    withdraw(
                        self,
                        deposit_revert::to(&message),
                        deposit_revert::amount(&message),
                        ctx
                    );
                
            };
            xcall::execute_call_result(xcall,ticket,true,fee,ctx);
        }else{
            xcall::execute_call_result(xcall,ticket,false,fee,ctx);
        };
        
    }

    fun get_asset_manager_mut<T>(config: &mut Config): &mut AssetManager<T> {
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<T>()));
        let asset_manager = config.assets.borrow_mut<String, AssetManager<T>>(token_type);
        asset_manager
    }

    fun get_asset_manager<T>(config: &Config): &AssetManager<T> {
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<T>()));
        let asset_manager = config.assets.borrow<String, AssetManager<T>>(token_type);
        asset_manager
    }

    fun withdraw<T>(self: &mut AssetManager<T>, to: address, amount: u64, ctx: &mut TxContext){
        assert!(amount>0, EAmountLessThanMinimumAmount);

        let token = coin::take(&mut self.balance, amount, ctx);
        transfer::public_transfer(token, to);
    }

    #[test_only]
    public fun init_test(ctx: &mut TxContext) {
        init(ctx)
    }

}

