const SNAKE_MAX_HEALTH = 100
const UP_DIR = (-1, 0)
const DOWN_DIR = (1, 0)
const LEFT_DIR = (0, -1)
const RIGHT_DIR = (0, 1)
const DIRECTIONS = [UP_DIR, RIGHT_DIR, DOWN_DIR, LEFT_DIR]
const SINGLE_PLAYER_MODE = :SINGLE
const MULTI_PLAYER_MODE = :MULTI

mutable struct Snake
    id::Int
    trail        # last element is the head
    health
    alive
    direction
    death_reason
end

const SType = NamedTuple{(:height, :width, :food, :snakes, :ns, :turn, :mode),
    Tuple{Int64,Int64,Array{Tuple{Int,Int},1},Array{Snake,1},Int64,Int64,Symbol}}

function Base.deepcopy_internal(t::Snake, d::IdDict)
    d[t] = Snake(t.id, copy(t.trail), t.health,
        t.alive, t.direction, t.death_reason)
end

mutable struct Cell
    indices::Tuple{Int,Int}
    food::Bool
    snakes # snakes (indices) occupying the cell /
                     # colliding at the cell
    ishead
    istail
    value # any metadata for the display
end

mutable struct Board
    cells::AbstractArray{Cell,2}
    snakes::AbstractArray{Snake,1}
    food
end

mutable struct Game
    board::Board
    turn
    foodtime
    ns
    mode::Symbol
end

mutable struct SnakeEnv
    game::Game
end

single_or_multi(n) = n > 1 ? MULTI_PLAYER_MODE : SINGLE_PLAYER_MODE

SnakeEnv(size::Tuple{Int,Int}, n::Int) =
    SnakeEnv(Game(size, n))

SnakeEnv(st::SType) = SnakeEnv(Game(st))

done(env::SnakeEnv) = done(env.game)
done(g::Game) = g.mode == MULTI_PLAYER_MODE ? g.ns == 1 : g.ns == 0

state(env::SnakeEnv) = gamestate(env.game)
state(env::SnakeEnv, st) = (env.game = Game(st))

Nsnakes(env::SnakeEnv) = Nsnakes(env.game)
function Nsnakes(g::Game)
    return length(snakes(g))
end

function step!(env::SnakeEnv, moves)
    game = env.game
    # # move
    # # up - 1
    # # right - 2
    # # down - 3
    # # left - 4
    # move(game, map(x -> DIRECTIONS[x], moves))
    step!(game, moves)
    r = map(x -> alive(x) ? 1 : 0, snakes(game))
    return state(env), r
end

function reset!(env::SnakeEnv)
    g = env.game
    st = gamestate(g)
    env.game = Game((st[:height], st[:width],), length(snakes(g)))
    return env
end

snakes(c::Cell) = c.snakes
snakes(g::Game) = snakes(g.board)
snakes(b::Board) = b.snakes
hasfood(c::Cell) = c.food
indices(c::Cell) = c.indices
hassnake(c::Cell) = !isempty(snakes(c))
unoccupied(c::Cell) = !hasfood(c) && !hassnake(c)
food!(c::Cell) = (c.food = true)
eat!(c::Cell) = (c.food = false)
function hassnakebody(c::Cell, s::Snake)
    return (id(s) in snakes(c)) && (
        (head(s) != indices(c)) ||
        any(map(x -> x == indices(c), s.trail[1:end-1])))
end

alive(s::Snake) = s.alive
health(s::Snake) = s.health
health(s::Snake, i) = (s.health = i)

Cell(indices) = Cell(indices, false, [], false, false, nothing)
Snake(i) = Snake(i, [], SNAKE_MAX_HEALTH, true, nothing, nothing)
foodtime(t) = t + rand(9:12)
Board() = Board((8, 8))

function Base.:<(s::Snake, w::Snake)
    return length(s) < length(w)
end

function Base.isequal(s::Snake, w::Snake)
    return length(s) == length(w)
end

function Board(state::SType)
    snakes = deepcopy.(state[:snakes])
    food = copy(state[:food])
    c = cells(state[:height], state[:width], snakes, food)
    return Board(c, snakes, food)
end

function cells(state)
    snakes = deepcopy.(state[:snakes])
    food = copy(state[:food])
    return cells(state[:height], state[:width], snakes, food)
end

function cells(r, c)
    cells = Array{Cell, 2}(undef, (r, c))
    @inbounds for j=1:c, i=1:r
        cells[i, j] = Cell((i, j,))
    end
    return cells
end

function cells(r, c, S, food)
    cls = cells(r, c)
    @inbounds for j=1:length(S)
        snake = S[j]
        !snake.alive && continue
        for i in snake.trail
            cell = cls[i...]
            if !in(id(snake), snakes(cell))
                push!(snakes(cell), id(snake))
            end
        end
    end

    @inbounds for i=1:length(food)
        x, y = food[i]
        food!(cls[x, y])
    end

    markends(cls, S, true)
    return cls
