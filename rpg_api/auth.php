
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
$username = trim($data["username"] ?? "");
$password = $data["password"] ?? "";

if ($username === "" || $password === "") {
    respond(false, "Username and password are required.");
}

if (!preg_match('/^[A-Za-z0-9_]{3,30}$/', $username)) {
    respond(false, "Username must be 3-30 characters and use only letters, numbers, or underscores.");
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

    if ($action === "register") {
        if (strlen($password) < 8) {
            respond(false, "Password must be at least 8 characters.");
        }

        $password_hash = password_hash($password, PASSWORD_DEFAULT);

        try {
            $stmt = $pdo->prepare(
                "INSERT INTO users (username, password_hash)
                 VALUES (:username, :password_hash)"
            );

            $stmt->execute([
                "username" => $username,
                "password_hash" => $password_hash
            ]);

            respond(true, "Account created successfully. You can now log in.");

        } catch (PDOException $e) {
            if ($e->getCode() === "23000") {
                respond(false, "That username is already taken.");
            }
            throw $e;
        }

    } elseif ($action === "login") {
        $stmt = $pdo->prepare(
            "SELECT user_id, username, password_hash
             FROM users
             WHERE username = :username
             LIMIT 1"
        );

        $stmt->execute(["username" => $username]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user["password_hash"])) {
            respond(false, "Incorrect username or password.");
        }

        $update = $pdo->prepare(
            "UPDATE users SET last_login = NOW()
             WHERE user_id = :user_id"
        );

        $update->execute(["user_id" => $user["user_id"]]);

        $auth_token = hash_hmac(
            "sha256",
            "rpg-game-data:" . $user["user_id"],
            $user["password_hash"]
        );

        respond(true, "Login successful!", [
            "user_id" => (int) $user["user_id"],
            "username" => $user["username"],
            "auth_token" => $auth_token
        ]);

    } else {
        respond(false, "Unknown action.");
    }

} catch (Throwable $e) {
    error_log($e->getMessage());
    http_response_code(500);
    respond(false, "Server error. Check your PHP error log.");
}
