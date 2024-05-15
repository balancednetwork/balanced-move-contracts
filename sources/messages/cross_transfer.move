#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::cross_transfer {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct XCrossTransfer has drop{
        from: String, 
        to: String,
        value: u64,
        data: vector<u8>
    }

    public fun encode(req:&XCrossTransfer, method: vector<u8>):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        vector::push_back(&mut list,encoder::encode_string(&req.from));
        vector::push_back(&mut list,encoder::encode_string(&req.to));
        vector::push_back(&mut list,encoder::encode_u64(req.value));
        vector::push_back(&mut list,encoder::encode(&req.data));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): XCrossTransfer {
        let decoded=decoder::decode_list(bytes);
        let from = decoder::decode_string(vector::borrow(&decoded, 1));
        let to = decoder::decode_string(vector::borrow(&decoded, 2));
        let value = decoder::decode_u64(vector::borrow(&decoded, 3));
        let data = *vector::borrow(&decoded, 4);
        let req= XCrossTransfer {
            from,
            to,
            value,
            data
        };
        req
    }

     public fun wrap_cross_transfer(from: String, to: String, value: u64, data: vector<u8>): XCrossTransfer {
        let cross_transfer = XCrossTransfer {
            from: from,
            to: to,
            value: value,
            data: data

        };
        cross_transfer
    }

    public fun get_method(bytes:&vector<u8>): vector<u8> {
        let decoded=decoder::decode_list(bytes);
        *vector::borrow(&decoded, 0)
    }

    public fun from(cross_transfer: &XCrossTransfer): String{
        cross_transfer.from
    }

    public fun to(cross_transfer: &XCrossTransfer): String{
        cross_transfer.to
    }

    public fun value(cross_transfer: &XCrossTransfer): u64{
        cross_transfer.value
    }

    public fun data(cross_transfer: &XCrossTransfer): vector<u8>{
        cross_transfer.data
    }


    #[test]
    fun test_xtransfer_encode_decode(){
        let from = string::utf8(b"sui/from");
        let to = string::utf8(b"sui/to");
        let transfer = wrap_cross_transfer(from, to, 90, b"");
        let data: vector<u8> = encode(&transfer, b"test");
        let result = decode(&data);
        
        assert!(result.from == from, 0x01);
        assert!(result.to == to, 0x01);
        assert!(result.value == 90, 0x01);
        assert!(result.data == b"", 0x01);
    }

}