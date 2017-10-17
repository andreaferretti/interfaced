import interfaced

import test_exports

type
  Human = object
    name: string
  Dog = object

proc makeNoise(human: var Human): string =
  "Hello, my name is " & human.name

proc legs(human: var Human): int = 2

proc greet(human: var Human, other: string): string =
  "Nice to meet you, " & other

proc makeNoise(dog: var Dog): string = "Woof! Woof!"

proc legs(dog: var Dog): int = 4

proc greet(dog: var Dog, other: string): string = "Woof! Woooof... wof!?"

createInterface(Animal):
  proc makeNoise(this: Animal): string
  proc legs(this: Animal): int
  proc greet(this: Animal, other: string): string
    
proc interact(animal: Animal) =
  echo animal.makeNoise
  echo animal.greet("James Bond")

proc interactAll(animals: varargs[Animal, toAnimal]) =
  for animal in animals:
    animal.interact()

when isMainModule:
  var
    me = Human(name: "Andrea")
    bau = Dog()

    charmander = Charmander()
    espeon = Espeon()

  for animal in @[me.toAnimal, bau.toAnimal, charmander.toAnimal, espeon.toAnimal]:
    echo "Number of legs: ", legs(animal)
  for pokemon in @[charmander.toPokemon, espeon.toPokemon]:
    echo pokemon.name(), " is a ", pokemon.typ(), " Pokemon"

  interactAll(me, bau, charmander, espeon)
