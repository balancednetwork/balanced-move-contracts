// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::asset_manager_test {
    use sui::test_scenario::{Self,Scenario};
    use std::string::{Self, String};

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;
    use std::debug;

    use xcall::xcall_state::{Self, Storage as XCallState, AdminCap as XcallAdminCap};
    use xcall::main::{Self as xcall, init_xcall_state};

    use balanced::asset_manager::{Self, AssetManager, Config, AdminCap, RateLimit, configure, deposit, register_token, WitnessCarrier, XcallCap  };
    // use balanced::deposit::Deposit;
    // use balanced::deposit_revert::DepositRevert;
    // use balanced::withdraw_to::WithdrawTo;

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR};

    const ICON_ASSET_MANAGER: vector<u8> = b"icon:hx734";
    const ICON_GOVERNANCE: vector<u8> = b"icon:hx3243";
    const XCALL_NETWORK_ADDRESS: vector<u8> = b"netId";
    const ADMIN: address = @0xBABE;

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

        let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
        let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
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
        asset_manager::register_xcall(&xcall_state,carrier,scenario.ctx());
        test_scenario::return_shared<XCallState>(xcall_state);
        scenario.return_to_sender(adminCap);
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

        // Act
        register_token(deposited, scenario.ctx());
        scenario.next_tx(ADMIN);

        // Assert
        let assetManager = scenario.take_shared<AssetManager<BALANCED_DOLLAR>>();
        debug::print(&assetManager);
        test_scenario::return_shared(assetManager);
        scenario.end();
    }

    #[test]
    fun test_deposit() {
        // Arrange
        let mut scenario = setup_test(ADMIN);
        scenario = setup_register_xcall(ADMIN, scenario);
        let token = coin::mint_for_testing<BALANCED_DOLLAR>(0, scenario.ctx());
        register_token(token, scenario.ctx());
        scenario.next_tx(ADMIN);

        let config = scenario.take_shared<Config>();
        let mut assetManager = scenario.take_shared<AssetManager<BALANCED_DOLLAR>>();
        let xcallManagerConfig: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        let fee_amount = math::pow(10, 9 + 4);
        let bnusd_amount = math::pow(10, 18);
        //let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        //let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, scenario.ctx());
        let mut xcall_state= scenario.take_shared<XCallState>();
        let xcallCap= scenario.take_shared<XcallCap>();
        //deposit(&mut assetManager, &mut xcall_state, &xcallCap, &config, &xcallManagerConfig, fee, deposited, bnusd_amount, option::none(), option::none(), scenario.ctx());
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(assetManager);
        test_scenario::return_shared(xcallManagerConfig);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(xcallCap);

        scenario.end();
     }



    

}