end

# Board(board size, number of snakes)
function Board(size, n)
    c = cells(size...)
    snakes = Array{Snake,1}(undef, n)
    @inbounds for i=1:n
        snakes[i] = Snake(i)
    end

    initial_positions(snakes, c)
    Board(c, snakes, create_food(c, n))
end

done(b::Board) = (length(filter(alive, b.snakes)) <= 1)
Game(size, n) = Game(Board(size, n))
function Game(b::Board, t=1, mode=single_or_multi(length(b.snakes)))
    Game(b, t, foodtime(t), count(alive.(b.snakes)), mode)
end

function gamestate(g::Game)
    b = g.board
    r, c = size(b.cells)
    return (height=r, width=r,
        food=b.food, snakes=b.snakes, ns=g.ns, turn=g.turn, mode=g.mode)
end

# peak performance...
function copystate(st::SType)
    return (height=st.height, width=st.width,
        food=copy(st.food), snakes=deepcopy.(st.snakes),
        ns=st.ns, turn=st.turn, mode=st.mode)
end

function Game(state::SType)
    snakes = deepcopy.(state[:snakes])
    food = copy(state[:food])
    c = cells(state[:height], state[:width], snakes, food)
    b = Board(c, snakes, food)
    return Game(b, state[:turn], state[:mode])
end

function pick_cell!(cells::Set{Cell})
    cell = rand(cells)
    pop!(cells, cell)
    return cell
end

in_bounds(i, j, b::Board) = in_bounds(i, j, size(b.cells)...)
in_bounds(i, j, r, c) = (1 <= i <= r) && (1 <= j <= c)

function neighbours(cell::Cell, cells::AbstractArray{Cell, 2})
    r, c = size(cells)
    i, j = cell.indices
    n = neighbours(cell.indices, r, c)
    nc = Array{Cell,1}(undef, length(n))
    @inbounds for i=1:length(n)
        x, y = n[i]
        nc[i] = cells[x, y]
    end
    return nc
end

function neighbours(cell::Tuple{Int,Int}, r, c)
    i, j = cell
    n = []
    for (Δi, Δj) in [(0, 1), (0, -1), (1, 0), (-1, 0)]
        I, J = i + Δi, j + Δj
        if in_bounds(I, J, r, c)
            push!(n, (I, J,))
        end
    end
    return n
end

function Base.push!(snake::Snake, c::Cell)
    if !(id(snake) in snakes(c))
        push!(snakes(c), snake.id)
    end
    push!(snake.trail, indices(c))
end

function Base.push!(snake::Snake, ::Nothing)
    push!(snake.trail, nothing)
end

function removetail!(b::Board, snake::Snake)
    t = tail(snake)
    popfirst!(snake.trail)
    if !all(head(snake) .== t)
        x, y = t
        cell = b.cells[x, y]
        cell.snakes = filter(x -> x != id(snake), cell.snakes)
    end

end

function pick_cells(f, cells, n, delete_neighbours=false)
    free_cells = filter(unoccupied, Set(cells))
    for i=1:n # pick one-by-one to guarentee uniqueness
        cell = pick_cell!(free_cells)
        f(cell, i)

        if delete_neighbours
            n = intersect(free_cells, neighbours(cell, cells))
            foreach(x -> pop!(free_cells, x), n)
        end
    end
end

function initial_positions(snakes::AbstractArray{Snake}, cells)
    pick_cells(cells, length(snakes), true) do cell, i
        @inbounds push!(snakes[i], cell)
    end
end

function create_food(cells, N, foodcells=Tuple{Int,Int}[])
    pick_cells(cells, N) do cell, i
        food!(cell)
        push!(foodcells, indices(cell))
    end
    return foodcells
end

Base.show(io::IO, g::SnakeEnv) = show(io, g.game)
Base.show(io::IO, g::Game) = show(io, g.board)
function Base.show(io::IO, b::Board)
    cells = b.cells
    showcells(io, cells)
end
showcells(io, s::SType) = showcells(io, cells(s[:height], s[:width], s[:snakes], s[:food]))
showcells(cells) = showcells(stdout, cells)


LEGENDS = Dict(
    :empty => " ",
    :unoccupied => "_",
    :food => "O",
    :head => "%",
    :tail => "/",
    :collision => "X",
    )

cellvalue(io, x...) = print(io, LEGENDS[:empty])
cellvalue(io, x::Cell) = print(io, x.value)
function showcell(io, cell)
    if cell.value != nothing
        cellvalue(io, cell)
    elseif unoccupied(cell)
        print(io, LEGENDS[:unoccupied])
    elseif hasfood(cell)
        print(io, LEGENDS[:food])
    else
        s = snakes(cell)
        if length(s) == 1
            if cell.ishead
                print(io, LEGENDS[:head])
            elseif cell.istail
                print(io, LEGENDS[:tail])
            else
                print(io, collect(s)[1])
            end
        else
            print(io, LEGENDS[:collision])
        end
    end
