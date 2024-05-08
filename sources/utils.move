module balanced::balanced_utils {

    use std::string::{Self, String};
    use sui::bcs::{Self};
    use sui::hex::{Self};


    public fun address_to_hex_string(address:&address): String {
        let bytes = bcs::to_bytes(address);
        let hex_bytes = hex::encode(bytes);
        string::utf8(hex_bytes)
    }

    public fun address_from_hex_string(str: &String): address {
        let bytes = str.bytes();
        let hex_bytes = hex::decode(*bytes);
        bcs::peel_address(&mut bcs::new(hex_bytes))
    }

    #[test]
    fun test_address_conversion(){
        let a = @0xBABE;
        let a_string = address_to_hex_string(&a);
        let result = address_from_hex_string(&a_string);
        assert!(a == result, 0x01);
    }
} 

