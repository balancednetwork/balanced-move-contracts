#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module balanced::configure_protocol {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct ConfigureProtocol has drop{
        sources: vector<String>, 
        destinations: vector<String>
    }

    public fun encode(req:&ConfigureProtocol, method: vector<u8>):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));

        let source_encoded = encoder::encode_strings(&req.sources);
        let dest_encoded = encoder::encode_strings(&req.destinations);

        vector::push_back(&mut list, encoder::encode(&source_encoded));
        vector::push_back(&mut list, encoder::encode(&dest_encoded));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): ConfigureProtocol {
        let decoded = decoder::decode_list(bytes);
        let sources = decoder::decode_strings(vector::borrow(&decoded, 1));
        let destinations = decoder::decode_strings(vector::borrow(&decoded, 2));

        let req = wrap_protocols (
             sources,
             destinations
        );
        req
    }

    public fun wrap_protocols(sources: vector<String>, destinations: vector<String>): ConfigureProtocol {
        let protocols = ConfigureProtocol {
            sources: sources,
            destinations: destinations

        };
        protocols
    }

    public fun get_method(bytes:&vector<u8>): vector<u8> {
        let decoded=decoder::decode_list(bytes);
        let method = decoder::decode(vector::borrow(&decoded, 0));
        method
    }

    public fun sources(protocols: &ConfigureProtocol): vector<String>{
        protocols.sources
    }

    public fun destinations(protocols: &ConfigureProtocol): vector<String>{
        protocols.destinations
    }

}