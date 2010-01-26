-module(fillMp3).

-include_lib("kernel/include/file.hrl").

-export([
        fill/3
    ]).

fill(DirtyPath, FillPath, Size) ->
    Path = DirtyPath ++ "/",

    %Artists = getSubDir(Path),
    %SLOW!
    Albums = findAlbums(Path),

    VerboseAlbums = [{P, recursive_size(P)} || P <- Albums],

    RandomAlbums = select_music(VerboseAlbums, Size),

    [recursive_copy(F, FillPath) || {string, F} <- RandomAlbums],
    ok.

%=============
%This code is from #erlang @ freenode under the DWTFYWI license
%TODO: Update code to keep folder structure
recursive_copy(From, To) ->
    {ok, Files} = file:list_dir(From),
    [ok = rec_copy1(From, To, X) || X <- Files],
    ok.

% ignore hidden
rec_copy1(_From, _To, [$. | _T]) ->
    ok;
rec_copy1(From, To, File) ->

    NewFrom = filename:join(From, File),
    NewTo   = filename:join(To, File),

    case filelib:is_dir(NewFrom) of

        true  ->
            ok = filelib:ensure_dir(NewTo),
            recursive_copy(NewFrom, NewTo);

        false ->
            case filelib:is_file(NewFrom) of
                true  ->
                    ok = filelib:ensure_dir(NewTo),
                    {ok, _} = file:copy(NewFrom, NewTo),
                    ok;
                false ->
                    ok
            end
    end.
%============


%TODO Will fill to size_left - 100Mb
select_music(Albums, SizeGig) ->
    SizeByte = SizeGig * 1024 * 1024 * 1024,
    select_music(Albums, SizeByte, []).
select_music(Albums, SizeLeft, Ack) when SizeLeft > 104857600 ->
    %pick album
    Elem = random:uniform(length(Albums)),
    {Album, Size} = lists:nth(Elem, Albums),

    %remove and calculate new size left
    NewAlbums = lists:delete({Album, Size}, Albums),
    NewSize = SizeLeft - Size,
    NewAck = [Album | Ack],
    select_music(NewAlbums, NewSize, NewAck);
select_music(_, _, Ack) ->
    Ack.

findAlbums(Path) ->
    AlbumsFlatt = lists:flatten(getBottomFolder(Path, Path)),
    removeDups(AlbumsFlatt).

removeDups([Head | List]) ->
    removeDupsHelper(List, [Head]).

removeDupsHelper([], Ack) ->
    Ack;
removeDupsHelper([ignore | Tail], Ack) ->
    removeDupsHelper(Tail, Ack);
removeDupsHelper([Head | Tail], Ack) ->
    case lists:member(Head, Tail) of
        true ->
            removeDupsHelper(Tail, Ack);
        false ->
            removeDupsHelper(Tail, [Head | Ack])
    end.

getBottomFolder(ParentPath, Path) ->
    {ok, FileInfo} = file:read_file_info(Path),
    case FileInfo#file_info.type of
        directory ->
            SubTree = getSubDir(Path),
            [getBottomFolder(Path,X) || X <- SubTree];
        regular ->
            % is this really the bottom?
            {ok, Dir} = file:list_dir(ParentPath),
            case isBottomDir(ParentPath, Dir) of
                true ->
                    {string, ParentPath};
                false ->
                    ignore
            end
    end.

isBottomDir(_, []) -> true;
isBottomDir(Path, [File | Dir]) ->
    {ok, FileInfo} = file:read_file_info(Path ++ "/" ++ File),
    case FileInfo#file_info.type of
        directory ->
            false;
        regular ->
            isBottomDir(Path, Dir)
    end.

getSubDir(Path) ->
    {ok, Dir} = file:list_dir(Path),
    [Path ++ "/" ++ X || X <- Dir].

recursive_size({string, Path}) ->
    {ok, FileInfo} = file:read_file_info(Path),
    case FileInfo#file_info.type of
        directory ->
            {ok, Content} = file:list_dir(Path),
            ContentSize = lists:sum([recursive_size({string, Path ++ "/" ++ C}) || C <- Content]),
            ContentSize + FileInfo#file_info.size;
        regular ->
            FileInfo#file_info.size
    end;
recursive_size(Fail) when is_integer(Fail) ->
    0.
