<?php
header("Content-Type: application/json; charset=UTF-8");

function respond($success, $message, $extra = []) {
    echo json_encode(array_merge([
        "success" => $success,
        "message" => $message
    ], $extra));
    exit;
}

function validate_checkpoint_snapshot($snapshot) {
    if (!is_array($snapshot)) {
        return false;
    }

    $required = [
        "character_class",
        "level",
        "exp",
        "gold",
        "score",
        "current_scene",
        "hp",
        "max_hp",
        "attack",
        "defense",
        "inventory",
        "equipment",
        "player_position_x",
        "player_position_y"
    ];

    foreach ($required as $field) {
        if (!array_key_exists($field, $snapshot)) {
            return false;
        }
    }

    if (!in_array(
        $snapshot["character_class"],
        ["Knight", "Mage", "Thief", "Archer"],
        true
    )) {
        return false;
    }

    $scene = $snapshot["current_scene"];
    if (
        !is_string($scene) ||
        strpos($scene, "..") !== false ||
        strpos($scene, "/battle/") !== false ||
        !preg_match('/^res:\/\/[A-Za-z0-9_ .\/-]+\.tscn$/', $scene)
    ) {
        return false;
    }

    foreach ([
        "level",
        "exp",
        "gold",
        "score",
        "hp",
        "max_hp",
        "attack",
        "defense"
    ] as $field) {
        if (
            !is_int($snapshot[$field]) ||
            $snapshot[$field] < 0 ||
            $snapshot[$field] > 4294967295
        ) {
            return false;
        }
    }

    if (
        $snapshot["level"] < 1 ||
        $snapshot["max_hp"] < 1 ||
        $snapshot["hp"] > $snapshot["max_hp"]
    ) {
        return false;
    }

    foreach (["player_position_x", "player_position_y"] as $field) {
        if (
            (!is_int($snapshot[$field]) && !is_float($snapshot[$field])) ||
            !is_finite((float)$snapshot[$field])
        ) {
            return false;
        }
    }

    if (
        !is_string($snapshot["inventory"]) ||
        !is_string($snapshot["equipment"]) ||
        strlen($snapshot["inventory"]) > 65536 ||
        strlen($snapshot["equipment"]) > 65536
    ) {
        return false;
    }

    foreach (["inventory", "equipment"] as $field) {
        $decoded = json_decode($snapshot[$field]);
        if (
            json_last_error() !== JSON_ERROR_NONE ||
            (!is_array($decoded) && !($decoded instanceof stdClass))
        ) {
            return false;
        }
    }

    return true;
}

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    respond(false, "POST requests only.");
}

$data = json_decode(file_get_contents("php://input"), true);

if (!is_array($data)) {
    respond(false, "Invalid JSON request.");
}

$action = $data["action"] ?? "";
$user_id = filter_var($data["user_id"] ?? null, FILTER_VALIDATE_INT);
$auth_token = $data["auth_token"] ?? "";

error_log(
    "[game_data] request action="
    . (is_scalar($action) ? (string)$action : "invalid")
    . " user_id="
    . ($user_id === false || $user_id === null ? "invalid" : (string)$user_id)
);

if (
    !$user_id ||
    $user_id < 1 ||
    !is_string($auth_token) ||
    !preg_match('/^[a-f0-9]{64}$/', $auth_token)
) {
    respond(false, "Authentication required.");
}

