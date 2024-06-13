#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::cross_transfer_revert {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct XCrossTransferRevert has drop{
        to: address,
        value: u64
    }

    public fun encode(req:&XCrossTransferRevert, method: vector<u8>): vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        vector::push_back(&mut list,encoder::encode_address(&req.to));
        vector::push_back(&mut list,encoder::encode_u64(req.value));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): XCrossTransferRevert {
        let decoded=decoder::decode_list(bytes);
        let to = decoder::decode_address(vector::borrow(&decoded, 1));
        let value = decoder::decode_u64(vector::borrow(&decoded, 2));
        let req= wrap_cross_transfer_revert (
            to,
            value
        );
        req
    }

     public fun wrap_cross_transfer_revert( to: address, value: u64): XCrossTransferRevert {
        let cross_transfer_revert = XCrossTransferRevert {
            to: to,
            value: value,
        };
        cross_transfer_revert
    }

    public fun to(cross_transfer_revert: &XCrossTransferRevert): address{
        cross_transfer_revert.to
    }

    public fun value(cross_transfer_revert: &XCrossTransferRevert): u64{
        cross_transfer_revert.value
    }

    #[test]
    fun test_transfer_revert_encode_decode(){
        let to = @0xBABE;
        let xcall_revert = wrap_cross_transfer_revert(to, 90);
        let data: vector<u8> = encode(&xcall_revert, b"test");
        let result = decode(&data);
        
        assert!(result.to == to, 0x01);
        assert!(result.value == 90, 0x01);
    }

}