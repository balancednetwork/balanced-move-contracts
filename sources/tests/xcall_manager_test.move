// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::xcall_manager_test {
    use sui::test_scenario::{Self, next_tx, ctx};
    use std::string::{Self, String};

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;

    use balanced::xcall_manager::{Self, AdminCap, Config, CallServiceCap, configure, getProtocals, proposeRemoval, handleCallMessage,  verifyProtocols, getModifiedProtocols    };

    #[test]
    fun test_config() {
        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            xcall_manager::init_test(test_scenario::ctx(scenario));
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            configure(&adminCap, string::utf8(b"icon:hx734"), admin, sources, destinations,  test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            //assert!(config.iconGovernance == string::utf8(b"icon:hx734"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_verify_protocols() {
        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            xcall_manager::init_test(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            configure(&adminCap, string::utf8(b"icon:hx734"), admin, sources, destinations,  test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Act & Assert
        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let (verified) = verifyProtocols(&config, sources);
            assert!(verified, 1);
            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }

}