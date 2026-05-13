import hashlib
import io
import importlib.util
import json
import os
from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest

_script_path = (
    Path(__file__).parent.parent / "examples" / ".automations" / "give-student-credit.py"
)
spec = importlib.util.spec_from_file_location("give_student_credit", _script_path)
gsc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gsc)


class TestGitConfig:
    def test_returns_stripped_value_on_success(self):
        result = MagicMock(returncode=0, stdout="  Alice  ")
        with patch("subprocess.run", return_value=result):
            assert gsc.git_config("user.name") == "Alice"

    def test_strips_carriage_return(self):
        result = MagicMock(returncode=0, stdout="Alice\r")
        with patch("subprocess.run", return_value=result):
            assert gsc.git_config("user.name") == "Alice"

    def test_returns_empty_when_stdout_none(self):
        result = MagicMock(returncode=0, stdout=None)
        with patch("subprocess.run", return_value=result):
            assert gsc.git_config("user.name") == ""

    def test_returns_empty_on_nonzero_returncode(self):
        result = MagicMock(returncode=1, stdout="something")
        with patch("subprocess.run", return_value=result):
            assert gsc.git_config("user.name") == ""

    def test_returns_empty_on_exception(self):
        with patch("subprocess.run", side_effect=Exception("timeout")):
            assert gsc.git_config("user.name") == ""


class TestGetUsername:
    def test_returns_git_config_value(self):
        with patch.object(gsc, "git_config", return_value="Alice"):
            assert gsc.get_username() == "Alice"

    def test_falls_back_to_git_author_name(self, monkeypatch):
        monkeypatch.setenv("GIT_AUTHOR_NAME", "EnvAlice")
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.delenv("USERNAME", raising=False)
        with patch.object(gsc, "git_config", return_value=""), \
             patch("getpass.getuser", return_value=""):
            assert gsc.get_username() == "EnvAlice"

    def test_falls_back_to_user_env(self, monkeypatch):
        monkeypatch.delenv("GIT_AUTHOR_NAME", raising=False)
        monkeypatch.setenv("USER", "EnvUser")
        monkeypatch.delenv("USERNAME", raising=False)
        with patch.object(gsc, "git_config", return_value=""), \
             patch("getpass.getuser", return_value=""):
            assert gsc.get_username() == "EnvUser"

    def test_falls_back_to_username_env(self, monkeypatch):
        monkeypatch.delenv("GIT_AUTHOR_NAME", raising=False)
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.setenv("USERNAME", "WinUser")
        with patch.object(gsc, "git_config", return_value=""), \
             patch("getpass.getuser", return_value=""):
            assert gsc.get_username() == "WinUser"

    def test_falls_back_to_getpass(self, monkeypatch):
        monkeypatch.delenv("GIT_AUTHOR_NAME", raising=False)
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.delenv("USERNAME", raising=False)
        with patch.object(gsc, "git_config", return_value=""), \
             patch("getpass.getuser", return_value="sysuser"):
            assert gsc.get_username() == "sysuser"

    def test_returns_unknown_as_last_resort(self, monkeypatch):
        monkeypatch.delenv("GIT_AUTHOR_NAME", raising=False)
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.delenv("USERNAME", raising=False)
        with patch.object(gsc, "git_config", return_value=""), \
             patch("getpass.getuser", return_value=""):
            assert gsc.get_username() == "unknown"


class TestGetSystemUser:
    def test_returns_getpass_value(self):
        with patch("getpass.getuser", return_value="sysuser"):
            assert gsc.get_system_user() == "sysuser"

    def test_falls_back_to_user_env_on_key_error(self, monkeypatch):
        monkeypatch.setenv("USER", "fallback")
        monkeypatch.delenv("USERNAME", raising=False)
        with patch("getpass.getuser", side_effect=KeyError("HOME")):
            assert gsc.get_system_user() == "fallback"

    def test_falls_back_to_username_env_on_os_error(self, monkeypatch):
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.setenv("USERNAME", "WinFallback")
        with patch("getpass.getuser", side_effect=OSError("no passwd")):
            assert gsc.get_system_user() == "WinFallback"

    def test_returns_unknown_when_all_env_missing(self, monkeypatch):
        monkeypatch.delenv("USER", raising=False)
        monkeypatch.delenv("USERNAME", raising=False)
        with patch("getpass.getuser", side_effect=KeyError("HOME")):
            assert gsc.get_system_user() == "unknown"


class TestGetEmail:
    def test_returns_git_config_value(self):
        with patch.object(gsc, "git_config", return_value="alice@test.com"):
            assert gsc.get_email() == "alice@test.com"

    def test_falls_back_to_env(self, monkeypatch):
        monkeypatch.setenv("GIT_AUTHOR_EMAIL", "env@test.com")
        with patch.object(gsc, "git_config", return_value=""):
            assert gsc.get_email() == "env@test.com"

    def test_returns_empty_when_nothing_set(self, monkeypatch):
        monkeypatch.delenv("GIT_AUTHOR_EMAIL", raising=False)
        with patch.object(gsc, "git_config", return_value=""):
            assert gsc.get_email() == ""


