import sqlite3
from typing import List, Optional, Dict, Any
from contextlib import contextmanager
import os
from database.repository import DatabaseRepository

class SQLiteRepository(DatabaseRepository):
    def __init__(self, db_path: str = "consent_store.db"):
        self.db_path = db_path
        self._initialize_database()
    
    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    
    def _initialize_database(self):
        """Initialize database schema"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Create applications table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS applications (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create capabilities table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS capabilities (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    application_id INTEGER NOT NULL,
                    capability TEXT NOT NULL,
                    FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
                    UNIQUE(application_id, capability)
                )
            ''')
            
            # Create user_consents table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS user_consents (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    requesting_app_id INTEGER NOT NULL,
                    destination_app_id INTEGER NOT NULL,
                    capability TEXT NOT NULL,
                    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (requesting_app_id) REFERENCES applications(id) ON DELETE CASCADE,
                    FOREIGN KEY (destination_app_id) REFERENCES applications(id) ON DELETE CASCADE,
                    UNIQUE(user_id, requesting_app_id, destination_app_id, capability)
                )
            ''')
            
            # Create indexes
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_user_consents_user_id ON user_consents(user_id)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_capabilities_app_id ON capabilities(application_id)')
    
    def create_application(self, name: str) -> int:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('INSERT INTO applications (name) VALUES (?)', (name,))
            return cursor.lastrowid
    
    def get_application(self, app_id: int) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM applications WHERE id = ?', (app_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    def get_application_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM applications WHERE name = ?', (name,))
            row = cursor.fetchone()
            return dict(row) if row else None
    
    def list_applications(self) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM applications ORDER BY name')
            return [dict(row) for row in cursor.fetchall()]
    
    def delete_application(self, app_id: int) -> bool:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM applications WHERE id = ?', (app_id,))
            return cursor.rowcount > 0
    
    def add_capability(self, app_id: int, capability: str) -> bool:
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    'INSERT INTO capabilities (application_id, capability) VALUES (?, ?)',
                    (app_id, capability)
                )
                return True
        except sqlite3.IntegrityError:
            return False
    
    def remove_capability(self, app_id: int, capability: str) -> bool:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                'DELETE FROM capabilities WHERE application_id = ? AND capability = ?',
                (app_id, capability)
            )
            return cursor.rowcount > 0
    
    def list_capabilities(self, app_id: int) -> List[str]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                'SELECT capability FROM capabilities WHERE application_id = ? ORDER BY capability',
                (app_id,)
            )
            return [row['capability'] for row in cursor.fetchall()]
    
    def grant_consent(self, user_id: str, requesting_app_id: int,
                     destination_app_id: int, capability: str) -> bool:
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO user_consents 
                    (user_id, requesting_app_id, destination_app_id, capability)
                    VALUES (?, ?, ?, ?)
                ''', (user_id, requesting_app_id, destination_app_id, capability))
                return True
        except sqlite3.IntegrityError:
            return False
    
    def check_consent(self, user_id: str, requesting_app_id: int,
                     destination_app_id: int, capabilities: List[str]) -> Dict[str, bool]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ','.join(['?' for _ in capabilities])
            cursor.execute(f'''
                SELECT capability FROM user_consents
                WHERE user_id = ? AND requesting_app_id = ? 
                AND destination_app_id = ? AND capability IN ({placeholders})
            ''', [user_id, requesting_app_id, destination_app_id] + capabilities)
            
            granted = {row['capability'] for row in cursor.fetchall()}
            return {cap: cap in granted for cap in capabilities}
    
    def revoke_consent(self, user_id: str, requesting_app_id: int,
                      destination_app_id: int, capability: str) -> bool:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                DELETE FROM user_consents
                WHERE user_id = ? AND requesting_app_id = ?
                AND destination_app_id = ? AND capability = ?
            ''', (user_id, requesting_app_id, destination_app_id, capability))
            return cursor.rowcount > 0
    
    def revoke_all_user_consent(self, user_id: str) -> int:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM user_consents WHERE user_id = ?', (user_id,))
            return cursor.rowcount
    
    def revoke_all_consent(self) -> int:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM user_consents')
            return cursor.rowcount
    
    def list_user_consents(self, user_id: str) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT 
                    uc.*,
                    ra.name as requesting_app_name,
                    da.name as destination_app_name
                FROM user_consents uc
                JOIN applications ra ON uc.requesting_app_id = ra.id
                JOIN applications da ON uc.destination_app_id = da.id
                WHERE uc.user_id = ?
                ORDER BY uc.granted_at DESC
            ''', (user_id,))
            return [dict(row) for row in cursor.fetchall()]