try {
    $pdo = new PDO(
        "mysql:host=127.0.0.1;dbname=rpg_database;charset=utf8mb4",
        "root",
        "",
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );

    $check = $pdo->prepare(
        "SELECT user_id, password_hash FROM users WHERE user_id = ?"
    );
    $check->execute([$user_id]);
    $user = $check->fetch();

    if (!$user) {
        respond(false, "Authentication failed.");
    }

    $expected_token = hash_hmac(
        "sha256",
        "rpg-game-data:" . $user_id,
        $user["password_hash"]
    );

    if (!hash_equals($expected_token, $auth_token)) {
        respond(false, "Authentication failed.");
    }

    // CHECK SAVE
    if ($action === "check_save") {
        $stmt = $pdo->prepare(
            "SELECT user_id
             FROM player_saves
             WHERE user_id = ?
             LIMIT 1"
        );

        $stmt->execute([$user_id]);

        $has_save = ($stmt->fetch() !== false);

        respond(
            true,
            $has_save
                ? "Existing save data found."
                : "No existing save data found.",
            ["has_save" => $has_save]
        );
    }

    if ($action === "get_leaderboard") {
        $count_stmt = $pdo->query("SELECT COUNT(*) FROM users");
        $total_players = (int)$count_stmt->fetchColumn();

        $stmt = $pdo->query(
            "SELECT
                users.username,
                COALESCE(player_saves.score, 0) AS score
             FROM users
             LEFT JOIN player_saves
                ON player_saves.user_id = users.user_id
             ORDER BY score DESC, users.username ASC"
        );

        $leaderboard = [];
        $rank = 0;
        foreach ($stmt->fetchAll() as $row) {
            $rank += 1;
            $score = filter_var($row["score"], FILTER_VALIDATE_INT);
            $leaderboard[] = [
                "rank" => $rank,
                "username" => (string)$row["username"],
                "score" => $score === false || $score === null
                    ? PHP_INT_MAX
                    : max($score, 0)
            ];
        }

        respond(true, "Leaderboard loaded.", [
            "leaderboard" => $leaderboard,
            "total_players" => $total_players
        ]);
    }

    if ($action === "save_checkpoint") {
        $checkpoint = $data["checkpoint"] ?? null;

        if (!validate_checkpoint_snapshot($checkpoint)) {
            respond(false, "Invalid checkpoint data.");
        }

        $checkpoint_json = json_encode(
            $checkpoint,
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES
        );
        $stmt = $pdo->prepare(
            "INSERT INTO player_checkpoints (user_id, checkpoint_data)
             VALUES (?, ?)
             ON DUPLICATE KEY UPDATE
                checkpoint_data = VALUES(checkpoint_data),
                updated_at = CURRENT_TIMESTAMP"
        );
        $stmt->execute([$user_id, $checkpoint_json]);

        respond(true, "Dungeon checkpoint saved.");
    }

    if ($action === "load_checkpoint") {
        $stmt = $pdo->prepare(
            "SELECT checkpoint_data
             FROM player_checkpoints
             WHERE user_id = ?
             LIMIT 1"
        );
        $stmt->execute([$user_id]);
        $row = $stmt->fetch();

        if ($row === false) {
            respond(true, "No dungeon checkpoint found.", [
                "has_checkpoint" => false,
                "checkpoint" => null
            ]);
        }

        $checkpoint = json_decode($row["checkpoint_data"], true);
        if (!validate_checkpoint_snapshot($checkpoint)) {
            respond(false, "Stored checkpoint data is invalid.");
        }

        respond(true, "Dungeon checkpoint loaded.", [
            "has_checkpoint" => true,
            "checkpoint" => $checkpoint
        ]);
    }

    if ($action === "record_death") {
        $exists = $pdo->prepare(
            "SELECT user_id
             FROM player_saves
             WHERE user_id = ?
             LIMIT 1"
        );
        $exists->execute([$user_id]);
        if ($exists->fetch() === false) {
            respond(false, "No player save exists for this account.");
        }

        $stmt = $pdo->prepare(
            "UPDATE player_saves
             SET total_deaths = LEAST(total_deaths + 1, 4294967295)
             WHERE user_id = ?"
        );
        $stmt->execute([$user_id]);

        respond(true, "Death recorded.");
    }

    // DELETE SAVE
    if ($action === "delete_save") {
        $pdo->beginTransaction();
        $checkpoint_stmt = $pdo->prepare(
            "DELETE FROM player_checkpoints
             WHERE user_id = ?"
        );
        $checkpoint_stmt->execute([$user_id]);

        $stmt = $pdo->prepare(
            "DELETE FROM player_saves
             WHERE user_id = ?"
        );

        $stmt->execute([$user_id]);
        $pdo->commit();

        respond(
            true,
            "Existing save data deleted.",
            ["deleted_rows" => $stmt->rowCount()]
        );
    }

    // SAVE CHARACTER
    if ($action === "save_character") {
        $character = $data["character_class"] ?? "";
        $allowed = ["Knight", "Mage", "Thief", "Archer"];

        if (!in_array($character, $allowed, true)) {
            respond(false, "Invalid character choice.");
        }

        $pdo->beginTransaction();
        $checkpoint_stmt = $pdo->prepare(
            "DELETE FROM player_checkpoints
             WHERE user_id = ?"
        );
        $checkpoint_stmt->execute([$user_id]);

        $stmt = $pdo->prepare(
            "INSERT INTO player_saves (user_id, character_class)
             VALUES (?, ?)
             ON DUPLICATE KEY UPDATE
                character_class = VALUES(character_class)"
        );

        $stmt->execute([$user_id, $character]);
        $pdo->commit();

        respond(true, "Character choice saved.");
    }

    // SAVE PROGRESS
    if ($action === "save_progress") {
        $character = $data["character_class"] ?? "";
        $allowed = ["Knight", "Mage", "Thief", "Archer"];

        if (!in_array($character, $allowed, true)) {
            respond(false, "Invalid character choice.");
        }

        $existing_stmt = $pdo->prepare(
            "SELECT
                character_class, level, exp, gold, score, mobs_defeated,
                dungeon_enemies_defeated, bosses_killed, playtime_seconds,
                hp, max_hp, attack, defense, current_scene, boss_completed,
                inventory, equipment, player_position_x, player_position_y,
                total_deaths, puzzle_clear_time, puzzle_time_improvement,
                best_puzzle_clear_time, puzzles_cleared, first_puzzle_clear_time
             FROM player_saves
             WHERE user_id = ?
             LIMIT 1"
        );
        $existing_stmt->execute([$user_id]);
        $existing = $existing_stmt->fetch() ?: [];

        $integer_fields = [
            "level",
            "exp",
            "gold",
            "score",
            "mobs_defeated",
            "dungeon_enemies_defeated",
            "bosses_killed",
            "playtime_seconds",
            "hp",
            "max_hp",
            "attack",
            "defense",
            "total_deaths",
            "puzzles_cleared"
        ];

        $integer_defaults = [
            "level" => 1,
            "exp" => 0,
            "gold" => 0,
            "score" => 0,
            "mobs_defeated" => 0,
            "dungeon_enemies_defeated" => 0,
            "bosses_killed" => 0,
            "playtime_seconds" => 0,
            "hp" => 200,
            "max_hp" => 200,
            "attack" => 30,
            "defense" => 10,
            "total_deaths" => 0,
            "puzzles_cleared" => 0
        ];

        $values = [];

        foreach ($integer_fields as $field) {
            $raw_value = array_key_exists($field, $data)
                ? $data[$field]
                : ($existing[$field] ?? $integer_defaults[$field]);
            $value = filter_var(
                $raw_value,
                FILTER_VALIDATE_INT
            );

            $maximum = in_array($field, [
                "level",
                "mobs_defeated",
                "total_deaths",
                "puzzles_cleared"
            ], true)
                ? 4294967295
                : (in_array($field, [
                    "dungeon_enemies_defeated",
                    "bosses_killed",
                    "hp",
                    "max_hp",
                    "attack",
                    "defense"
                ], true) ? 2147483647 : PHP_INT_MAX);

            if (
                $value === false ||
                $value === null ||
                $value < 0 ||
                $value > $maximum
            ) {
                respond(false, "Invalid value for " . $field . ".");
            }

            $values[$field] = $value;
        }

        foreach ([
            "puzzle_clear_time",
            "puzzle_time_improvement",
            "best_puzzle_clear_time",
            "first_puzzle_clear_time"
        ] as $field) {
            $raw_value = array_key_exists($field, $data)
                ? $data[$field]
                : ($existing[$field] ?? 0.0);
            if (
                !is_numeric($raw_value) ||
                !is_finite((float)$raw_value) ||
                (float)$raw_value < 0.0 ||
                (float)$raw_value > 86400.0
            ) {
                respond(false, "Invalid value for " . $field . ".");
            }
            $values[$field] = (float)$raw_value;
        }

        if ($values["level"] < 1 || $values["max_hp"] < 1) {
            respond(false, "Level and maximum HP must be positive.");
        }

        if ($values["hp"] > $values["max_hp"]) {
            respond(false, "HP cannot exceed maximum HP.");
        }

        $boss_completed = filter_var(
            $data["boss_completed"] ?? ($existing["boss_completed"] ?? false),
            FILTER_VALIDATE_BOOLEAN,
            FILTER_NULL_ON_FAILURE
        );

        if ($boss_completed === null) {
            respond(false, "Invalid boss completion value.");
        }

        $scene = $data["current_scene"]
            ?? ($existing["current_scene"] ?? "res://scenes/maps/world.tscn");

        if (
            !is_string($scene) ||
            !str_starts_with($scene, "res://") ||
            strlen($scene) > 255
        ) {
            respond(false, "Invalid scene path.");
        }

        $position_x = $data["player_position_x"]
            ?? ($existing["player_position_x"] ?? 0);
        $position_y = $data["player_position_y"]
            ?? ($existing["player_position_y"] ?? 0);

        error_log(
            "[game_data] save_progress received coordinates user_id="
            . $user_id
            . " x=" . json_encode($position_x)
            . " y=" . json_encode($position_y)
        );

        if (
            !is_numeric($position_x) ||
            !is_numeric($position_y) ||
            !is_finite((float)$position_x) ||
            !is_finite((float)$position_y) ||
            abs((float)$position_x) > 3.402823466e38 ||
            abs((float)$position_y) > 3.402823466e38
        ) {
            respond(false, "Invalid player position.");
        }

        $inventory = $data["inventory"] ?? ($existing["inventory"] ?? "[]");
        $equipment = $data["equipment"] ?? ($existing["equipment"] ?? "{}");

        if (!is_string($inventory) || !is_string($equipment)) {
            respond(false, "Inventory and equipment must be JSON strings.");
        }
        json_decode($inventory);
        if (json_last_error() !== JSON_ERROR_NONE) {
            respond(false, "Inventory must contain valid JSON.");
        }
        json_decode($equipment);
        if (json_last_error() !== JSON_ERROR_NONE) {
            respond(false, "Equipment must contain valid JSON.");
        }

        $stmt = $pdo->prepare(
            "INSERT INTO player_saves (
                user_id, character_class, level, exp, gold, score,
                mobs_defeated, dungeon_enemies_defeated, bosses_killed,
                playtime_seconds, hp, max_hp, attack, defense,
                current_scene, boss_completed, inventory, equipment,
                player_position_x, player_position_y, total_deaths,
                puzzle_clear_time, puzzle_time_improvement,
                best_puzzle_clear_time, puzzles_cleared,
                first_puzzle_clear_time
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?
            )
            ON DUPLICATE KEY UPDATE
                character_class = VALUES(character_class),
                level = VALUES(level),
                exp = VALUES(exp),
                gold = VALUES(gold),
                score = VALUES(score),
                mobs_defeated = VALUES(mobs_defeated),
                dungeon_enemies_defeated = VALUES(dungeon_enemies_defeated),
                bosses_killed = VALUES(bosses_killed),
                playtime_seconds = VALUES(playtime_seconds),
                hp = VALUES(hp),
                max_hp = VALUES(max_hp),
                attack = VALUES(attack),
                defense = VALUES(defense),
                current_scene = VALUES(current_scene),
                boss_completed = VALUES(boss_completed),
                inventory = VALUES(inventory),
                equipment = VALUES(equipment),
                player_position_x = VALUES(player_position_x),
                player_position_y = VALUES(player_position_y),
                total_deaths = VALUES(total_deaths),
                puzzle_clear_time = VALUES(puzzle_clear_time),
                puzzle_time_improvement = VALUES(puzzle_time_improvement),
                best_puzzle_clear_time = VALUES(best_puzzle_clear_time),
                puzzles_cleared = VALUES(puzzles_cleared),
                first_puzzle_clear_time = VALUES(first_puzzle_clear_time)"
        );

        error_log(
            "[game_data] save_progress before SQL user_id="
            . $user_id
            . " x=" . (string)(float)$position_x
            . " y=" . (string)(float)$position_y
        );

        $stmt->execute([
            $user_id,
            $character,
            $values["level"],
            $values["exp"],
            $values["gold"],
            $values["score"],
            $values["mobs_defeated"],
            $values["dungeon_enemies_defeated"],
            $values["bosses_killed"],
            $values["playtime_seconds"],
            $values["hp"],
            $values["max_hp"],
            $values["attack"],
            $values["defense"],
            $scene,
            $boss_completed ? 1 : 0,
            $inventory,
            $equipment,
            (float)$position_x,
            (float)$position_y,
            $values["total_deaths"],
            $values["puzzle_clear_time"],
            $values["puzzle_time_improvement"],
            $values["best_puzzle_clear_time"],
            $values["puzzles_cleared"],
            $values["first_puzzle_clear_time"]
        ]);

        error_log(
            "[game_data] save_progress SQL succeeded user_id="
            . $user_id
            . " affected_rows=" . $stmt->rowCount()
        );

        respond(true, "Progress saved.", [
            "playtime_seconds" => $values["playtime_seconds"]
        ]);
    }

    // LOAD SAVE
    if ($action === "load_save") {
        $stmt = $pdo->prepare(
            "SELECT
                character_class, level, exp, gold, score,
                mobs_defeated, dungeon_enemies_defeated, bosses_killed,
                playtime_seconds, hp, max_hp, attack, defense,
                current_scene, boss_completed, inventory, equipment,
               player_position_x, player_position_y, total_deaths,
               puzzle_clear_time, puzzle_time_improvement,
               best_puzzle_clear_time, puzzles_cleared,
               first_puzzle_clear_time
            FROM player_saves
             WHERE user_id = ?
             LIMIT 1"
        );

        $stmt->execute([$user_id]);
        $save = $stmt->fetch();

        if ($save === false) {
            error_log(
                "[game_data] load_save found no row for user_id=" . $user_id
            );
            respond(true, "No save found yet.", [
                "has_save" => false,
                "save" => null
            ]);
        }

        error_log(
            "[game_data] load_save coordinates user_id="
            . $user_id
            . " x=" . (string)$save["player_position_x"]
            . " y=" . (string)$save["player_position_y"]
        );

        // Return saved fields at the top level for Godot.
        $save["has_save"] = true;
        $save["boss_completed"] = (bool)$save["boss_completed"];

        respond(true, "Save loaded.", $save);
    }

    // RECORD SCORE
    if ($action === "record_score") {
        $score = filter_var(
            $data["score"] ?? null,
            FILTER_VALIDATE_INT
        );

        if ($score === false || $score === null || $score < 0) {
            respond(false, "Invalid score.");
        }

        $stmt = $pdo->prepare(
            "INSERT INTO score_records (user_id, score)
             VALUES (?, ?)"
        );

        $stmt->execute([$user_id, $score]);

        respond(true, "Score recorded.");
    }

    // UNKNOWN ACTION
    respond(false, "Unknown action.");

} catch (Throwable $e) {
    error_log(
        "[game_data] request failed action="
        . (is_scalar($action) ? (string)$action : "invalid")
        . " user_id=" . (string)$user_id
        . " error=" . $e->getMessage()
    );
    http_response_code(500);

    respond(false, "Server error. Check the PHP error log.");
}
