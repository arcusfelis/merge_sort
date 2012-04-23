-module(merge_sort).


bag() -> {[], []}.
list({H, T}) -> lists:reverse(H, T).


add(Elem, {[HH|HT] = Head, Tail}) when Elem < HH ->
    add_forward(Elem, Head, Tail);

add(Elem, {Head, Tail}) ->
    add_backward(Elem, Head, Tail).


add_forward(E, [HH|HT], T) when E < HH ->
    add_forward(E, HT, [HH|T]);

add_forward(E, H, T) ->
    {H, [E|T]}.


add_backward(E, H, [HT|TT]) when E > HT ->
    add_backward(E, [HT|H], TT);

add_backward(E, H, T) ->
    {[E|H], T}.


run(Filename, From, Parts, Acc) ->
    {ok, FD} = file:open(Filename, [read, binary]),
    {ok, Max} = file:position(FD, eof),
    file:position(FD, bof),
    Len = Max div Parts,
    read_part(FD, From, Len, Acc).

read_part(FD, Num, Len, Acc) ->
    {Type, Bag} = read_chunk(FD, Len, bag()),
    Acc(Num, list(Bag)),
    case Type of
    eof -> 
        ok;
    eoc ->
        read_part(FD, Num+1, Len, Acc)
    end.

read_chunk(FD, Len, Bag) ->
    case file:read_line(FD) of
    {ok, Str} ->
        StrLen = erlang:byte_size(Str),
        NewLen = Len - StrLen,
        NewBag = add(Str, Bag),
        if NewLen < 0 -> 
                {eoc, NewBag};
            true -> 
                read_chunk(FD, NewLen, NewBag)
        end;
    eof -> 
        {eof, Bag}
    end.


%% Lazy file
lf_open(Name) ->
    {ok, Fd} = file:open(Name, [read, binary]),
    {Fd, []}.


lf_add(Elem, {Fd, Acc}) -> {Fd, [Elem|Acc]}.

lf_pop({Fd, [H|T]}) -> {H, {Fd, T}};
lf_pop({Fd, []}) -> 
    case file:read_line(Fd) of
    {ok, Line} ->
        {Line, {Fd, []}};
    eof ->
        io:format(user, "Close reader~n", []),
        file:close(Fd),
        eof
    end.


lf_foreach([H|LazyReaders], Handler) ->
    case lf_pop(H) of
    eof ->
        lf_foreach(LazyReaders, Handler);
    {Min, MinReader} ->
        {NewMin, NewReaders} = 
        lf_foreach(LazyReaders, Min, MinReader, []),
        Handler(NewMin),
        lf_foreach(NewReaders, Handler)
    end;

lf_foreach([], _Handler) ->
    eof.


lf_foreach([H|T], Min, MR, Acc) ->
    case lf_pop(H) of
    eof ->
        lf_foreach(T, Min, MR, Acc);

    {Cur, NewH} ->
        if Cur < Min ->
            %% Replace old Min
            lf_foreach(T, Cur, NewH, [lf_add(Min, MR)|Acc]);
           true ->
            lf_foreach(T, Min, MR,   [lf_add(Cur, NewH)|Acc])
        end
    end;

lf_foreach([], Min, MR, Acc) ->
    {Min, [MR|Acc]}.


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

simple_test() ->
    PartCount = 10,
    crypto:start(),
    Dir = mochitemp:mkdtemp(),
    TestDataFN = filename:join(Dir, testdata),

    %% Fill
    test_file(TestDataFN),

    %% Sort
    Acc = fun(Num, Acc) ->
        PartName = filename:join(Dir, integer_to_list(Num)),
        io:format(user, "~p~n", [PartName]),
        file:write_file(PartName, Acc)
        end,
    From = 1,
    run(TestDataFN, From, PartCount, Acc),

    
    %% Merge
    TempFNsAll = 
    [filename:join(Dir, integer_to_list(Num)) || Num <- lists:seq(From, PartCount)],
    TempFNs = [File || File <- TempFNsAll, filelib:is_regular(File)],
    LazyReaders = 
    [lf_open(FN) || FN <- TempFNs],

    lf_foreach(LazyReaders, fun(Str) -> 
            io:format(user, "~w~n", [Str]) 
        end),
    mochitemp:rmtempdir(Dir).
    

rand_line(Len) -> 
    Rand = crypto:rand_bytes(10),
    <<Rand/binary, $\n>>.

test_file(Name) ->
    {ok, FD} = file:open(Name, [write]),
    [file:write(FD,  rand_line(10)) || _ <- lists:seq(1, 100)],
    file:close(FD).

bag_test() ->
    Bag1 = bag(),
    Bag2 = add(1, Bag1),
    Bag3 = add(2, Bag2),
    Bag4 = add(1, Bag3),
    Bag5 = add(5, Bag4),
    Bag6 = add(-10, Bag5),
    Bag7 = add(10, Bag6),
    
    ?assertEqual(list(Bag2), [1]),
    ?assertEqual(list(Bag3), [1, 2]),
    ?assertEqual(list(Bag4), [1, 1, 2]),
    ?assertEqual(list(Bag5), [1, 1, 2, 5]),
    ?assertEqual(list(Bag6), [-10, 1, 1, 2, 5]),
    ?assertEqual(list(Bag7), [-10, 1, 1, 2, 5, 10]).


-endif.
