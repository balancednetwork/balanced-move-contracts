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
    use sui::balance::{Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;

    use xcall::main as xcall;
    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};

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

    struct Config has key{
        id: UID, 
        xCallNetworkAddress: String,
        iconAssetManager: String
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

    struct AdminCap has key {
        id: UID, 
    }

    fun init(witness: ASSET_MANAGER,  ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        //main.register_dapp(witness);
    }

    entry fun configure(_: &AdminCap, _iconAssetManager: String, _xCallNetworkAddress: String, ctx: &mut TxContext ) {
        transfer::share_object(Config {
            id: object::new(ctx),
            iconAssetManager: _iconAssetManager,
            xCallNetworkAddress: _xCallNetworkAddress
        });
    }
    
    public entry fun deposit<T>(config: &Config, xcallManagerConfig: &XcallManagerConfig, value: Coin<SUI>, token: Coin<T>, amount: u64, to: Option<String>, data: Option<vector<u8>>, ctx: &mut TxContext) {
        let fromAddress = config.xCallNetworkAddress;
        string::append(&mut fromAddress, address::to_string(tx_context::sender(ctx)));
        let toAddress = option::get_with_default(&to, fromAddress);
        let messageData = option::get_with_default(&data, b"");
        
        assert!(amount >= 0, EAmountLessThanMinimumAmount);
        assert!(coin::value(&token) == amount, ENotDepositedAmount);
        transfer::share_object(AssetManager {
            id: object::new(ctx),
            balance: coin::into_balance(token)
        });
        let tokenNetworkAddress = config.xCallNetworkAddress;
        string::append(&mut tokenNetworkAddress, string::utf8(b"")); //get token address
        let depositMessage = Deposit {
            tokenAddress: tokenNetworkAddress,
            from: fromAddress,
            to: toAddress,
            amount: amount,
            data: messageData
        };
        let rollbackMessage = DepositRevert {
            tokenAddress: tokenNetworkAddress,
            amount: amount,
            to: toAddress
        };
       let(sources, destinations) = xcall_manager::getProtocals(xcallManagerConfig); 
        sendCallMessage(value,  config.iconAssetManager, depositMessage, rollbackMessage, sources,  destinations, ctx ); //todo: should be xcal method call
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

    public fun handleCallMessage<T>(self: &mut AssetManager<T>,  xcallManagerConfig: &XcallManagerConfig, from: String, data: vector<u8>, protocols: vector<String>, ctx: &mut TxContext){
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

    #[test]
    fun test_config() {
        use sui::test_scenario;

        // Arrange
        let admin = @0xBABE;
        let witness = ASSET_MANAGER{};

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(witness, test_scenario::ctx(scenario));
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            
            configure(&adminCap, string::utf8(b"icon:hx734"), string::utf8(b"address"), test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            assert!(config.iconAssetManager == string::utf8(b"icon:hx734"), 1);
            assert!(config.xCallNetworkAddress == string::utf8(b"address"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit() {
        use sui::test_scenario;
        use balanced::balanced_dollar::BALANCED_DOLLAR;

        // Arrange
        let admin = @0xBABE;
        let witness = ASSET_MANAGER{};

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {  init(witness, test_scenario::ctx(scenario)); };
        
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            configure(&adminCap, string::utf8(b"icon:hx734"), string::utf8(b"address"), test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, adminCap);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            xcall_manager::shareConfig(
                 string::utf8(b"iconGovernance"),
                 admin,
                 sources,
                 destinations,
                 string::utf8(b""),
                 test_scenario::ctx(scenario)
            );
        };

        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            let xcallManagerConfig: xcall_manager::Config  = test_scenario::take_shared<xcall_manager::Config>(scenario);
            let fee_amount = math::pow(10, 9 + 4);
            let bnusd_amount = math::pow(10, 18);
            let fee = coin::mint_for_testing<SUI>(fee_amount, test_scenario::ctx(scenario));
            let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, test_scenario::ctx(scenario));
          
            
            deposit(&config, &xcallManagerConfig, fee, deposited, bnusd_amount, option::none(), option::none(), test_scenario::ctx(scenario));
            test_scenario::return_shared(config);
            test_scenario::return_shared(xcallManagerConfig);
        };

        test_scenario::end(scenario_val);

     }




}

