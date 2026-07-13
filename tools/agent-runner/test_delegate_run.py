import tempfile
from pathlib import Path
import unittest

import delegate_run


class AgentRunnerTests(unittest.TestCase):
    def test_collect_excludes_git_env_and_detected_secrets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src").mkdir()
            (root / ".git").mkdir()
            (root / "src" / "safe.py").write_text("print('safe')")
            (root / "src" / "secret.py").write_text("password=supersecretvalue")
            (root / ".env").write_text("API_KEY=example")
            (root / ".git" / "config").write_text("history")

            selected = delegate_run.collect(root, ["**"])
            relative = [path.relative_to(root).as_posix() for path in selected]

            self.assertEqual(relative, ["src/safe.py"])

    def test_sensitive_suffixes_are_blocked(self) -> None:
        self.assertTrue(delegate_run.is_sensitive(Path("certificates/client.pem")))
        self.assertTrue(delegate_run.is_sensitive(Path("config/.env.production")))
        self.assertFalse(delegate_run.is_sensitive(Path("Sources/App.swift")))


if __name__ == "__main__":
    unittest.main()
