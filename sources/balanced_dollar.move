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

    use xcall::main::{Self};
    use balanced::xcall_manager::{Self, XcallManagerVars};

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferRevert";

    const AmountLessThanMinimumAmount: u64  = 1;
    const ProtocolMismatch: u64 = 2;
    const OnlyICONBnUSD: u64 = 3;
    const OnlyCallService: u64 = 4;
    const UnknownMessageType: u64 = 5;

    struct BALANCED_DOLLAR has drop {}

    struct AdminCap has key{
        id: UID 
    }

    struct XCrossTransfer has drop{
        from: String, 
        to: String,
        value: u256,
        data: vector<u8>
    }

    struct XCrossTransferRevert has drop{
        to: String,
        value: u256
    }

    struct BalancedDollarVars has key, store{
        id: UID, 
        xCall: address,
        xCallNetworkAddress: String,
        nid: String,
        iconBnUSD: String,
        xCallManager: address,
    }

    struct CallServiceCap has key{
        id: UID, 
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

        transfer::transfer(AdminCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    entry fun configure(_: &AdminCap, _xCallNetworkAddress: String, _xCall: address, _nid: String, _iconBnUSD: String, _xCallManager: address,  ctx: &mut TxContext ){
        transfer::share_object(BalancedDollarVars{
            id: object::new(ctx),
            xCall: _xCall,
            xCallNetworkAddress: _xCallNetworkAddress,
            nid: _nid,
            iconBnUSD: _iconBnUSD,
            xCallManager: _xCallManager
        });
        transfer::transfer(CallServiceCap{
            id: object::new(ctx)
        }, _xCall);
    }

    entry fun crossTransfer(
        vars: &BalancedDollarVars,
        xcallManagerVars: &XcallManagerVars,
        coin: Coin<SUI>,
        token: Coin<BALANCED_DOLLAR>,
        treasury_cap: &mut TreasuryCap<BALANCED_DOLLAR>,
        to: String,
        value: u256,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let messageData = option::get_with_default(&data, b"");
        assert!(value > 0, AmountLessThanMinimumAmount);
        coin::burn(treasury_cap, token);

        let from = vars.xCallNetworkAddress;
        string::append(&mut from, address::to_string(tx_context::sender(ctx)));

        let xcallMessage = XCrossTransfer{
            from: from,
            to: to,
            value: value,
            data: messageData
        };

        let rollback = XCrossTransferRevert{
            to: to,
            value: value
        };

        let (sources, destinations) = xcall_manager::getProtocals(xcallManagerVars);

        // xcall::sendCallMessage(
        //     coin,
        //     vars.iconBnUSD,
        //     xcallMessage,
        //     rollback,
        //     sources,
        //     destinations
        // );
        sendCallMessage(coin, vars.iconBnUSD, xcallMessage, rollback, sources, destinations, ctx );
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
        vars: &BalancedDollarVars,
        xcallManagerVars: &XcallManagerVars,
        from: String,
        data: vector<u8>,
        protocols: vector<String>
    ) {
        let verified = xcall_manager::verifyProtocols(xcallManagerVars, protocols);
        assert!(
            verified,
            ProtocolMismatch
        );

        //string memory method = data.getMethod();
        let method = CROSS_TRANSFER;

        assert!(method == CROSS_TRANSFER || method == CROSS_TRANSFER_REVERT, UnknownMessageType);
        if (method == CROSS_TRANSFER) {
            assert!(from == vars.iconBnUSD, OnlyICONBnUSD);
            // Messages.XCrossTransfer memory message = data.decodeCrossTransfer(); 
            // (,string memory to) = message.to.parseNetworkAddress();
            // _mint(to.parseAddress("Invalid account"), message.value);
        } else if (method == CROSS_TRANSFER_REVERT) {
            assert!(from == vars.xCallNetworkAddress, OnlyCallService);
            //Messages.XCrossTransferRevert memory message = data.decodeCrossTransferRevert();
            //_mint(message.to, message.value);
        } 
    }


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BALANCED_DOLLAR {}, ctx);
    }
}
