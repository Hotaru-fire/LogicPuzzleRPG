<?php
header("Content-Type: application/json; charset=UTF-8");

function respond($success, $message, $extra = []) {
    echo json_encode(array_merge([
        "success" => $success,
        "message" => $message
    ], $extra));
    exit;
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

error_log(
    "[game_data] request action="
    . (is_scalar($action) ? (string)$action : "invalid")
    . " user_id="
    . ($user_id === false || $user_id === null ? "invalid" : (string)$user_id)
);

if (!$user_id || $user_id < 1) {
    respond(false, "Invalid user ID.");
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
        "SELECT user_id FROM users WHERE user_id = ?"
    );
    $check->execute([$user_id]);

    if (!$check->fetch()) {
        respond(false, "User account not found.");
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

    // DELETE SAVE
    if ($action === "delete_save") {
        $stmt = $pdo->prepare(
            "DELETE FROM player_saves
             WHERE user_id = ?"
        );

        $stmt->execute([$user_id]);

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

        $stmt = $pdo->prepare(
            "INSERT INTO player_saves (user_id, character_class)
             VALUES (?, ?)
             ON DUPLICATE KEY UPDATE
                character_class = VALUES(character_class)"
        );

        $stmt->execute([$user_id, $character]);

        respond(true, "Character choice saved.");
    }

    // SAVE PROGRESS
    if ($action === "save_progress") {
        $character = $data["character_class"] ?? "";
        $allowed = ["Knight", "Mage", "Thief", "Archer"];

        if (!in_array($character, $allowed, true)) {
            respond(false, "Invalid character choice.");
        }

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
            "defense"
        ];

        $values = [];

        foreach ($integer_fields as $field) {
            $value = filter_var(
                $data[$field] ?? null,
                FILTER_VALIDATE_INT
            );

            if ($value === false || $value === null || $value < 0) {
                respond(false, "Invalid value for " . $field . ".");
            }

            $values[$field] = $value;
        }

        if ($values["level"] < 1 || $values["max_hp"] < 1) {
            respond(false, "Level and maximum HP must be positive.");
        }

        if ($values["hp"] > $values["max_hp"]) {
            respond(false, "HP cannot exceed maximum HP.");
        }

        $boss_completed = filter_var(
            $data["boss_completed"] ?? false,
            FILTER_VALIDATE_BOOLEAN,
            FILTER_NULL_ON_FAILURE
        );

        if ($boss_completed === null) {
            respond(false, "Invalid boss completion value.");
        }

        $scene = $data["current_scene"] ?? "res://scenes/maps/world.tscn";

        if (
            !is_string($scene) ||
            !str_starts_with($scene, "res://") ||
            strlen($scene) > 255
        ) {
            respond(false, "Invalid scene path.");
        }

        $position_x = $data["player_position_x"] ?? null;
        $position_y = $data["player_position_y"] ?? null;

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
            !is_finite((float)$position_y)
        ) {
            respond(false, "Invalid player position.");
        }

        $inventory = $data["inventory"] ?? "[]";
        $equipment = $data["equipment"] ?? "{}";

        if (!is_string($inventory) || !is_string($equipment)) {
            respond(false, "Inventory and equipment must be JSON strings.");
        }

        $stmt = $pdo->prepare(
            "INSERT INTO player_saves (
                user_id, character_class, level, exp, gold, score,
                mobs_defeated, dungeon_enemies_defeated, bosses_killed,
                playtime_seconds, hp, max_hp, attack, defense,
                current_scene, boss_completed, inventory, equipment,
                player_position_x, player_position_y
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
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
                player_position_y = VALUES(player_position_y)"
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
            (float)$position_y
        ]);

        error_log(
            "[game_data] save_progress SQL succeeded user_id="
            . $user_id
            . " affected_rows=" . $stmt->rowCount()
        );

        respond(true, "Progress saved.");
    }

    // LOAD SAVE
    if ($action === "load_save") {
        $stmt = $pdo->prepare(
            "SELECT
                character_class, level, exp, gold, score,
                mobs_defeated, dungeon_enemies_defeated, bosses_killed,
                playtime_seconds, hp, max_hp, attack, defense,
                current_scene, boss_completed, inventory, equipment,
                player_position_x, player_position_y
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
