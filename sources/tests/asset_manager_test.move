// Copyright (c) Sui Foundation, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module balanced::asset_manager_test {
    use sui::test_scenario::{Self, next_tx, ctx};
    use std::string::{Self, String};

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::address::{Self};
    use sui::sui::SUI;
    use sui::math;

    use balanced::asset_manager::{Self, AssetManager, Config, AdminCap, RateLimit, configure, deposit, register_token  };
    use balanced::deposit::Deposit;
    use balanced::deposit_revert::DepositRevert;
    use balanced::withdraw_to::WithdrawTo;

    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use balanced::balanced_dollar::{Self, BALANCED_DOLLAR};
    

    #[test]
    fun test_config() {
        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            asset_manager::test_init(test_scenario::ctx(scenario));
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
            // assert!(config.iconAssetManager == string::utf8(b"icon:hx734"), 1);
            // assert!(config.xCallNetworkAddress == string::utf8(b"address"), 1);

            test_scenario::return_shared( config);
        };
        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_register_token() {
        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            asset_manager::test_init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            
            configure(&adminCap, string::utf8(b"icon:hx734"), string::utf8(b"address"), test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, adminCap);
        };

        // Act
        test_scenario::next_tx(scenario, admin);
        {
            let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(0, test_scenario::ctx(scenario));
            register_token(deposited, test_scenario::ctx(scenario));
        };


        test_scenario::next_tx(scenario, admin);
        {
            let assetManager = test_scenario::take_shared<AssetManager<BALANCED_DOLLAR>>(scenario);
            // assert!(balance::value(&assetManager.balance)==0, 1);
            // assert!(balance::value(&assetManager.balance)!=1, 1);
            test_scenario::return_shared(assetManager);
        };

        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_deposit() {
        // Arrange
        let admin = @0xBABE;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {  asset_manager::test_init(test_scenario::ctx(scenario)); };
        
        test_scenario::next_tx(scenario, admin);
        {
            let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
            configure(&adminCap, string::utf8(b"icon:hx734"), string::utf8(b"address"), test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, adminCap);
            let sources = vector[string::utf8(b"xcall"), string::utf8(b"connection")];
            let destinations = vector[string::utf8(b"icon:hx234"), string::utf8(b"icon:hx334")];
            xcall_manager::share_config_for_testing(
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
            let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(0, test_scenario::ctx(scenario));
            register_token(deposited, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let config = test_scenario::take_shared<Config>(scenario);
            let mut assetManager = test_scenario::take_shared<AssetManager<BALANCED_DOLLAR>>(scenario);
            let xcallManagerConfig: xcall_manager::Config  = test_scenario::take_shared<xcall_manager::Config>(scenario);
            let fee_amount = math::pow(10, 9 + 4);
            let bnusd_amount = math::pow(10, 18);
            //let fee = coin::mint_for_testing<SUI>(fee_amount, test_scenario::ctx(scenario));
            //let deposited = coin::mint_for_testing<BALANCED_DOLLAR>(bnusd_amount, test_scenario::ctx(scenario));
          
            
            //deposit(&mut assetManager, &config, &xcallManagerConfig, fee, deposited, bnusd_amount, option::none(), option::none(), test_scenario::ctx(scenario));
            test_scenario::return_shared(config);
            test_scenario::return_shared(assetManager);
            test_scenario::return_shared(xcallManagerConfig);
        };

        test_scenario::end(scenario_val);

     }

}
