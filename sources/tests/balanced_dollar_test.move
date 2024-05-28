// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::balanced_dollar_test {
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use std::string::{Self, String};
    use std::debug::{Self};

    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui::math;
    use sui::hex;

    use xcall::xcall_state::{Self, Storage as XCallState};
    use xcall::main::{Self as xcall, init_xcall_state};
    use xcall::cs_message::{Self};
    use xcall::message_request::{Self};
    use xcall::network_address::{Self};

    use balanced::xcall_manager::{Self, WitnessCarrier as XcallManagerWitnessCarrier};
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR, AdminCap, Config, TreasuryCapCarrier, configure, cross_transfer, get_treasury_cap_for_testing, WitnessCarrier    };
    
    use balanced::cross_transfer::{wrap_cross_transfer, encode};
    use balanced::cross_transfer_revert::{Self, wrap_cross_transfer_revert};

    const ADMIN: address = @0xBABE;
    const TO: vector<u8> = b"sui/address";
    
    const ICON_BnUSD: vector<u8> = b"icon/hx734";

    const TO_ADDRESS: vector<u8>  = b"sui/0000000000000000000000000000000000000000000000000000000000001234";
    const FROM_ADDRESS: vector<u8>  = b"sui/000000000000000000000000000000000000000000000000000000000000123d";
    const ADDRESS_TO_ADDRESS: address = @0x645d;

     #[test_only]
    fun setup_test(admin:address):Scenario {
        let mut scenario = test_scenario::begin(admin);
        balanced_dollar::init_test(scenario.ctx());
        scenario.next_tx(admin);
        scenario = init_xcall_state(admin,scenario);
        scenario.next_tx(admin);
        xcall_manager::init_test(scenario.ctx());
        scenario.next_tx(admin);
        let adminCap = scenario.take_from_sender<AdminCap>();
        let managerAdminCap = scenario.take_from_sender<xcall_manager::AdminCap>();
        let xcall_state= scenario.take_shared<XCallState>();
        let carrier = scenario.take_from_sender<WitnessCarrier>();
        configure(&adminCap, &xcall_state, carrier, string::utf8(b"icon/hx534"),  1,  scenario.ctx());

        let sources = vector[string::utf8(b"centralized")];
        let destinations = vector[string::utf8(b"icon/hx234"), string::utf8(b"icon/hx334")];
        let xm_carrier = scenario.take_from_sender<XcallManagerWitnessCarrier>();
        xcall_manager::configure(&managerAdminCap, &xcall_state, xm_carrier, string::utf8(ICON_BnUSD),  sources, destinations, 1, scenario.ctx());
        test_scenario::return_shared<XCallState>(xcall_state);
        scenario.return_to_sender(adminCap);
        scenario.return_to_sender(managerAdminCap);
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
        let scenario = setup_test(ADMIN);
        let config = scenario.take_shared<Config>();
        debug::print(&config);
        test_scenario::return_shared(config);
        scenario.end();
    }

    #[test]
    fun test_cross_transfer() {
        // Arrange
        let mut scenario = setup_test(ADMIN);

        scenario.next_tx(ADMIN);
        scenario = setup_connection(scenario, string::utf8(b"sui"), ADMIN);
       
        // Assert
        let config = scenario.take_shared<Config>();
        let xcallManagerConfig: xcall_manager::Config = scenario.take_shared<xcall_manager::Config>();
        let mut treasury_cap = scenario.take_shared<TreasuryCapCarrier<BALANCED_DOLLAR>>();

        let fee_amount = math::pow(10, 9 + 4);
        let bnusd_amount = math::pow(10, 18);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let deposited = coin::mint(get_treasury_cap_for_testing(&mut treasury_cap), bnusd_amount, scenario.ctx());

        let mut xcall_state= scenario.take_shared<XCallState>();
    
        cross_transfer(&mut xcall_state, &config, &xcallManagerConfig, fee, deposited, &mut treasury_cap, TO.to_string(),  bnusd_amount, option::none(), scenario.ctx());
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared( config);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(treasury_cap);
        scenario.end();
    }

    #[test]
    fun cross_transfer_execute_call() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario.next_tx(ADMIN);

        let bnusd_amount = math::pow(10, 18);
        let message = wrap_cross_transfer(string::utf8(FROM_ADDRESS),  string::utf8(TO_ADDRESS), bnusd_amount, b"");
        let data = encode(&message, b"xCrossTransfer");
        
        scenario = setup_connection( scenario, string::utf8(b"icon"), ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = xcall_state::create_conn_cap_for_testing(&mut xcall_state);

        let config = scenario.take_shared<Config>();

        let sources = vector[string::utf8(b"centralized")];
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let sui_dapp = id_to_hex_string(&xcall_state::get_id_cap_id(balanced_dollar::get_idcap(&config)));
        let icon_dapp = network_address::create(string::utf8(b"icon"), string::utf8(b"hx534"));
        let from_nid = string::utf8(b"icon");
        let request = message_request::create(icon_dapp, sui_dapp, 1, 1, data, sources);
        let message = cs_message::encode(&cs_message::new(cs_message::request_code(), message_request::encode(&request)));
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());

        scenario.next_tx(ADMIN);
        
        
        
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let mut treasury_cap = scenario.take_shared<TreasuryCapCarrier<BALANCED_DOLLAR>>();
        balanced_dollar::execute_call(&mut treasury_cap, &config, &xcallManagerConfig, &mut xcall_state, fee, 1, data, scenario.ctx());

        test_scenario::return_shared(config);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(treasury_cap);
        
        scenario.end();
    }
    

    #[test]
    fun cross_transfer_rollback_execute_call() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario.next_tx(ADMIN);

        let bnusd_amount = math::pow(10, 18);
        let message = wrap_cross_transfer_revert( ADDRESS_TO_ADDRESS, bnusd_amount);
        let data = cross_transfer_revert::encode(&message, b"xCrossTransferRevert");

        scenario = setup_connection( scenario, string::utf8(b"icon"), ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = xcall_state::create_conn_cap_for_testing(&mut xcall_state);

        let config = scenario.take_shared<Config>();

        let sources = vector[string::utf8(b"centralized")];
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let sui_dapp = id_to_hex_string(&xcall_state::get_id_cap_id(balanced_dollar::get_idcap(&config)));
        let icon_dapp = network_address::create(string::utf8(b"icon"), string::utf8(b"hx534"));
        let from_nid = string::utf8(b"icon");
        let request = message_request::create(icon_dapp, sui_dapp, 2, 1, data, sources);
        let message = cs_message::encode(&cs_message::new(cs_message::request_code(), message_request::encode(&request)));
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());

        scenario.next_tx(ADMIN);
        
        
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());

        let mut treasury_cap = scenario.take_shared<TreasuryCapCarrier<BALANCED_DOLLAR>>();
        balanced_dollar::execute_call(&mut treasury_cap, &config, &xcallManagerConfig, &mut xcall_state, fee, 1, data, scenario.ctx());

        test_scenario::return_shared(config);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(treasury_cap);
        
        scenario.end();
    }

    #[test_only]
    fun id_to_hex_string(id:&ID): String {
        let bytes = object::id_to_bytes(id);
        let hex_bytes = hex::encode(bytes);
        string::utf8(hex_bytes)
    }

}