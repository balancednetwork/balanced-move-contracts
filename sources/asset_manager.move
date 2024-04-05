#[allow(unused_const)]
module balanced::asset_manager{
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::debug;
    
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::address::{Self};
    use sui::sui::SUI;

    use xcall::main::{Self};
    use balanced::xcall_manager::{Self, XcallManagerVars};

    const WITHDRAW_TO_NAME: vector<u8> = b"widraw";
    const WITHDRAW_NATIVE_TO_NAME: vector<u8> = b"widraw_native";
    const DEPOSIT_REVERT_NAME: vector<u8> = b"deposit_revert";

    const EAmountLessThanMinimumAmount: u64 = 0;
    const ENotDepositedAmount: u64 = 1;
    const EWithdrawTooLarge: u64 = 2;
    const ProtocolMismatch: u64 = 3;
    const UnknownMessageType: u64 = 4;

    struct ASSET_MANAGER has drop {}
    
    struct AssetManager<phantom T> has key {
        id: UID,
        balance: Balance<T>
    }

    struct AssetManagerVars has key, store{
        id: UID, 
        xCall: address,
        xCallNetworkAddress: String,
        iconAssetManager: String,
        xCallManager: address
    }

    struct Deposit has drop {
        tokenAddress: String,
        from: String,
        to: String,
        amount: u64,
        data: vector<u8>
    }

    struct DepositRevert has drop {
        tokenAddress: String,
        to: String,
        amount: u64
    }

    struct WithdrawTo has key {
        id: UID,
        tokenAddress: String,
        to: String,
        amount: u64
    }

    struct AdminCap has key{
        id: UID, 
    }

    struct CallServiceCap has key{
        id: UID, 
    }

    fun init(witness: ASSET_MANAGER,  ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        //main.register_dapp(witness);
    }

    entry fun configure(_: &AdminCap, _iconAssetManager: String, _xCall: address, _xCallManager: address, _xCallNetworkAddress: String, ctx: &mut TxContext ){
        transfer::share_object(AssetManagerVars{
            id: object::new(ctx),
            xCall: _xCall,
            iconAssetManager: _iconAssetManager,
            xCallManager: _xCallManager,
            xCallNetworkAddress: _xCallNetworkAddress
        });
        transfer::transfer(CallServiceCap{
            id: object::new(ctx)
        }, _xCall);

    }
    
    public entry fun deposit<T>(self: &mut AssetManager<T>, vars: &mut AssetManagerVars, xcallManagerVars: &XcallManagerVars, value: Coin<SUI>, token: Coin<T>, amount: u64, to: Option<String>, data: Option<vector<u8>>, ctx: &mut TxContext){
        let fromAddress = vars.xCallNetworkAddress;
        string::append(&mut fromAddress, address::to_string(tx_context::sender(ctx)));
        let toAddress = option::get_with_default(&to, fromAddress);
        let messageData = option::get_with_default(&data, b"");
        
        assert!(amount >= 0, EAmountLessThanMinimumAmount);
        assert!(coin::value(&token) == amount, ENotDepositedAmount);
        coin::put(&mut self.balance, token);
        let tokenNetworkAddress = vars.xCallNetworkAddress;
        string::append(&mut tokenNetworkAddress, string::utf8(b"")); //get token address
        let depositMessage = Deposit{
            tokenAddress: tokenNetworkAddress,
            from: fromAddress,
            to: toAddress,
            amount: amount,
            data: messageData
        };
        let rollbackMessage = DepositRevert{
            tokenAddress: tokenNetworkAddress,
            amount: amount,
            to: toAddress
        };
       let(sources, destinations) = xcall_manager::getProtocals(xcallManagerVars); 
        sendCallMessage(value,  vars.iconAssetManager, depositMessage, rollbackMessage, sources,  destinations, ctx ); //todo: should be xcal method call
    }

    //todo: remove this method once xcall integrated
    public fun sendCallMessage(coin: Coin<SUI>,  iconAssetManager: String, depositMessage: Deposit, rollbackMessage: DepositRevert, sources: vector<String>, destinations: vector<String>, ctx: &mut TxContext){
        debug::print(&iconAssetManager);
        debug::print(&depositMessage);
        debug::print(&rollbackMessage);
        debug::print(&sources);
        debug::print(&destinations);

        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    public fun handleCallMessage<T>(self: &mut AssetManager<T>,  xcallManagerVars: &XcallManagerVars, from: String, data: vector<u8>, protocols: vector<String>, ctx: &mut TxContext){
        let verified = xcall_manager::verifyProtocols(xcallManagerVars, protocols);
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
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

}

