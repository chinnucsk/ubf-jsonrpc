%% @doc Functions for JSON&lt;->Erlang data conversion.
%%
%% For most purposes, these functions are not called by code outside of
%% this library: Erlang client &amp; Erlang server application code usually
%% have no need to use these functions.
%%
%% == Links ==
%%
%% <ul>
%% <li> http://www.erlang-projects.org/Public/news/ejson/view </li>
%% <li> http://www.erlang.org/eeps/eep-0018.html </li>
%% <li> http://www.erlang.org/ml-archive/erlang-questions/200511/msg00193.html </li>
%% <li> http://www.ietf.org/rfc/rfc4627.txt </li>
%% <li> http://www.json.org/ </li>
%% <li> http://www.lshift.net/blog/2007/02/17/json-and-json-rpc-for-erlang </li>
%% <li> http://www.json.com/json-schema-proposal/ </li>
%% </ul>
%%
%% == JSON Basic Data Types ==
%% ```
%% object
%%           {}
%%           { members }
%% members
%%           pair
%%           pair, members
%% pair
%%           string : value
%% array
%%          []
%%          [ elements ]
%% elements
%%          value
%%          value, elements
%% value
%%          string
%%          number
%%          object
%%          true (atom)
%%          false (atom)
%%          null (atom)
%% '''
%%
%% == Mapping: JSON -> Erlang Terms, using erlang-rfc46267 ==
%% ```
%% json::object() = {struct, [json::pair()]}
%%
%% json::pair() = {string(), json::value()}
%%      string() = [byte()]
%%      byte() = integer()
%%
%% json::array() = [json::value()]
%%
%% json::value() = json::object() | json::array() | json::number() | json::string() | json::true() | json::false() | json::null()
%%
%% json::number() = integer() | float()
%%
%% json::string() = binary()
%%
%% json::true() = true
%% json::false() = false
%% json::null() = null
%% '''
%%
%% == Mapping: UBF -> Erlang Terms ==
%% ```
%% ubf::tuple() = tuple()
%%
%% ubf::list() = list()
%%
%% ubf::number = integer() | float()
%%
%% ubf::string() = {'$S', [integer()]}
%%
%% ubf::proplist() = {'$P', [{term(), term()}]}
%%
%% ubf::binary() = binary()
%%
%% ubf::true() = true
%% ubf::false() = false
%% ubf::undefined() = undefined
%%
%% ubf::atom() = atom()
%%
%% ubf::record() = record()
%% '''
%%
%% == Mapping: UBF value -> JSON value ==
%% ```
%% ubf::tuple() = {struct, [{<<"$T">>, ubf::list()}]}
%%
%% ubf::list() = [value()]
%%
%% ubf::number() = integer() | float()
%%
%% ubf::string() = {struct, [{<<"$S">>, binary()}]}
%%
%% ubf::proplist() = {struct, [{binary(), value()}]}
%%
%% ubf::binary() = binary()
%%
%% ubf::true() = true
%% ubf::false() = false
%% ubf::undefined() = null
%%
%% ubf::atom() = {struct, [{<<"$A">>, atomname()}]}
%%      atomname() = binary()  % a.k.a. list_to_binary(atom_to_list()) for the actual atom
%%
%% ubf::record() = {struct, [{<<"$R">>, recordname()}] ++ [recordpair()]}
%%      recordname() = binary()  % a.k.a. list_to_binary(atom_to_list()) for the record's name
%%      recordpair() = {recordkey(), value()}
%%      recordkey() = binary()  % a.k.a. list_to_binary(atom_to_list()) for the record key's name
%%
%% value() = ubf::tuple() | ubf::list() | ubf::number() | ubf::string() | ubf::binary() | ubf::true() | ubf::false() | ubf::undefined() | ubf::atom() | ubf::record()
%% '''

-module(jsf).
-behavior(contract_proto).

-include("ubf.hrl").

-export([proto_vsn/0, proto_driver/0, proto_packet_type/0]).
-export([encode/1, encode/2, do_encode/2]).
-export([decode_init/0, decode/1, decode/2, decode/3, do_decode/2]).

-export([atom_to_binary/1]).
-export([binary_to_existing_atom/1]).


%% Dummy hack/kludge.
-export([contract_records/0]).

contract_records() ->
    [].


%%
%%---------------------------------------------------------------------
%%
proto_vsn()         -> 'jsf1.0'.
proto_driver()      -> jsf_driver.
proto_packet_type() -> 0.


%%
%%---------------------------------------------------------------------
%%
encode(X) ->
    encode(X, ?MODULE).

encode(X, Mod) ->
    Encoder = mochijson2:encoder([{utf8, true}]),
    iolist_to_binary(Encoder(do_encode(X, Mod))).

do_encode(X, _Mod) when is_binary(X); is_integer(X); is_float(X) ->
    X;
do_encode(X, _Mod) when is_atom(X) ->
    encode_atom(X);
do_encode(X, Mod) when is_list(X) ->
    encode_list(X, Mod);
do_encode(?S(X), _Mod) ->
    encode_string(X);
do_encode(?P(X), Mod) ->
    encode_proplist(X, Mod);
do_encode(X, Mod) when is_tuple(X) ->
    encode_tuple(X, Mod).

encode_atom(true) ->
    true;
encode_atom(false) ->
    false;
encode_atom(undefined) ->
    null;
encode_atom(X) ->
    {struct, [{<<"$A">>, atom_to_binary(X)}]}.

encode_list(X, Mod) ->
    encode_list(X, [], Mod).

encode_list([], Acc, _Mod) ->
    lists:reverse(Acc);
encode_list([H|T], Acc, Mod) ->
    NewAcc = [do_encode(H, Mod)|Acc],
    encode_list(T, NewAcc, Mod).

encode_string(X) when is_list(X) ->
    {struct, [{<<"$S">>, list_to_binary(X)}]}.

encode_proplist(X, Mod) when is_list(X) ->
    {struct, [ {K, do_encode(V, Mod)} || {K, V} <- X ]}.

encode_tuple({}, _Mod) ->
    {struct, [{<<"$T">>, []}]};
encode_tuple(X, Mod) when not is_atom(element(1, X)) ->
    {struct, [{<<"$T">>, encode_tuple(1, X, [], Mod)}]};
encode_tuple(X, Mod) ->
    RecName = element(1, X),
    Y = {RecName, tuple_size(X)-1},
    case lists:member(Y, Mod:contract_records()) of
        false ->
            {struct, [{<<"$T">>, encode_tuple(1, X, [], Mod)}]};
        true ->
            %% @TODO optimize this code
            Keys = list_to_tuple(Mod:contract_record(Y)),
            {struct, [{<<"$R">>, atom_to_binary(RecName)}|encode_record(2, X, Keys, [], Mod)]}
    end.

encode_tuple(N, X, Acc, _Mod) when is_integer(N), N > tuple_size(X) ->
    lists:reverse(Acc);
encode_tuple(N, X, Acc, Mod) ->
    NewAcc = [do_encode(element(N, X), Mod)|Acc],
    encode_tuple(N+1, X, NewAcc, Mod).

encode_record(N, X, _Keys, Acc, _Mod) when is_integer(N), N > tuple_size(X) ->
    Acc;
encode_record(N, X, Keys, Acc, Mod) ->
    NewAcc = [{atom_to_binary(element(N-1, Keys)), do_encode(element(N, X), Mod)}|Acc],
    encode_record(N+1, X, Keys, NewAcc, Mod).


%%
%%---------------------------------------------------------------------
%%
decode_init() -> {more, <<>>}.

decode(X) ->
    decode(X, ?MODULE).

decode(X, Mod) ->
    decode(X, Mod, decode_init()).

decode(X, Mod, {more, Old}) ->
    decode(X, Mod, Old);
decode(X, Mod, Old) when is_list(X) ->
    decode(list_to_binary(X), Mod, Old);
decode(X, Mod, Old) when is_binary(X) ->
    New = <<Old/bitstring, X/bitstring>>,
    if
	New==<<>> ->
	    {more, <<>>};
	true ->
	    case gmt_charset:classify(New) of
		'8bit' ->
		    %% same crash as rfc4627.erl and xmerl_ucs.erl
		    exit({ucs,{bad_utf8_character_code}});
		_ ->
		    case catch mochijson2:decode(New) of
			{'EXIT',_} ->
			    {error,syntax_error};
			JSON ->
			    {ok, do_decode(JSON, Mod), <<>>}
		    end
	    end
    end.

do_decode(X, _Mod) when is_binary(X); is_integer(X); is_float(X) ->
    X;
do_decode(X, _Mod) when is_atom(X) ->
    decode_atom(X);
do_decode(X, Mod) when is_list(X) ->
    decode_list(X, Mod);
do_decode({struct, [{<<"$A">>, X}]}, _Mod) ->
    decode_atom(X);
do_decode({struct, [{<<"$S">>, X}]}, _Mod) ->
    decode_string(X);
do_decode({struct, [{<<"$T">>, X}]}, Mod) ->
    decode_tuple(X, Mod);
do_decode({struct, X}, Mod) ->
    case lists:keytake(<<"$R">>, 1, X) of
        {value, {<<"$R">>, RecName}, Y} ->
            decode_record(RecName, Y, Mod);
        false ->
            decode_proplist(X, Mod)
    end.

decode_atom(true) ->
    true;
decode_atom(false) ->
    false;
decode_atom(null) ->
    undefined;
decode_atom(X) when is_binary(X) ->
    binary_to_existing_atom(X).

decode_list(X, Mod) ->
    decode_list(X, [], Mod).

decode_list([], Acc, _Mod) ->
    lists:reverse(Acc);
decode_list([H|T], Acc, Mod) ->
    NewAcc = [do_decode(H, Mod)|Acc],
    decode_list(T, NewAcc, Mod).

decode_string(X) when is_binary(X) ->
    ?S(binary_to_list(X)).

decode_proplist(X, Mod) when is_list(X) ->
    ?P([ {K, do_decode(V, Mod)} || {K, V} <- X ]).

decode_tuple(L, Mod) ->
    decode_tuple(L, [], Mod).

decode_tuple([], Acc, _Mod) ->
    list_to_tuple(lists:reverse(Acc));
decode_tuple([H|T], Acc, Mod) ->
    NewAcc = [do_decode(H, Mod)|Acc],
    decode_tuple(T, NewAcc, Mod).

decode_record(RecNameStr, X, Mod) ->
    RecName = binary_to_existing_atom(RecNameStr),
    Y = {RecName, length(X)},
    Keys = Mod:contract_record(Y),
    decode_record(RecName, Keys, X, [], Mod).

decode_record(RecName, [], [], Acc, _Mod) ->
    list_to_tuple([RecName|lists:reverse(Acc)]);
decode_record(RecName, [H|T], X, Acc, Mod) ->
    K = atom_to_binary(H),
    case lists:keytake(K, 1, X) of
        {value, {K, V}, NewX} ->
            NewAcc = [do_decode(V, Mod)|Acc],
            decode_record(RecName, T, NewX, NewAcc, Mod);
        false ->
            exit({badrecord, RecName})
    end.


%%
%%---------------------------------------------------------------------
%%
atom_to_binary(X) ->
    list_to_binary(atom_to_list(X)).

binary_to_existing_atom(X) ->
    list_to_existing_atom(binary_to_list(X)).