end
function showcells(io, cells)
    r, c = size(cells)
    println(io, "-"^(r + 2))
    for i=1:r
        print(io, "|")
        for j=1:c
            cell = cells[i, j]
            showcell(io, cell)
        end
        println(io, "|")
    end
    println(io, "-"^(r + 2))
end

function step!(g::Game, moves)
    board = g.board

    move(board, moves)

    g.turn += 1
    if g.mode == MULTI_PLAYER_MODE
        if g.turn >= g.foodtime
            a = length(filter(alive, board.snakes))
            n = ceil(Int, a/2)
            board.food = create_food(board.cells, n, board.food)
            g.foodtime = foodtime(g.turn)
        end
    else
        if isempty(board.food)
            board.food = create_food(board.cells, 1, board.food)
        end
    end

    g.ns = count(alive.(snakes(g)))

    return g
end

function move(board::Board, moves)
    snakes = board.snakes

    food = board.food
    cells = board.cells

    markends(board, snakes, false)
    for (s, m) in zip(snakes, moves)
        !alive(s) && continue
        health(s, health(s) - 1)

        s.direction = m
        move(board, s)
        if !in_bounds(head(s)..., board)
            # snake hit a wall
            kill!(board, s, :COLLIDED_WITH_A_WALL)
            continue
        end

        if caneat(board, s)
            health(s, SNAKE_MAX_HEALTH)
        else
            # allow snake to grow to a length of 3 cells
            if length(s) > 3
                removetail!(board, s)
            end

            if health(s) <= 0
                # snake died out of starvation :(
                kill!(board, s, :STARVATION)
            end
        end
    end
    board.food = removefood(board, food)

    handlecollisions(board, snakes)
    markends(board, snakes, true)
end

function handlecollisions(board::Board, S)
    cells = board.cells
    eachsnake(S) do s
        @inbounds cell = cells[head(s)...]

        if length(snakes(cell)) == 1
            H = hassnakebody(cell, s)

            !H && return
            # tried to bite itself
            kill!(board, s, :BIT_ITSELF)
        end
    end

    eachsnake(S) do s
        @inbounds cell = cells[head(s)...]

        L = filter(x -> x != id(s), snakes(cell))
        length(L) == 0 && return

        peers = filter(x -> !in(id(x), L), S)
        if any(map(x -> hassnakebody(cell, x), peers))
            # tried to bite another snake
            kill!(board, s, :BIT_ANOTHER_SNAKE)
            return
        end

        if any(map(x -> s < x, peers)) # it dies
            kill!(board, s, :HEAD_COLLISION)
            return
        end

        if any(map(x -> isequal(s, x), peers)) # everyone dies
            eachsnake(peers) do x
                kill!(board, x, :HEAD_COLLISION)
            end
            return
        end
    end
end

function removefood(board, food)
    fc = Set(food)
    for f in food
        @inbounds cell = board.cells[f...]
        if length(snakes(cell)) != 0
            eat!(cell)
            pop!(fc, f)
        end
    end
    return collect(fc)
end


function move(b::Board, s::Snake)
    d = s.direction
    if d == nothing
        s.direction = d = UP_DIR
    end
    cells = b.cells
    p = head(s) .+ d
    if in_bounds(p..., b)
        @inbounds push!(s, cells[p...])
    else
        push!(s.trail, p)
    end
end

caneat(b::Board, snake) = @inbounds hasfood(b.cells[head(snake)...])

# snake cannot move back
# function canmove(s::Snake, m)
#     return (s.direction == nothing) ||
#      !all(s.direction .== -1 .* m)
# end

function kill!(board::Board, s::Snake, reason)
    !s.alive && return
    # println("Kill: $(id(s)) >> $(reason)")
    cells = board.cells
    t = s.trail
    for i=1:length(t)
        @inbounds x, y = t[i]
        !in_bounds(x, y, board)  && continue
        @inbounds cell = cells[x, y]
        c = snakes(cell)
        !(id(s) in c) && continue
        cell.snakes = c[c .!= id(s)]
    end

    s.alive = false
    s.death_reason = reason
end

head(s::Snake) = s.trail[end]
tail(s::Snake) = s.trail[1]
Base.length(s::Snake) = length(s.trail)
id(s::Snake) = s.id


function eachsnake(f, snakes::AbstractArray{Snake,1})
    l = length(snakes)
    for i=1:l
        @inbounds snake = snakes[i]
        !alive(snake) && continue
        f(snake)
    end
end

markends(b::Board, snakes, v=true) = markends(b.cells, snakes, v)

function markends(cells, S, v=true)
    eachsnake(S) do snake
        tx, ty = tail(snake)
        hx, hy = head(snake)
        @inbounds cells[tx, ty].istail = v
        @inbounds cells[hx, hy].ishead = v
    end
end
