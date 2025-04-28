#!/usr/bin/env python3
"""
Unit tests for the UserManager class.
"""

import unittest
from unittest.mock import patch
import sys
import os

# Add src directory to sys.path to allow importing src modules
sys.path.insert(
    0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "src"))
)

# Now import the class to be tested
from users import UserManager

# Define constants used by UserManager for file paths
MOCK_USERS_FILE = "mock_users.json"
MOCK_ADMINS_FILE = "mock_admins.json"


# Keep file path patches at class level
@patch("users.USERS_FILE", MOCK_USERS_FILE)
@patch("users.ADMINS_FILE", MOCK_ADMINS_FILE)
class TestUserManager(unittest.TestCase):
    # Apply mocks for load/save to each test method individually
    # using method decorators to ensure they are active before instance creation inside the test.
    # This avoids issues with setUp timing.

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_initialization_loading(self, mock_load_json, mock_save_json):
        """Test that users and admins are loaded correctly during init."""

        # Configure mock loader
        def load_side_effect(filename, default):
            if filename == MOCK_USERS_FILE:
                return [100, 200]
            elif filename == MOCK_ADMINS_FILE:
                return [100]
            return default

        mock_load_json.side_effect = load_side_effect

        # Instantiate UserManager
        user_manager = UserManager()

        # Assert calls during init
        self.assertEqual(mock_load_json.call_count, 2)
        mock_load_json.assert_any_call(MOCK_USERS_FILE, [])
        mock_load_json.assert_any_call(MOCK_ADMINS_FILE, [])

        # Check internal lists
        self.assertEqual(user_manager.users, [100, 200])
        self.assertEqual(user_manager.admins, [100])
        # Ensure save wasn't called during init
        mock_save_json.assert_not_called()

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_add_user_new(self, mock_load_json, mock_save_json):
        """Test adding a completely new user."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        new_user_id = 300
        initial_users = user_manager.users.copy()

        # --- Act ---
        result = user_manager.add_user(new_user_id)

        # --- Assert ---
        self.assertTrue(result)
        self.assertIn(new_user_id, user_manager.users)
        self.assertNotEqual(initial_users, user_manager.users)
        mock_save_json.assert_called_once_with(MOCK_USERS_FILE, user_manager.users)

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_add_user_existing(self, mock_load_json, mock_save_json):
        """Test adding a user who already exists."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        existing_user_id = 200
        initial_users = user_manager.users.copy()

        # --- Act ---
        result = user_manager.add_user(existing_user_id)

        # --- Assert ---
        self.assertFalse(result)
        self.assertEqual(initial_users, user_manager.users)
        mock_save_json.assert_not_called()

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_add_admin_new(self, mock_load_json, mock_save_json):
        """Test adding a new admin."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        new_admin_id = 200
        initial_admins = user_manager.admins.copy()

        # --- Act ---
        result = user_manager.add_admin(new_admin_id)

        # --- Assert ---
        self.assertTrue(result)
        self.assertIn(new_admin_id, user_manager.admins)
        self.assertNotEqual(initial_admins, user_manager.admins)
        mock_save_json.assert_called_once_with(MOCK_ADMINS_FILE, user_manager.admins)

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_add_admin_existing(self, mock_load_json, mock_save_json):
        """Test adding an existing admin."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        existing_admin_id = 100
        initial_admins = user_manager.admins.copy()

        # --- Act ---
        result = user_manager.add_admin(existing_admin_id)

        # --- Assert ---
        self.assertFalse(result)
        self.assertEqual(initial_admins, user_manager.admins)
        mock_save_json.assert_not_called()

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_remove_admin_success(self, mock_load_json, mock_save_json):
        """Test removing an admin successfully."""
        # Configure loader for init (with multiple admins)
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100, 200] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        admin_to_remove = 100
        initial_admins = user_manager.admins.copy()

        # --- Act ---
        result = user_manager.remove_admin(admin_to_remove)

        # --- Assert ---
        self.assertTrue(result)
        self.assertNotIn(admin_to_remove, user_manager.admins)
        self.assertIn(200, user_manager.admins)
        self.assertNotEqual(initial_admins, user_manager.admins)
        mock_save_json.assert_called_once_with(MOCK_ADMINS_FILE, user_manager.admins)

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_remove_admin_last_admin(self, mock_load_json, mock_save_json):
        """Test attempting to remove the last admin."""
        # Configure loader for init (with one admin)
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        last_admin_id = 100
        self.assertEqual(len(user_manager.admins), 1)
        initial_admins = user_manager.admins.copy()

        # --- Act ---
        result = user_manager.remove_admin(last_admin_id)

        # --- Assert ---
        self.assertFalse(result)
        self.assertEqual(initial_admins, user_manager.admins)
        self.assertIn(last_admin_id, user_manager.admins)
        mock_save_json.assert_not_called()

    @patch("users.save_json_file")
    @patch("users.load_json_file")
    def test_remove_admin_non_existent(self, mock_load_json, mock_save_json):
        """Test attempting to remove a non-admin user."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()

        # --- Arrange ---
        non_admin_id = 500
        initial_admins = user_manager.admins.copy()

        # --- Act ---
        result = user_manager.remove_admin(non_admin_id)

        # --- Assert ---
        self.assertFalse(result)
        self.assertEqual(initial_admins, user_manager.admins)
        mock_save_json.assert_not_called()

    @patch("users.load_json_file")  # Only need load mock here
    def test_is_admin_true(self, mock_load_json):
        """Test checking if a user ID belongs to an admin (positive case)."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()
        self.assertTrue(user_manager.is_admin(100))

    @patch("users.load_json_file")  # Only need load mock here
    def test_is_admin_false(self, mock_load_json):
        """Test checking if a user ID belongs to an admin (negative case)."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()
        self.assertFalse(user_manager.is_admin(200))
        self.assertFalse(user_manager.is_admin(999))

    @patch("users.load_json_file")  # Only need load mock here
    def test_get_all_users(self, mock_load_json):
        """Test retrieving all users returns a copy."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()
        users_list = user_manager.get_all_users()
        self.assertEqual(users_list, [100, 200])
        users_list.append(999)
        self.assertEqual(user_manager.users, [100, 200])

    @patch("users.load_json_file")  # Only need load mock here
    def test_get_all_admins(self, mock_load_json):
        """Test retrieving all admins returns a copy."""
        # Configure loader for init
        mock_load_json.side_effect = (
            lambda f, d: [100, 200]
            if f == MOCK_USERS_FILE
            else ([100] if f == MOCK_ADMINS_FILE else d)
        )
        user_manager = UserManager()
        admins_list = user_manager.get_all_admins()
        self.assertEqual(admins_list, [100])
        admins_list.append(999)
        self.assertEqual(user_manager.admins, [100])


if __name__ == "__main__":
    # Ensure src directory is in path for imports when run directly
    if "src" not in sys.path[0]:
        sys.path.insert(
            0,
            os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "src")),
        )
    # Re-import UserManager in case path was just added
    from users import UserManager

    unittest.main()
