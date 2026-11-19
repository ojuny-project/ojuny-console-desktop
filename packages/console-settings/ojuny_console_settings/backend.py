from __future__ import annotations

import json
import queue
import subprocess
import sys
import threading
from typing import Any


class BackendError(Exception):
    pass


class Backend:
    """Newline-delimited JSON-RPC client for nix-settings-backend --stdio."""

    def __init__(self, program: str) -> None:
        self._program = program
        self._process: subprocess.Popen[str] | None = None
        self._next_id = 0
        self._waiters: dict[int, queue.Queue[dict[str, Any]]] = {}
        self._lock = threading.Lock()
        self._reader: threading.Thread | None = None
        self._stderr: threading.Thread | None = None

    def start(self) -> None:
        if self._process is not None:
            return

        self._process = subprocess.Popen(
            [self._program, "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

        self._reader = threading.Thread(target=self._read_stdout, daemon=True)
        self._reader.start()

        self._stderr = threading.Thread(target=self._read_stderr, daemon=True)
        self._stderr.start()

    def call(self, method: str, params: dict[str, Any] | None = None, timeout: float = 60.0) -> Any:
        process = self._process
        if process is None or process.stdin is None:
            raise BackendError("settings backend is not running")

        with self._lock:
            self._next_id += 1
            request_id = self._next_id
            waiter: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=1)
            self._waiters[request_id] = waiter

        request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params or {},
        }

        try:
            process.stdin.write(json.dumps(request) + "\n")
            process.stdin.flush()
        except OSError as error:
            raise BackendError(str(error)) from error

        try:
            response = waiter.get(timeout=timeout)
        except queue.Empty:
            with self._lock:
                self._waiters.pop(request_id, None)
            raise BackendError(f"{method} timed out") from None

        if "error" in response:
            message = response["error"].get("message", "backend error")
            raise BackendError(message)

        return response.get("result")

    def close(self) -> None:
        process = self._process
        self._process = None

        if process is None:
            return

        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

    def _read_stdout(self) -> None:
        process = self._process
        if process is None or process.stdout is None:
            return

        try:
            for line in process.stdout:
                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue

                request_id = message.get("id")
                with self._lock:
                    waiter = self._waiters.pop(request_id, None)

                if waiter is not None:
                    waiter.put(message)
        finally:
            with self._lock:
                waiters = list(self._waiters.values())
                self._waiters.clear()

            for waiter in waiters:
                waiter.put(
                    {
                        "jsonrpc": "2.0",
                        "id": None,
                        "error": {
                            "code": -32000,
                            "message": "settings backend exited",
                        },
                    }
                )

    def _read_stderr(self) -> None:
        process = self._process
        if process is None or process.stderr is None:
            return

        for line in process.stderr:
            print(f"nix-settings-backend: {line.rstrip()}", file=sys.stderr)
