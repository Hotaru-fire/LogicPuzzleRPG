-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Oct 29, 2026 at 09:09 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `rpg_database`
--

-- --------------------------------------------------------

--
-- Table structure for table `player_checkpoints`
--

CREATE TABLE `player_checkpoints` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `checkpoint_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`checkpoint_data`)),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `player_checkpoints`
--

INSERT INTO `player_checkpoints` (`user_id`, `checkpoint_data`, `updated_at`) VALUES
(1, '{\"attack\":30,\"best_puzzle_clear_time\":0,\"boss_completed\":false,\"bosses_killed\":0,\"character_class\":\"Mage\",\"current_scene\":\"res://scenes/maps/dungeon_1.tscn\",\"defense\":10,\"dungeon_enemies_defeated\":4,\"equipment\":\"{}\",\"exp\":0,\"first_puzzle_clear_time\":0,\"gold\":32,\"hp\":200,\"inventory\":\"[]\",\"level\":2,\"max_hp\":200,\"mobs_defeated\":0,\"player_position_x\":652.77197265625,\"player_position_y\":451.861999511719,\"playtime_seconds\":68,\"puzzle_clear_time\":0,\"puzzle_time_improvement\":0,\"puzzles_cleared\":0,\"score\":40,\"total_deaths\":0}', '2026-10-29 08:01:44');

-- --------------------------------------------------------

--
-- Table structure for table `player_saves`
--

CREATE TABLE `player_saves` (
  `save_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `character_class` varchar(30) NOT NULL DEFAULT '',
  `level` int(10) UNSIGNED NOT NULL DEFAULT 1,
  `exp` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `gold` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `score` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `mobs_defeated` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `playtime_seconds` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `hp` int(11) NOT NULL DEFAULT 200,
  `max_hp` int(11) NOT NULL DEFAULT 200,
  `attack` int(11) NOT NULL DEFAULT 30,
  `defense` int(11) NOT NULL DEFAULT 10,
  `current_scene` varchar(255) NOT NULL DEFAULT 'res://scenes/world.tscn',
  `boss_completed` tinyint(1) NOT NULL DEFAULT 0,
  `inventory` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '[]' CHECK (json_valid(`inventory`)),
  `equipment` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '{}' CHECK (json_valid(`equipment`)),
  `player_position_x` float NOT NULL DEFAULT 0,
  `player_position_y` float NOT NULL DEFAULT 0,
  `dungeon_enemies_defeated` int(11) NOT NULL DEFAULT 0,
  `bosses_killed` int(11) NOT NULL DEFAULT 0,
  `total_deaths` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `puzzle_clear_time` float NOT NULL DEFAULT 0,
  `puzzle_time_improvement` float NOT NULL DEFAULT 0,
  `best_puzzle_clear_time` float NOT NULL DEFAULT 0,
  `puzzles_cleared` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `first_puzzle_clear_time` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `player_saves`
--

INSERT INTO `player_saves` (`save_id`, `user_id`, `character_class`, `level`, `exp`, `gold`, `score`, `mobs_defeated`, `playtime_seconds`, `updated_at`, `hp`, `max_hp`, `attack`, `defense`, `current_scene`, `boss_completed`, `inventory`, `equipment`, `player_position_x`, `player_position_y`, `dungeon_enemies_defeated`, `bosses_killed`, `total_deaths`, `puzzle_clear_time`, `puzzle_time_improvement`, `best_puzzle_clear_time`, `puzzles_cleared`, `first_puzzle_clear_time`) VALUES
(60, 1, 'Mage', 2, 0, 32, 40, 0, 68, '2026-10-29 08:01:46', 200, 200, 30, 10, 'res://scenes/maps/dungeon_1.tscn', 0, '[]', '{}', 652.772, 451.862, 4, 0, 0, 0, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `score_records`
--

CREATE TABLE `score_records` (
  `score_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `score` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `username` varchar(30) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `username`, `password_hash`, `created_at`, `last_login`) VALUES
(1, 'cyemon', '$2y$10$turPCvZ1S6TUJnEgXXyzvOgXxrjDeNeFAWGilzpqXKS92/gH5WIYC', '2026-10-16 09:06:55', '2026-10-29 16:00:25');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `player_checkpoints`
--
ALTER TABLE `player_checkpoints`
  ADD PRIMARY KEY (`user_id`);

--
-- Indexes for table `player_saves`
--
ALTER TABLE `player_saves`
  ADD PRIMARY KEY (`save_id`),
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `score_records`
--
ALTER TABLE `score_records`
  ADD PRIMARY KEY (`score_id`),
  ADD KEY `idx_score_user` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `player_saves`
--
ALTER TABLE `player_saves`
  MODIFY `save_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT for table `score_records`
--
ALTER TABLE `score_records`
  MODIFY `score_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `player_checkpoints`
--
ALTER TABLE `player_checkpoints`
  ADD CONSTRAINT `fk_player_checkpoints_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `player_saves`
--
ALTER TABLE `player_saves`
  ADD CONSTRAINT `fk_player_saves_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `score_records`
--
ALTER TABLE `score_records`
  ADD CONSTRAINT `fk_score_records_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
