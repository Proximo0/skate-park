extends TestCase

const WALLET_TMP: String = "user://test_wallet_tmp.json"


func test_starts_with_money_for_a_few_items() -> void:
	var w: Wallet = Wallet.new()
	assert_eq(w.coins, Wallet.START_COINS)
	assert_true(Wallet.START_COINS >= 100, "enough for 2-3 items")


func test_starter_items_are_owned() -> void:
	var w: Wallet = Wallet.new()
	assert_true(w.owns("deck_popsicle"))
	assert_false(w.owns("deck_oldschool"))


func test_buy_spends_coins_and_owns() -> void:
	var w: Wallet = Wallet.new()
	var price: int = int(PartCatalog.load_default().item("shoes_cupsole")["price"])
	assert_true(w.buy("shoes_cupsole"))
	assert_eq(w.coins, Wallet.START_COINS - price)
	assert_true(w.owns("shoes_cupsole"))
	assert_false(w.buy("shoes_cupsole"), "already owned")
	assert_eq(w.coins, Wallet.START_COINS - price, "no second charge")


func test_cannot_buy_without_enough_coins() -> void:
	var w: Wallet = Wallet.new()
	w.coins = 10
	assert_false(w.buy("deck_oldschool"))
	assert_eq(w.coins, 10)
	assert_false(w.owns("deck_oldschool"))
	assert_false(w.buy("no_such_item"))


func test_coins_for_combo() -> void:
	assert_eq(Wallet.coins_for_combo(0), 0)
	assert_eq(Wallet.coins_for_combo(50), 1, "small combos still pay one coin")
	assert_eq(Wallet.coins_for_combo(1000), 10)
	assert_eq(Wallet.coins_for_combo(1000000), Wallet.MAX_COINS_PER_COMBO)


func test_add_never_goes_negative() -> void:
	var w: Wallet = Wallet.new()
	w.add(30)
	assert_eq(w.coins, Wallet.START_COINS + 30)
	w.add(-100000)
	assert_eq(w.coins, 0)


func test_save_and_load_round_trip() -> void:
	var w: Wallet = Wallet.new()
	w.add(55)
	w.buy("wheel_park_54")
	assert_true(w.save(WALLET_TMP))
	var back: Wallet = Wallet.load_file(WALLET_TMP)
	assert_eq(back.coins, w.coins)
	assert_true(back.owns("wheel_park_54"))
	assert_false(back.owns("truck_hollow"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WALLET_TMP))


func test_missing_file_gives_fresh_wallet() -> void:
	var w: Wallet = Wallet.load_file("user://no_such_wallet_file.json")
	assert_eq(w.coins, Wallet.START_COINS)
