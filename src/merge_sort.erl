-module(merge_sort).


bag() -> {[], []}.


add(Elem, {[HH|HT] = Head, Tail}) when Elem > HH ->
    add_forward(Elem, Head, Tail);

add(Elem, {Head, Tail}) ->
    add_backward(Elem, Head, Tail).


add_forward(E, [HH|HT], T) when E < HH ->
    add_forward(E, HT, [HH|T]);

add_forward(E, H, T) ->
    {H, [E|T]}.


add_backward(E, H, [HT|TT]) when E > H ->
    add_forward(E, [HT|H], TT);

add_backward(E, [H|T], Acc) ->
    {[E|H], T}.


run(Filename, Parts) ->
    {ok, FD} = file:open(Filename, [read, binary]),
    {ok, Max} = file:position(FD, eof),
    file:position(FD, bof),
    Len = Max div Parts,
    read_part(FD, 0, Len, []).

read_part(FD, Num, Len, Bags) ->
    {Type, Bag} = read_chunk(FD, Len, bag()),
    case Type of
    eof -> 
        Bag;
    eoc ->
        read_part(FD, Num+1, Len, [Bag|Bags])
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


simple_test() ->
    Dir = mochitemp:mkdtemp(),
    TestDataFN = filename:join(Dir, testdata),
    test_file(TestDataFN),
    run(TestDataFN, 10).
    

test_file(Name) ->
   {ok, FD} = file:open(Name, [write]),
   [io:write(FD, [random:uniform(), $\n]) || _ <- lists:seq(1, 10000)],
   file:close(FD).
    
