"""Executa o mesmo fluxo de um terminal, com entrada controlada e timeout."""
import os
import pty
import subprocess
import fcntl
import signal
import termios


def terminal_session():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


def run_terminal(command, answers, *, env, cwd, timeout=30):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen([str(arg) for arg in command], stdin=slave,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   env=env, cwd=cwd, text=True, preexec_fn=terminal_session)
        os.write(master, answers.encode())
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            raise
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    finally:
        os.close(master)
        os.close(slave)
