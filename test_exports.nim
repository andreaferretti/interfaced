import interfaced

type
    PokemonType* {.pure.} = enum
        Fire, Psychic # ...

    Charmander* = object
    Espeon* = object

proc makeNoise*(this: Charmander): string = "Charmander, Charmander"
proc legs*(this: Charmander): int = 2
proc greet*(this: Charmander, other: string): string = "Charmander, Char, Charmander... (" & other & ")"

proc makeNoise*(this: Espeon): string = "By using Telepathy I'm able to communicate with creatures of other species"
proc legs*(this: Espeon): int = 4
proc greet*(this: Espeon, other: string): string = "What a pleasure to meet you, " & other

createInterface *Pokemon:
    proc name*(this: Pokemon): string
    proc typ*(this: Pokemon): PokemonType

proc name*(this: Espeon): string = "Espeon"
proc typ*(this: Espeon): PokemonType = PokemonType.Psychic

proc name*(this: Charmander): string = "Charmander"
proc typ*(this: Charmander): PokemonType = PokemonType.Fire