class TestGetRepository:
    def test_returns_remote_url(self):
        with patch.object(gsc, "git_config", return_value="https://github.com/org/repo"):
            assert gsc.get_repository() == "https://github.com/org/repo"

    def test_falls_back_to_project_root(self):
        with patch.object(gsc, "git_config", return_value=""):
            result = gsc.get_repository()
            assert result == str(gsc.PROJECT_ROOT)


class TestFileHash:
    def test_returns_hash_for_existing_file(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_bytes(b"hello world")
        original = gsc.PROJECT_ROOT
        gsc.PROJECT_ROOT = tmp_path
        try:
            result = gsc.file_hash("test.txt")
        finally:
            gsc.PROJECT_ROOT = original
        expected = hashlib.sha256(b"hello world").hexdigest()[:12]
        assert result == expected

    def test_returns_missing_for_nonexistent_file(self, tmp_path):
        original = gsc.PROJECT_ROOT
        gsc.PROJECT_ROOT = tmp_path
        try:
            result = gsc.file_hash("nonexistent.txt")
        finally:
            gsc.PROJECT_ROOT = original
        assert result == "missing"


class TestMain:
    def _make_config(self, tmp_path, url="https://example.com/exec"):
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps({"url": url}))
        return config_file

    def test_posts_payload_and_prints(self, monkeypatch, tmp_path, capsys):
        config_file = self._make_config(tmp_path)
        monkeypatch.setattr(gsc, "CONFIG_PATH", config_file)
        monkeypatch.setattr("sys.argv", ["script", "--tool", "claude", "--event", "PostToolUse"])

        with patch.object(gsc, "file_hash", return_value="abc123def456"), \
             patch.object(gsc, "get_repository", return_value="https://github.com/org/repo"), \
             patch.object(gsc, "get_username", return_value="alice"), \
             patch.object(gsc, "get_email", return_value="alice@test.com"), \
             patch.object(gsc, "get_system_user", return_value="alice"), \
             patch("socket.gethostname", return_value="testhost"), \
             patch("sys.stdin", io.StringIO("")), \
             patch.object(gsc, "urlopen") as mock_urlopen:
            gsc.main()

        mock_urlopen.assert_called_once()
        assert capsys.readouterr().out.strip() == "{}"

    def test_uses_default_tool_and_event_args(self, monkeypatch, tmp_path, capsys):
        config_file = self._make_config(tmp_path)
        monkeypatch.setattr(gsc, "CONFIG_PATH", config_file)
        monkeypatch.setattr("sys.argv", ["script"])

        with patch.object(gsc, "file_hash", return_value="abc123def456"), \
             patch.object(gsc, "get_repository", return_value=""), \
             patch.object(gsc, "get_username", return_value=""), \
             patch.object(gsc, "get_email", return_value=""), \
             patch.object(gsc, "get_system_user", return_value=""), \
             patch("socket.gethostname", return_value=""), \
             patch("sys.stdin", io.StringIO("")), \
             patch.object(gsc, "urlopen"):
            gsc.main()

        assert capsys.readouterr().out.strip() == "{}"

    def test_silences_url_error(self, monkeypatch, tmp_path, capsys):
        from urllib.error import URLError
        config_file = self._make_config(tmp_path)
        monkeypatch.setattr(gsc, "CONFIG_PATH", config_file)
        monkeypatch.setattr("sys.argv", ["script"])

        with patch.object(gsc, "file_hash", return_value="abc123def456"), \
             patch.object(gsc, "get_repository", return_value=""), \
             patch.object(gsc, "get_username", return_value=""), \
             patch.object(gsc, "get_email", return_value=""), \
             patch.object(gsc, "get_system_user", return_value=""), \
             patch("socket.gethostname", return_value=""), \
             patch("sys.stdin", io.StringIO("")), \
             patch.object(gsc, "urlopen", side_effect=URLError("refused")):
            gsc.main()

        assert capsys.readouterr().out.strip() == "{}"

    def test_silences_os_error(self, monkeypatch, tmp_path, capsys):
        config_file = self._make_config(tmp_path)
        monkeypatch.setattr(gsc, "CONFIG_PATH", config_file)
        monkeypatch.setattr("sys.argv", ["script"])

        with patch.object(gsc, "file_hash", return_value="abc123def456"), \
             patch.object(gsc, "get_repository", return_value=""), \
             patch.object(gsc, "get_username", return_value=""), \
             patch.object(gsc, "get_email", return_value=""), \
             patch.object(gsc, "get_system_user", return_value=""), \
             patch("socket.gethostname", return_value=""), \
             patch("sys.stdin", io.StringIO("")), \
             patch.object(gsc, "urlopen", side_effect=OSError("network error")):
            gsc.main()

        assert capsys.readouterr().out.strip() == "{}"
