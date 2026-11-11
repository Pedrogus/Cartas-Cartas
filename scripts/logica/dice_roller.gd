class_name DiceRoller
extends RefCounted
## DiceRoller (sem autoload). Único ponto de sorteio do jogo.
## Uso: DiceRoller.d20(), DiceRoller.rolar(2, 4), DiceRoller.d20_vantagem()

static var _rng := RandomNumberGenerator.new()


## Fixa a semente: a mesma sequência se repete. Usado nos testes.
static func definir_semente(semente: int) -> void:
	_rng.seed = semente


## Volta a sortear de verdade (semente aleatória).
static func aleatorizar() -> void:
	_rng.randomize()


static func d20() -> int:
	return _rng.randi_range(1, 20)


## Rola 2d20 e fica com o maior.
static func d20_vantagem() -> int:
	return maxi(d20(), d20())


## Rola 2d20 e fica com o menor.
static func d20_desvantagem() -> int:
	return mini(d20(), d20())


## Soma de qtd dados de "faces" lados. Ex.: rolar(2, 4) = 2d4.
static func rolar(qtd: int, faces: int) -> int:
	if qtd <= 0 or faces <= 0:
		return 0
	var total := 0
	for i in qtd:
		total += _rng.randi_range(1, faces)
	return total


## Embaralha a lista no lugar (Fisher-Yates), usando o mesmo sorteador (respeita a semente).
static func embaralhar(lista: Array) -> void:
	for i in range(lista.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp: Variant = lista[i]
		lista[i] = lista[j]
		lista[j] = temp
