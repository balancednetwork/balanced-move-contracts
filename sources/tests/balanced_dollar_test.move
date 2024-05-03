// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::balanced_dollar_test {
    use sui::test_scenario::{Self, next_tx, ctx};
    use std::string::{Self, String};

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR, AdminCap, Config, XCrossTransfer, XCrossTransferRevert, configure, crossTransfer, handleCallMessage    };

    #[test]
    fun test_config() {
        // Arrange
        let admin = @0xBABE;
        //let initial_owner = @0xCAFE;
        //let final_owner = @0xFACE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            balanced_dollar::test_init( test_scenario::ctx(scenario));
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
            // assert!(config.iconBnUSD == string::utf8(b"icon1:hx534"), 1);
            // assert!(config.xCallNetworkAddress == string::utf8(b"sui1:xcall"), 1);
            // assert!(config.nid == string::utf8(b"sui1"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

    // #[test]
    // fun test_cross_transfer() {

    //     // Arrange
    //     let admin = @0xBABE;
    //     let final_owner = @0xFACE;

    //     let mut scenario_val = test_scenario::begin(admin);
    //     let scenario = &mut scenario_val;
    //     {
    //         balanced_dollar::test_init(test_scenario::ctx(scenario));
    //     };

    //     // Act
    //     test_scenario::next_tx(scenario, admin);
    //     {
    //         let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
    //         configure(&adminCap, string::utf8(b"sui1:xcall"), string::utf8(b"sui1"), string::utf8(b"icon1:hx534"),  test_scenario::ctx(scenario));

    //         test_scenario::return_to_sender(scenario, adminCap);
    //         let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
    //         let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
    //         xcall_manager::share_config_for_testing(
    //              string::utf8(b"iconGovernance"),
    //              admin,
    //              sources,
    //              destinations,
    //              string::utf8(b""),
    //              test_scenario::ctx(scenario)
    //         );
    //     };
        
    //     // Assert
    //     test_scenario::next_tx(scenario, admin);
    //     {
    //         let config = test_scenario::take_shared<Config>(scenario);
    //         let xcallManagerConfig: xcall_manager::Config = test_scenario::take_shared<xcall_manager::Config>(scenario);
    //         let mut treasury_cap = test_scenario::take_from_address<TreasuryCap<BALANCED_DOLLAR>>(scenario, admin);

    //         let fee_amount = math::pow(10, 9 + 4);
    //         let bnusd_amount = math::pow(10, 18);
    //         let fee = coin::mint_for_testing<SUI>(fee_amount, test_scenario::ctx(scenario));
    //         let deposited = coin::mint(&mut treasury_cap, bnusd_amount, test_scenario::ctx(scenario));
            
    //         crossTransfer(&config, &xcallManagerConfig, fee, deposited, &mut treasury_cap, string::utf8(b"icon1:hx9445"),  bnusd_amount, option::none() , test_scenario::ctx(scenario));
    //         test_scenario::return_shared(xcallManagerConfig);
    //         test_scenario::return_shared( config);
    //         test_scenario::return_to_address(admin, treasury_cap);
    //     };
    //     test_scenario::end(scenario_val);
    // }

}