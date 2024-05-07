// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::asset_manager_test {
    use sui::test_scenario::{Self,Scenario};
    use std::string::{Self, String};
    use std::type_name::{Self};
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;
    use sui::hex;
    use std::debug;

    use xcall::xcall_state::{Self, Storage as XCallState, AdminCap as XcallAdminCap};
    use xcall::main::{Self as xcall, init_xcall_state};
    use xcall::cs_message::{Self};
    use xcall::message_request::{Self};
    use xcall::network_address::{Self};

    use balanced::asset_manager::{Self, AssetManager, Config, AdminCap, RateLimit, configure, deposit, register_token };
    use balanced::xcall_manager::{Self, Config as XcallManagerConfig, WitnessCarrier, XcallCap };
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR};

    use balanced::withdraw_to::{WithdrawTo, wrap_withdraw_to, encode};
    use balanced::deposit_revert::{Self, DepositRevert, wrap_deposit_revert};

    const ICON_ASSET_MANAGER: vector<u8> = b"icon/hx734";
    const XCALL_NETWORK_ADDRESS: vector<u8> = b"netId";
    const ADMIN: address = @0xBABE;
    const TO_ADDRESS: vector<u8>  = b"sui/0000000000000000000000000000000000000000000000000000000000001234";
    //const TOKEN_ADDRESS: vector<u8> = b"sui/0x745d";
    const ADDRESS_TO_ADDRESS: address = @0x0000000000000000000000000000000000000000000000000000000000001234;

    #[test_only]
    fun setup_test(admin:address):Scenario {
        let mut scenario = test_scenario::begin(admin);
        asset_manager::init_test(scenario.ctx());
        scenario.next_tx(admin);
        scenario = init_xcall_state(admin,scenario);
        scenario.next_tx(admin);
        xcall_manager::init_test(scenario.ctx());
        scenario.next_tx(admin);
        let adminCap = scenario.take_from_sender<AdminCap>();
        let managerAdminCap = scenario.take_from_sender<xcall_manager::AdminCap>();
        configure(&adminCap, string::utf8(ICON_ASSET_MANAGER), string::utf8(XCALL_NETWORK_ADDRESS), scenario.ctx());

        let sources = vector[string::utf8(b"centralized")];
        let destinations = vector[string::utf8(b"icon/hx234"), string::utf8(b"icon/hx334")];
        xcall_manager::configure(&managerAdminCap, string::utf8(ICON_ASSET_MANAGER), ADMIN,  sources, destinations, scenario.ctx());
        scenario.return_to_sender(adminCap);
        scenario.return_to_sender(managerAdminCap);
        scenario.next_tx(admin);
        scenario
    }

    #[test_only]
    fun setup_register_xcall(admin:address,mut scenario:Scenario):Scenario{
        let carrier = scenario.take_from_sender<WitnessCarrier>();
        let xcall_state= scenario.take_shared<XCallState>();
        let adminCap = scenario.take_from_sender<AdminCap>();
        xcall_manager::register_xcall(&xcall_state,carrier,scenario.ctx());
        test_scenario::return_shared<XCallState>(xcall_state);
        scenario.return_to_sender(adminCap);
        scenario.next_tx(admin);
        scenario
    }

    #[test_only]
    fun setup_connection(mut scenario: Scenario, from_nid: String, admin:address): Scenario {
        let mut storage = scenario.take_shared<XCallState>();
        let adminCap = scenario.take_from_sender<xcall_state::AdminCap>();
        xcall::register_connection(&mut storage, &adminCap,from_nid, string::utf8(b"centralized"), scenario.ctx());
        test_scenario::return_shared(storage);
        test_scenario::return_to_sender(&scenario, adminCap);
        scenario.next_tx(admin);
        scenario
    }

    #[test]
    fun test_config(){
        // Assert
        let mut scenario = setup_test(ADMIN);
         scenario = setup_register_xcall(ADMIN, scenario);
        let config = scenario.take_shared<Config>();
        debug::print(&config);
        test_scenario::return_shared(config);
        scenario.end();
    }

    #[test]
    fun test_register_token() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(0, scenario.ctx());
        let mut bag = scenario.take_shared<Bag>();
        // Act
        register_token(deposited, &mut bag, scenario.ctx());
        scenario.next_tx(ADMIN);
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<BALANCED_DOLLAR>()));
        let asset_manager = bag::borrow<String, AssetManager<BALANCED_DOLLAR>>(&bag, token_type);

        debug::print(asset_manager);
        // Assert
        //let assetManager = scenario.take_shared<AssetManager<BALANCED_DOLLAR>>();
        //debug::print(&assetManager);
        //test_scenario::return_shared(assetManager);

        test_scenario::return_shared(bag);
        scenario.end();
    }

    #[test]
    fun test_deposit() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario = setup_register_xcall(ADMIN, scenario);
        let token = coin::mint_for_testing<BALANCED_DOLLAR>(0, scenario.ctx());
        let mut bag = scenario.take_shared<Bag>();
        register_token(token, &mut bag, scenario.ctx());
        scenario.next_tx(ADMIN);
        scenario = setup_connection(scenario, string::utf8(b"sui"), ADMIN);

        let config = scenario.take_shared<Config>();
        //let mut assetManager = scenario.take_shared<AssetManager<BALANCED_DOLLAR>>();
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let fee_amount = math::pow(10, 9 + 4);
        let bnusd_amount = math::pow(10, 18);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, scenario.ctx());
        let mut xcall_state= scenario.take_shared<XCallState>();
        let xcallCap= scenario.take_shared<XcallCap>();
        deposit(&mut bag, &mut xcall_state, &xcallCap, &config, &xcallManagerConfig, fee, deposited, bnusd_amount, option::none(), option::none(), scenario.ctx());
        
        test_scenario::return_shared(config);
        //test_scenario::return_shared(assetManager);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(xcallCap);
        test_scenario::return_shared(bag);
        
        scenario.end();
     }


    #[test]
    fun withdraw_to_execute_call() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario = setup_register_xcall(ADMIN, scenario);
        let token = coin::mint_for_testing<BALANCED_DOLLAR>(0, scenario.ctx());
        let mut bag = scenario.take_shared<Bag>();
        register_token(token, &mut bag, scenario.ctx());
        scenario.next_tx(ADMIN);

        let xcallCap= scenario.take_shared<XcallCap>();
        let bnusd_amount = math::pow(10, 18);
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<BALANCED_DOLLAR>()));
        let message = wrap_withdraw_to(token_type, string::utf8(TO_ADDRESS), bnusd_amount);
        let data = encode(&message, b"WithdrawTo");
        
        scenario = setup_connection( scenario, string::utf8(b"icon"), ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = xcall_state::create_conn_cap_for_testing(&mut xcall_state);

        let sources = vector[string::utf8(b"centralized")];
        let sui_dapp = id_to_hex_string(&xcall_state::get_id_cap_id(xcall_manager::get_idcap(&xcallCap)));
        let icon_dapp = network_address::create(string::utf8(b"icon"), string::utf8(b"hx734"));
        let from_nid = string::utf8(b"icon");
        let request = message_request::create(icon_dapp, sui_dapp, 1, 1, data, sources);
        let message = cs_message::encode(&cs_message::new(cs_message::request_code(), message_request::encode(&request)));
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());

        scenario.next_tx(ADMIN);
        
        let config = scenario.take_shared<Config>();
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposit_fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, scenario.ctx());
        deposit(&mut bag, &mut xcall_state, &xcallCap, &config, &xcallManagerConfig, deposit_fee, deposited, bnusd_amount, option::none(), option::none(), scenario.ctx());
        asset_manager::execute_call<BALANCED_DOLLAR>(&mut bag, &xcallCap, &config, &xcallManagerConfig, &mut xcall_state, fee, 1, data, scenario.ctx());

        test_scenario::return_shared(xcallCap);
        test_scenario::return_shared(config);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(bag);
        
        scenario.end();
    }

    #[test]
    fun rollback_execute_call() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario = setup_register_xcall(ADMIN, scenario);
        let token = coin::mint_for_testing<BALANCED_DOLLAR>(0, scenario.ctx());
        let mut bag = scenario.take_shared<Bag>();
        register_token(token, &mut bag, scenario.ctx());
        scenario.next_tx(ADMIN);

        let xcallCap= scenario.take_shared<XcallCap>();
        let bnusd_amount = math::pow(10, 18);
        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<BALANCED_DOLLAR>()));
        let message = wrap_deposit_revert(token_type, ADDRESS_TO_ADDRESS, bnusd_amount);
        let data = deposit_revert::encode(&message, b"DepositRevert");
        
        scenario = setup_connection( scenario, string::utf8(b"icon"), ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = xcall_state::create_conn_cap_for_testing(&mut xcall_state);

        let sources = vector[string::utf8(b"centralized")];
        let sui_dapp = id_to_hex_string(&xcall_state::get_id_cap_id(xcall_manager::get_idcap(&xcallCap)));
        let icon_dapp = network_address::create(string::utf8(b"icon"), string::utf8(b"hx734"));
        let from_nid = string::utf8(b"icon");
        let request = message_request::create(icon_dapp, sui_dapp, 2, 1, data, sources);
        let message = cs_message::encode(&cs_message::new(cs_message::request_code(), message_request::encode(&request)));
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());

        scenario.next_tx(ADMIN);
        
        let config = scenario.take_shared<Config>();
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposit_fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, scenario.ctx());
        deposit(&mut bag, &mut xcall_state, &xcallCap, &config, &xcallManagerConfig, deposit_fee, deposited, bnusd_amount, option::none(), option::none(), scenario.ctx());
        asset_manager::execute_call<BALANCED_DOLLAR>(&mut bag, &xcallCap, &config, &xcallManagerConfig, &mut xcall_state, fee, 1, data, scenario.ctx());

        test_scenario::return_shared(xcallCap);
        test_scenario::return_shared(config);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(bag);
        
        scenario.end();
    }

    #[test_only]
    fun id_to_hex_string(id:&ID): String {
        let bytes = object::id_to_bytes(id);
        let hex_bytes = hex::encode(bytes);
        string::utf8(hex_bytes)
    }

    

}
