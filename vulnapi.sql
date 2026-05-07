-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 04, 2026 at 03:30 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `vulnapi`
--

-- --------------------------------------------------------

--
-- Table structure for table `notes`
--

CREATE TABLE `notes` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notes`
--

INSERT INTO `notes` (`id`, `user_id`, `title`, `body`, `created_at`, `updated_at`) VALUES
(1, 2, 'Alice\'s Shopping List', 'Milk, Eggs, Bread, Butter', '2026-05-02 16:26:56', '2026-05-02 16:26:56'),
(2, 2, 'Alice\'s Secret Diary', 'Today I learned about SQL injection...', '2026-05-02 16:26:56', '2026-05-02 16:26:56'),
(3, 3, 'Bob\'s Bank Account', 'Account number: 12345678, Routing: 987654321', '2026-05-02 16:26:56', '2026-05-02 16:26:56'),
(4, 3, 'Bob\'s Passwords', 'Email: password123, Bank: mybankpassword', '2026-05-02 16:26:56', '2026-05-02 16:26:56'),
(5, 1, 'Admin Note', 'This is a super secret admin note', '2026-05-02 16:26:56', '2026-05-02 16:26:56');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('user','admin') DEFAULT 'user',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password`, `role`, `created_at`, `updated_at`) VALUES
(1, 'Admin User', 'admin@vulnapi.com', '$2y$10$QI18pCWiz.bDx4DCeEE7oehNHmVJLmvtuJ7lH/VRNbdNxZqcPYSpW', 'admin', '2026-05-02 16:26:56', '2026-05-02 16:37:27'),
(2, 'Alice Johnson', 'alice@example.com', '$2y$10$CUrj1TDtImeYrCByU8jwPOE9VPRo0RjCQBRz.b/0tGy5U2/a.c.bG', 'user', '2026-05-02 16:26:56', '2026-05-02 16:43:18'),
(3, 'Bob Smith', 'bob@example.com', '$2y$10$CUrj1TDtImeYrCByU8jwPOE9VPRo0RjCQBRz.b/0tGy5U2/a.c.bG', 'user', '2026-05-02 16:26:56', '2026-05-02 16:43:26'),
(4, 'Charlie Brown', 'charlie@example.com', '$2y$10$CUrj1TDtImeYrCByU8jwPOE9VPRo0RjCQBRz.b/0tGy5U2/a.c.bG', 'user', '2026-05-02 16:26:56', '2026-05-02 16:43:33');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `notes`
--
ALTER TABLE `notes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `notes`
--
ALTER TABLE `notes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `notes`
--
ALTER TABLE `notes`
  ADD CONSTRAINT `notes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
