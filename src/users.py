import logging
from typing import List
from pathlib import Path

from .utils import load_json_file, save_json_file
from .config import USERS_FILE, ADMINS_FILE

logger = logging.getLogger(__name__)

class UserManager:
    def __init__(self):
        self.users: List[int] = self._load_users()
        self.admins: List[int] = self._load_admins()
        
    def _load_users(self) -> List[int]:
        """Load registered users from file."""
        return load_json_file(USERS_FILE, [])
    
    def _load_admins(self) -> List[int]:
        """Load admin users from file."""
        admins = load_json_file(ADMINS_FILE, [])
        if not admins:
            logger.warning("Admins list is empty, first user to interact will become admin")
        return admins
    
    def save_users(self) -> None:
        """Save registered users to file."""
        save_json_file(USERS_FILE, self.users)
    
    def save_admins(self) -> None:
        """Save admin users to file."""
        save_json_file(ADMINS_FILE, self.admins)
    
    def add_user(self, user_id: int) -> bool:
        """Add a new user if not already registered."""
        if user_id not in self.users:
            self.users.append(user_id)
            self.save_users()
            logger.info(f"New user added: {user_id}")
            return True
        return False
    
    def add_admin(self, user_id: int) -> bool:
        """Add a new admin if not already an admin."""
        if user_id not in self.admins:
            self.admins.append(user_id)
            self.save_admins()
            logger.info(f"New admin added: {user_id}")
            return True
        return False
    
    def is_admin(self, user_id: int) -> bool:
        """Check if user is an admin."""
        return user_id in self.admins
    
    def get_all_users(self) -> List[int]:
        """Get list of all registered users."""
        return self.users.copy()
    
    def get_all_admins(self) -> List[int]:
        """Get list of all admin users."""
        return self.admins.copy()
