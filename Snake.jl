const SNAKE_MAX_HEALTH = 100
const UP_DIR = (-1, 0)
const DOWN_DIR = (1, 0)
const LEFT_DIR = (0, -1)
const RIGHT_DIR = (0, 1)
const DIRECTIONS = [UP_DIR, RIGHT_DIR, DOWN_DIR, LEFT_DIR]

mutable struct Snake
    id::Int
    trail        # last element is the head
    health
    alive
    direction
    death_reason
end

mutable struct Cell
    indices::Tuple{Int,Int}
    food::Bool
    snakes::BitSet # snakes (indices) occupying the cell /
                     # colliding at the cell
    ishead
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
    gameover
end

mutable struct SnakeEnv
    game
end

SnakeEnv(size, n) = SnakeEnv(Game(size, n))

done(env::SnakeEnv) = env.game.gameover
state(env::SnakeEnv) = gamestate(env.game)
state(env::SnakeEnv, st) = (env.game = Game(st))


function step!(env::SnakeEnv, moves)
    game = env.game
    # # move 
    # # up - 1
    # # right - 2
    # # down - 3
    # # left - 4
    # move(game, map(x -> DIRECTIONS[x], moves))
    move(game, moves)
    r = map(x -> alive(x) ? 1 : 0, snakes(game))
    return state(env), r
end

function reset!(env::SnakeEnv)
    st = gamestate(env)
    env.game = Game((st[:height], st[:width],), length(snakes(env)))
    return env
end

snakes(c::Cell) = c.snakes
snakes(g::Game) = snakes(g.board)
snakes(b::Board) = b.snakes
hasfood(c::Cell) = c.food
indices(c::Cell) = c.indices
unoccupied(c::Cell) = !hasfood(c) && length(snakes(c)) == 0
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

Cell(indices) = Cell(indices, false, BitSet(), false)
Snake(i) = Snake(i, [], SNAKE_MAX_HEALTH, true, nothing, nothing)
foodtime(t) = t + rand(9:12)
Board() = Board((8, 8))

function cells(r, c)
    cells = Array{Cell, 2}(undef, (r, c))
    for i=1:r, j=1:c
        cells[i, j] = Cell((i, j,))
    end
    return cells
end

function cells(r, c, S, food)
    cls = cells(r, c)
    for snake in S
        !snake.alive && continue
        for i in snake.trail
            cell = cls[i...]
            push!(snakes(cell), id(snake))
        end
    end
    for i in food
        food!(cls[i...])
    end
    return cls
end

# Board(board size, number of snakes)
function Board(size, n)
    c = cells(size...)
    snakes = Array{Snake,1}(undef, n)
    for i=1:n
        snakes[i] = Snake(i)
    end

    initial_positions(snakes, c)
    Board(c, snakes, create_food(c, n))
end

done(b::Board) = (length(filter(alive, b.snakes)) <= 1)
Game(size, n) = Game(Board(size, n))
Game(b::Board, t=1) = Game(b, t, foodtime(t), done(b))

function gamestate(g::Game)
    b = g.board
    r, c = size(b.cells)
    return deepcopy((height=r, width=r,
        food=b.food, snakes=b.snakes, done=g.gameover, turn=g.turn))
end

function Game(state::NamedTuple)
    snakes = deepcopy(state[:snakes])
    food = deepcopy(state[:food])
    c = cells(state[:height], state[:width], snakes, food)
    b = Board(c, snakes, food)
    markheads(b, snakes, true)
    return Game(b, state[:turn])
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
    neighbours = Set{Cell}()
    for (Δi, Δj) in [(0, 1), (0, -1), (1, 0), (-1, 0)]
        I, J = i + Δi, j + Δj
        if in_bounds(I, J, r, c)
            @inbounds m = cells[I, J]
            push!(neighbours, m)
        end
    end
    return neighbours
end

function Base.push!(snake::Snake, c::Cell)
    push!(snakes(c), snake.id)
    push!(snake.trail, indices(c))
end

function Base.push!(snake::Snake, ::Nothing)
    push!(snake.trail, nothing)
end

