module balanced::balanced_dollar {
    use sui::object::{Self, UID};
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::debug;

    use sui::url;
    use sui::transfer;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;
    use sui::address::{Self};
    use sui::balance::{Self};
    use xcall::main::{Self};
    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";

    const AmountLessThanMinimumAmount: u64  = 1;
    const ProtocolMismatch: u64 = 2;
    const OnlyICONBnUSD: u64 = 3;
    const OnlyCallService: u64 = 4;
    const UnknownMessageType: u64 = 5;
    const ENotTransferredAmount: u64 = 6;

    struct BALANCED_DOLLAR has drop {}

    struct AdminCap has key{
        id: UID 
    }

    struct XCrossTransfer has drop{
        from: String, 
        to: String,
        value: u64,
        data: vector<u8>
    }

    struct XCrossTransferRevert has drop{
        to: String,
        value: u64
    }

    struct Config has key, store{
        id: UID, 
        xCallNetworkAddress: String,
        nid: String,
        iconBnUSD: String,
    }

    fun init(witness: BALANCED_DOLLAR, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BALANCED_DOLLAR>(
            witness, 
            18, 
            b"bnUSD", 
            b"Balanced Dollar", 
            b"A stable coin issued by Balanced", 
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/balancednetwork/assets/master/blockchains/icon/assets/cx88fd7df7ddff82f7cc735c871dc519838cb235bb/logo.png")),
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        
        transfer::public_share_object(metadata);

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    entry fun configure(_: &AdminCap, _xCallNetworkAddress: String, _nid: String, _iconBnUSD: String, ctx: &mut TxContext ){
        transfer::share_object(Config {
            id: object::new(ctx),
            xCallNetworkAddress: _xCallNetworkAddress,
            nid: _nid,
            iconBnUSD: _iconBnUSD
        });
    }

    entry fun crossTransfer(
        config: &Config,
        xcallManagerConfig: &XcallManagerConfig,
        coin: Coin<SUI>,
        token: Coin<BALANCED_DOLLAR>,
        treasury_cap: &mut TreasuryCap<BALANCED_DOLLAR>,
        to: String,
        amount: u64,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let messageData = option::get_with_default(&data, b"");
        assert!(amount > 0, AmountLessThanMinimumAmount);
        debug::print(&coin::value(&token));
        debug::print(&amount);
        //assert!(coin::value(&token) == amount, ENotTransferredAmount);
        coin::burn(treasury_cap, token);

        let from = config.xCallNetworkAddress;
        string::append(&mut from, address::to_string(tx_context::sender(ctx)));

        let xcallMessage = XCrossTransfer {
            from: from,
            to: to,
            value: amount,
            data: messageData
        };

        let rollback = XCrossTransferRevert {
            to: to,
            value: amount
        };

        let (sources, destinations) = xcall_manager::getProtocals(xcallManagerConfig);

        // xcall::sendCallMessage(
        //     coin,
        //     vars.iconBnUSD,
        //     xcallMessage,
        //     rollback,
        //     sources,
        //     destinations
        // );
        sendCallMessage(coin, config.iconBnUSD, xcallMessage, rollback, sources, destinations, ctx );
    }

    //todo: remove this method once xcall integrated
    public fun sendCallMessage(coin: Coin<SUI>,  iconBnUSD: String, xcallMessage: XCrossTransfer, rollback: XCrossTransferRevert, sources: vector<String>, destinations: vector<String>, ctx: &mut TxContext){
        debug::print(&iconBnUSD);
        debug::print(&xcallMessage);
        debug::print(&rollback);
        debug::print(&sources);
        debug::print(&destinations);

        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    public fun handleCallMessage(
        config: &Config,
        xcallManagerConfig: &XcallManagerConfig,
        from: String,
        data: vector<u8>,
        protocols: vector<String>
    ) {
        let verified = xcall_manager::verifyProtocols(xcallManagerConfig, protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        //string memory method = data.getMethod();
        let method = CROSS_TRANSFER;

        assert!(method == CROSS_TRANSFER || method == CROSS_TRANSFER_REVERT, UnknownMessageType);
        if (method == CROSS_TRANSFER) {
            assert!(from == config.iconBnUSD, OnlyICONBnUSD);
            // Messages.XCrossTransfer memory message = data.decodeCrossTransfer(); 
            // (,string memory to) = message.to.parseNetworkAddress();
            // _mint(to.parseAddress("Invalid account"), message.value);
        } else if (method == CROSS_TRANSFER_REVERT) {
            assert!(from == config.xCallNetworkAddress, OnlyCallService);
            //Messages.XCrossTransferRevert memory message = data.decodeCrossTransferRevert();
            //_mint(message.to, message.value);
        } 
    }


    #[test]
    fun test_config() {
        use sui::test_scenario;

        // Arrange
        let admin = @0xBABE;
        //let initial_owner = @0xCAFE;
        //let final_owner = @0xFACE;
        let witness = BALANCED_DOLLAR{};

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(witness, test_scenario::ctx(scenario));
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            configure(&adminCap, string::utf8(b"sui1:xcall"), string::utf8(b"sui1"), string::utf8(b"icon1:hx534"),  test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            assert!(config.iconBnUSD == string::utf8(b"icon1:hx534"), 1);
            assert!(config.xCallNetworkAddress == string::utf8(b"sui1:xcall"), 1);
            assert!(config.nid == string::utf8(b"sui1"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_cross_transfer() {
        use sui::test_scenario;
        use sui::math;

        // Arrange
        let admin = @0xBABE;
        let final_owner = @0xFACE;
        let witness = BALANCED_DOLLAR{};

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(witness, test_scenario::ctx(scenario));
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            configure(&adminCap, string::utf8(b"sui1:xcall"), string::utf8(b"sui1"), string::utf8(b"icon1:hx534"),  test_scenario::ctx(scenario));

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
        
        // Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            let xcallManagerConfig: xcall_manager::Config = test_scenario::take_shared<xcall_manager::Config>(scenario);
            let treasury_cap = test_scenario::take_from_address<TreasuryCap<BALANCED_DOLLAR>>(scenario, admin);

            let fee_amount = math::pow(10, 9 + 4);
            let bnusd_amount = math::pow(10, 18);
            let fee = coin::mint_for_testing<SUI>(fee_amount, test_scenario::ctx(scenario));
            let deposited = coin::mint(&mut treasury_cap, bnusd_amount, test_scenario::ctx(scenario));
            
            crossTransfer(&config, &xcallManagerConfig, fee, deposited, &mut treasury_cap, string::utf8(b"icon1:hx9445"),  bnusd_amount, option::none() , test_scenario::ctx(scenario));
            test_scenario::return_shared(xcallManagerConfig);
            test_scenario::return_shared( config);
            test_scenario::return_to_address(admin, treasury_cap);
        };
        test_scenario::end(scenario_val);
    }

}
