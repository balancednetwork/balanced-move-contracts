#[allow(unused_const)]
module balanced::asset_manager{
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::debug;
    use std::vector;
    
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;
    use sui::clock::{Self, Clock};

    use xcall::{main as xcall};
    use xcall::xcall_state::{IDCap, Storage};
    use xcall::envelope::{Self,XCallEnvelope};
    use xcall::network_address::{Self, NetworkAddress};

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR};
    use balanced::deposit::{Self, Deposit};
    use balanced::deposit_revert::{Self, DepositRevert};
    use balanced::withdraw_to::{Self, WithdrawTo};


    const WITHDRAW_TO_NAME: vector<u8> = b"widraw";
    const WITHDRAW_NATIVE_TO_NAME: vector<u8> = b"widraw_native";
    const DEPOSIT_REVERT_NAME: vector<u8> = b"deposit_revert";
    const POINTS: u64 = 1000;

    const EAmountLessThanMinimumAmount: u64 = 0;
    const ENotDepositedAmount: u64 = 1;
    const EWithdrawTooLarge: u64 = 2;
    const ProtocolMismatch: u64 = 3;
    const UnknownMessageType: u64 = 4;
    const EZeroAmountRequired: u64 = 5;
    const EExceedsWithdrawLimit: u64 = 6;

    public struct ASSET_MANAGER has drop {}
    
    public struct AssetManager<phantom T> has key, store{
        id: UID,
        balance: Balance<T>
    }

    public struct Config has key{
        id: UID, 
        xCallNetworkAddress: String,
        iconAssetManager: String
    }

    public struct RateLimit<phantom T> has key {
        id: UID,
        period: u64,
        percentage: u64,
        lastUpdate: u64,
        currentLimit: u64
    }

    public struct AdminCap has key {
        id: UID, 
    }

    fun init(_witness:ASSET_MANAGER, ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

    }

    public fun register_dapp(_: &AdminCap, witness: ASSET_MANAGER, storage: &Storage, ctx: &mut TxContext){
       let idCap =   xcall::register_dapp(storage, witness, ctx);
       transfer::public_transfer(idCap, tx_context::sender(ctx));
    }

    entry fun configure(_: &AdminCap, _iconAssetManager: String, _xCallNetworkAddress: String, ctx: &mut TxContext ) {
        transfer::share_object(Config {
            id: object::new(ctx),
            iconAssetManager: _iconAssetManager,
            xCallNetworkAddress: _xCallNetworkAddress
        });
    }

    entry fun register_token<T>(token: Coin<T>, ctx: &mut TxContext ) {
       assert!(coin::value(&token)==0, EZeroAmountRequired);
       let mut assetManager = AssetManager<T> {
            id: object::new(ctx),
            balance: balance::zero<T>()
        };
        coin::put<T>(&mut assetManager.balance, token);
        transfer::share_object(assetManager);
    }

    entry fun configure_rate_limit<T: key+store> (
        _: &AdminCap,
        self: &AssetManager<T>,
        c: &Clock,
        period: u64,
        percentage: u64,
        ctx: &mut TxContext
    ) {
        transfer::share_object(RateLimit<T> {
            id: object::new(ctx),
            period: period,
            percentage: percentage,
            lastUpdate: clock::timestamp_ms(c),
            currentLimit: (balance::value(&self.balance) * percentage) / POINTS
        });
    }

    entry fun reset_limit<T> (
        _: &AdminCap,
        self: &AssetManager<T>,
        rateLimit: &mut RateLimit<T>
    ) 
    {
        rateLimit.currentLimit = (balance::value(&self.balance) *rateLimit.percentage) / POINTS
    }

    public fun get_withdraw_limit<T>(self: &AssetManager<T>,
        rateLimit: &mut RateLimit<T>, c: &Clock, ctx: &mut TxContext): u64  {
        let tokenBalance = balance::value(&self.balance);
        calculate_limit(tokenBalance, rateLimit, c)
    }

    fun calculate_limit<T>(tokenBalance: u64, rateLimit: &mut RateLimit<T>, c: &Clock): u64 {
        let period = rateLimit.period;
        let percentage = rateLimit.percentage;
        if (period == 0) {
            return 0;
        };

        let maxLimit = (tokenBalance * percentage) / POINTS;
        let maxWithdraw = tokenBalance - maxLimit;
        let mut timeDiff = clock::timestamp_ms(c) - rateLimit.lastUpdate;
        timeDiff = if(timeDiff > period){ period } else { timeDiff };

        let addedAllowedWithdrawal = (maxWithdraw * timeDiff) / period;
        let mut limit = rateLimit.currentLimit - addedAllowedWithdrawal;
        limit = if(tokenBalance > limit){ limit } else { tokenBalance };
        limit = if(limit > maxLimit){ limit } else { maxLimit };
        limit
    }

    entry fun verify_withdraw<T>(self: &AssetManager<T>, rateLimit: &mut RateLimit<T>, c: &Clock, amount: u64) {
        let tokenBalance = balance::value(&self.balance);
        let limit = calculate_limit(tokenBalance, rateLimit, c);
        assert!(tokenBalance - amount >= limit, EExceedsWithdrawLimit );

        rateLimit.currentLimit = limit;
        rateLimit.lastUpdate = clock::timestamp_ms(c);
    }

    public entry fun deposit<T>(self: &mut AssetManager<T>, storage: &mut Storage, idCap: &IDCap, config: &Config, xcallManagerConfig: &XcallManagerConfig, fee: Coin<SUI>, token: Coin<T>, amount: u64, to: Option<String>, data: Option<vector<u8>>, ctx: &mut TxContext) {
        let sender = address::to_string(tx_context::sender(ctx));
        let fromAddress = network_address::to_string(&network_address::create(config.xCallNetworkAddress, sender));
        let toAddress = network_address::to_string(&network_address::create(config.xCallNetworkAddress, option::get_with_default(&to, fromAddress)));
        let messageData = option::get_with_default(&data, b"");
        
        assert!(amount >= 0, EAmountLessThanMinimumAmount);
        assert!(coin::value(&token) == amount, ENotDepositedAmount);
        coin::put<T>(&mut self.balance, token);

        let mut tokenNetworkAddress = config.xCallNetworkAddress;
        string::append(&mut tokenNetworkAddress, string::utf8(b"")); //get token address

        let depositMessage = deposit::wrap_deposit(
            tokenNetworkAddress,
            fromAddress,
            toAddress,
            amount,
            messageData
        );
        let data = deposit::encode(&depositMessage);

        let rollbackMessage = deposit_revert::wrap_deposit_revert (
            tokenNetworkAddress,
            sender,
            amount
        );
        let rollback = deposit_revert::encode(&rollbackMessage);

       let(sources, destinations) = xcall_manager::getProtocals(xcallManagerConfig); 
       let envelope = envelope::wrap_call_message_rollback(data, rollback, sources, destinations);
        xcall::send_call(storage, fee, idCap, config.iconAssetManager, envelope::encode(&envelope), ctx);
    }

    public fun handle_call_message<T>(self: &mut AssetManager<T>,  xcallManagerConfig: &XcallManagerConfig, from: String, data: vector<u8>, protocols: vector<String>, ctx: &mut TxContext){
        let verified = xcall_manager::verifyProtocols(xcallManagerConfig, protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        //string memory method = data.getMethod();
        let method = WITHDRAW_TO_NAME;
        assert!(
            method == WITHDRAW_TO_NAME || method == WITHDRAW_NATIVE_TO_NAME || method == DEPOSIT_REVERT_NAME,
            UnknownMessageType
        );

        if (method == WITHDRAW_TO_NAME) {
            // require(from.compareTo(iconAssetManager), "onlyICONAssetManager");
            // Messages.WithdrawTo memory message = data.decodeWithdrawTo();
            // withdraw(
            //     message.tokenAddress.parseAddress("Invalid account"),
            //     message.to.parseAddress("Invalid account"),
            //     message.amount
            // );
        } else if (method == WITHDRAW_NATIVE_TO_NAME) {
            //revert("Withdraw to native is currently not supported");
        } else if (method == DEPOSIT_REVERT_NAME) {
            // require(from.compareTo(xCallNetworkAddress), "onlyCallService");
            // Messages.DepositRevert memory message = data.decodeDepositRevert();
            // withdraw(message.tokenAddress, message.to, message.amount);
        };
    }

    #[allow(unused_function)]
    fun withdraw<T>(self: &mut AssetManager<T>, to: address, amount: u64, ctx: &mut TxContext){
        assert!(amount>0, EAmountLessThanMinimumAmount);

        let token = coin::take(&mut self.balance, amount, ctx);
        transfer::public_transfer(token, to);
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(ASSET_MANAGER {}, ctx)
    }

}