function removetail!(b::Board, snake::Snake)
    t = tail(snake)
    popfirst!(snake.trail)
    if !all(head(snake) .== t)
        pop!(snakes(b.cells[t...]), id(snake))
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
        push!(snakes[i], cell)
    end
end

function create_food(cells, N, foodcells = Set())
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
    r, c = size(cells)
    println(io, "-"^(r + 2))
    for i=1:r
        print(io, "|")
        for j=1:c
            cell = cells[i, j]
            if unoccupied(cell)
                print(io, "_")
            elseif hasfood(cell)
                print(io, "O")
            else
                s = snakes(cell)
                if length(s) == 1
                    if cell.ishead
                        print(io, "%")
                    else    
                        print(io, collect(s)[1])
                    end
                else
                    print(io, "X")
                end
            end
        end
        println(io, "|")
    end
    println(io, "-"^(r + 2))
end

function move(g::Game, moves)

    board = g.board
    snakes = board.snakes

    
    food = board.food
    cells = board.cells

    markheads(board, snakes, false)
    for (s, m) in zip(snakes, moves)
        !alive(s) && continue
        health(s, health(s) - 1)

        if canmove(s, m)
            s.direction = m
        end

        move(board, s)

        if head(s) == nothing
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
    removefood(board, food)

    handlecollisions(board, snakes)

    g.turn += 1
    if g.turn >= g.foodtime
        a = length(filter(alive, snakes))
        n = ceil(Int, a/2)
        board.food = create_food(cells, n, food)
        g.foodtime = foodtime(g.turn)
    end

    g.gameover = done(board)
    markheads(board, snakes, true)

    return g
end

function handlecollisions(board::Board, S)
    for s in S
        !alive(s) && continue

        cell = board.cells[head(s)...]

        if length(snakes(cell)) == 1
            H = hassnakebody(cell, s)

            !H && continue
            # tried to bite itself
            kill!(board, s, :BIT_ITSELF)
            continue
        end

        L = collect(snakes(cell))
        peers = S[L] # includes `s`
        if any(map(x -> hassnakebody(cell, x), peers))
            # tried to bite another snake
            kill!(board, s, :BIT_ANOTHER_SNAKE)
            continue
        end


        G = peers[length.(peers) .>= length(s)]
        length(G) == 1 && continue # `s` is the biggest snake

        if any(length.(G) .> length(s)) || any(health.(G) .> health(s))
            kill!(board, s, :HEAD_COLLISION) # `s` is not the biggest snake :/
            continue
        end

        # randomly pick a survivor
        
        survivor = rand(peers)
        foreach(x -> x != survivor ?
            kill!(board, x, :HEAD_COLLISION) : nothing, peers)

    end
end

function removefood(board, food)
    fc = collect(food)
    for f in fc
        cell = board.cells[f...]
        if length(snakes(cell)) != 0
            eat!(cell)
            pop!(food, f)
        end
    end
end


function move(b::Board, s::Snake)
    d = s.direction
    if d == nothing
        s.direction = d = UP_DIR
    end
    cells = b.cells
    p = head(s) .+ d
    if in_bounds(p..., b)
        push!(s, cells[p...])
    else
        push!(s, nothing)
    end
end

caneat(b::Board, snake) = hasfood(b.cells[head(snake)...])

# snake cannot move back
function canmove(s::Snake, m)
    return (s.direction == nothing) ||
     !all(s.direction .== -1 .* m)
end

function kill!(board::Board, s::Snake, reason)
    !s.alive && return
    println("Kill: $(id(s)) >> $(reason)")
    cells = board.cells
    for i in collect(s.trail)
        i == nothing && continue
        c = snakes(cells[i...])
        !(id(s) in c) && continue
        pop!(c, id(s))
    end

    s.alive = false
    s.death_reason = reason
end

head(s::Snake) = s.trail[end]
tail(s::Snake) = s.trail[1]
Base.length(s::Snake) = length(s.trail)
id(s::Snake) = s.id


function markheads(b::Board, snakes, v=true)
    cells = b.cells
    for snake in snakes
        !alive(snake) && continue
        cells[head(snake)...].ishead = v
    end
end
