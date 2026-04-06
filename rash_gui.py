#!/usr/bin/env python3
"""
rash_gui.py — Graphical front-end for RASH (Remote Apple Shell Helper).

Provides the same functionality as rash.sh / rash_single.sh in a Tkinter
window:

  • Left panel  : list of machine groups parsed from machine_groups.txt
  • Top strip   : SSH key path, username, command entry, Run button
  • Output area : scrollable, colour-coded results per machine
  • Settings    : inline editor for machine_groups.txt

Usage:
    python3 rash_gui.py

Requires Python 3.8+ (ships with macOS 12+).  No third-party packages needed.
"""
from __future__ import annotations

import os
import queue
import subprocess
import threading
import tkinter as tk
from tkinter import messagebox, scrolledtext, ttk

# ---------------------------------------------------------------------------
# Paths — all relative to this script's directory, matching the Bash scripts
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MACHINE_GROUPS_FILE = os.path.join(SCRIPT_DIR, "machine_groups.txt")
ADMIN_ACCOUNT_FILE = os.path.join(SCRIPT_DIR, "admin_account.txt")
DEFAULT_PRIVATE_KEY = os.path.expanduser("~/.ssh/id_rsa")

SSH_TIMEOUT = 15  # seconds, matches the Bash scripts

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def load_machine_groups(path: str) -> dict:
    """Parse machine_groups.txt into {group_name: [ip, ...]}."""
    groups: dict[str, list[str]] = {}
    try:
        with open(path, "r") as fh:
            for raw in fh:
                line = raw.strip()
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 2:
                    groups[parts[0]] = parts[1:]
    except FileNotFoundError:
        pass
    return groups


def load_username(path: str) -> str:
    """Read the admin username from admin_account.txt if it exists."""
    try:
        with open(path, "r") as fh:
            return fh.read().strip()
    except FileNotFoundError:
        return ""


def save_machine_groups(path: str, text: str) -> None:
    """Write edited text back to machine_groups.txt."""
    with open(path, "w") as fh:
        fh.write(text)


# ---------------------------------------------------------------------------
# SSH worker (runs in a background thread)
# ---------------------------------------------------------------------------


def ssh_worker(
    private_key: str,
    username: str,
    machine: str,
    command: str,
    result_queue: queue.Queue,
) -> None:
    """
    Invoke SSH with the same flags used by the Bash scripts, then push
    (machine, output, exit_status) into result_queue so the UI can pick it up.
    """
    ssh_cmd = [
        "ssh",
        "-i", private_key,
        "-o", f"ConnectTimeout={SSH_TIMEOUT}",
        "-o", "StrictHostKeyChecking=no",
        "-o", "PasswordAuthentication=no",
        "-o", "LogLevel=ERROR",
        "-q", "-T",
        f"{username}@{machine}",
        f"sudo {command}",
    ]
    try:
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=SSH_TIMEOUT + 5,
        )
        output = (result.stdout + result.stderr).strip()
        result_queue.put((machine, output, result.returncode))
    except subprocess.TimeoutExpired:
        result_queue.put((machine, "", 255))
    except Exception as exc:
        result_queue.put((machine, str(exc), 1))


# ---------------------------------------------------------------------------
# Settings window
# ---------------------------------------------------------------------------


class AddGroupDialog(tk.Toplevel):
    """Small modal dialog for adding a new machine group."""

    def __init__(self, parent: RashApp) -> None:
        super().__init__(parent.root)
        self._parent = parent
        self.title("Add Group")
        self.resizable(False, False)
        self.grab_set()

        tk.Label(self, text="Group name:").grid(
            row=0, column=0, padx=(12, 4), pady=(12, 4), sticky="e"
        )
        self._name_var = tk.StringVar()
        tk.Entry(self, textvariable=self._name_var, width=24).grid(
            row=0, column=1, padx=(0, 12), pady=(12, 4), sticky="ew"
        )

        tk.Label(self, text="Machines\n(space-separated IPs):").grid(
            row=1, column=0, padx=(12, 4), pady=4, sticky="ne"
        )
        self._machines_text = tk.Text(self, width=32, height=4, font=("Courier", 12))
        self._machines_text.grid(row=1, column=1, padx=(0, 12), pady=4, sticky="ew")

        btn_frame = tk.Frame(self)
        btn_frame.grid(row=2, column=0, columnspan=2, padx=12, pady=(4, 12), sticky="e")
        tk.Button(btn_frame, text="Cancel", width=8, command=self.destroy).pack(
            side=tk.RIGHT, padx=(4, 0)
        )
        tk.Button(btn_frame, text="Add", width=8, command=self._add).pack(side=tk.RIGHT)

        self.columnconfigure(1, weight=1)

    def _add(self) -> None:
        name = self._name_var.get().strip()
        machines_raw = self._machines_text.get("1.0", tk.END).strip()
        if not name:
            messagebox.showwarning("Missing Name", "Please enter a group name.", parent=self)
            return
        machines = machines_raw.split()
        if not machines:
            messagebox.showwarning(
                "Missing Machines", "Please enter at least one IP/hostname.", parent=self
            )
            return
        # Append the new group to machine_groups.txt
        line = name + "  " + "  ".join(machines) + "\n"
        with open(MACHINE_GROUPS_FILE, "a") as fh:
            fh.write(line)
        self._parent.reload_groups()
        # Select the newly added group in the listbox
        items = list(self._parent._groups.keys())
        if name in items:
            idx = items.index(name)
            self._parent._group_listbox.selection_clear(0, tk.END)
            self._parent._group_listbox.selection_set(idx)
            self._parent._group_listbox.see(idx)
            self._parent._on_group_select()
        self.destroy()


class SettingsWindow(tk.Toplevel):
    """Modal-style window for editing machine_groups.txt inline."""

    def __init__(self, parent: RashApp) -> None:
        super().__init__(parent.root)
        self._parent = parent
        self.title("Settings — machine_groups.txt")
        self.resizable(True, True)
        self.grab_set()  # keep focus on this window while open

        tk.Label(
            self, text="Edit machine_groups.txt", font=("", 12, "bold")
        ).pack(padx=10, pady=(10, 2), anchor="w")
        tk.Label(
            self,
            text="Format:  GroupName  IP1  IP2  IP3   (one group per line)",
            fg="gray",
        ).pack(padx=10, pady=(0, 4), anchor="w")

        self._text = scrolledtext.ScrolledText(
            self, width=60, height=15, font=("Courier", 12)
        )
        self._text.pack(padx=10, pady=(0, 4), fill=tk.BOTH, expand=True)

        try:
            with open(MACHINE_GROUPS_FILE, "r") as fh:
                self._text.insert("1.0", fh.read())
        except FileNotFoundError:
            pass

        btn_frame = tk.Frame(self)
        btn_frame.pack(padx=10, pady=(0, 10), fill=tk.X)
        tk.Button(
            btn_frame, text="Cancel", width=10, command=self.destroy
        ).pack(side=tk.RIGHT, padx=(4, 0))
        tk.Button(
            btn_frame, text="Save", width=10, command=self._save
        ).pack(side=tk.RIGHT)

    def _save(self) -> None:
        content = self._text.get("1.0", tk.END)
        save_machine_groups(MACHINE_GROUPS_FILE, content)
        self._parent.reload_groups()
        self.destroy()


# ---------------------------------------------------------------------------
# Main application
# ---------------------------------------------------------------------------


class RashApp:
    """Tkinter GUI that replicates the interactive workflow of rash.sh."""

    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("RASH — Remote Apple Shell Helper")
        self.root.minsize(720, 540)

        self._result_queue: queue.Queue = queue.Queue()
        self._pending_machines: int = 0
        self._groups: dict[str, list[str]] = {}

        self._build_ui()
        self.reload_groups()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self) -> None:
        root = self.root

        # ── Top bar: SSH key path + username ──────────────────────────
        top = tk.Frame(root, padx=8, pady=6)
        top.pack(fill=tk.X, side=tk.TOP)

        tk.Label(top, text="SSH Key:").grid(row=0, column=0, sticky="e")
        self._key_var = tk.StringVar(value=DEFAULT_PRIVATE_KEY)
        tk.Entry(top, textvariable=self._key_var, width=38).grid(
            row=0, column=1, padx=(4, 16), sticky="ew"
        )

        tk.Label(top, text="Username:").grid(row=0, column=2, sticky="e")
        self._user_var = tk.StringVar(value=load_username(ADMIN_ACCOUNT_FILE))
        tk.Entry(top, textvariable=self._user_var, width=16).grid(
            row=0, column=3, padx=(4, 0), sticky="ew"
        )
        top.columnconfigure(1, weight=1)

        # ── Command bar ───────────────────────────────────────────────
        cmd_bar = tk.Frame(root, padx=8, pady=4)
        cmd_bar.pack(fill=tk.X, side=tk.TOP)

        tk.Label(cmd_bar, text="Command:").pack(side=tk.LEFT)
        self._cmd_var = tk.StringVar()
        cmd_entry = tk.Entry(
            cmd_bar, textvariable=self._cmd_var, font=("Courier", 13)
        )
        cmd_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(4, 8))
        cmd_entry.bind("<Return>", lambda _e: self._run())

        self._run_btn = tk.Button(
            cmd_bar,
            text="▶  Run",
            width=10,
            command=self._run,
            bg="#3a7ebf",
            fg="white",
            activebackground="#2c6aa0",
            activeforeground="white",
        )
        self._run_btn.pack(side=tk.LEFT)

        ttk.Separator(root, orient="horizontal").pack(fill=tk.X, padx=8)

        # ── Main area: group list (left) + output (right) ─────────────
        main = tk.Frame(root, padx=8, pady=6)
        main.pack(fill=tk.BOTH, expand=True)

        # Left panel — group selector
        left = tk.Frame(main)
        left.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 8))

        tk.Label(left, text="Groups", font=("", 11, "bold")).pack(anchor="w")
        self._group_listbox = tk.Listbox(
            left, width=20, selectmode=tk.SINGLE, exportselection=False
        )
        self._group_listbox.pack(fill=tk.BOTH, expand=True)
        self._group_listbox.bind("<<ListboxSelect>>", self._on_group_select)

        tk.Button(
            left, text="＋  Add Group", command=self._open_add_group
        ).pack(fill=tk.X, pady=(2, 0))

        tk.Button(
            left, text="⚙  Settings", command=self._open_settings
        ).pack(fill=tk.X, pady=(4, 0))

        ttk.Separator(main, orient="vertical").pack(
            side=tk.LEFT, fill=tk.Y, padx=(0, 8)
        )

        # Right panel — output
        right = tk.Frame(main)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        output_header = tk.Frame(right)
        output_header.pack(fill=tk.X)
        tk.Label(
            output_header, text="Output", font=("", 11, "bold")
        ).pack(side=tk.LEFT)
        tk.Button(
            output_header, text="Clear", command=self._clear_output
        ).pack(side=tk.RIGHT)

        self._output = scrolledtext.ScrolledText(
            right,
            state="disabled",
            font=("Courier", 12),
            bg="#1e1e1e",
            fg="#d4d4d4",
            insertbackground="white",
            wrap=tk.WORD,
        )
        self._output.pack(fill=tk.BOTH, expand=True, pady=(4, 0))

        # Colour-coded text tags
        self._output.tag_config("success", foreground="#4ec9b0")   # teal
        self._output.tag_config("error", foreground="#f44747")     # red
        self._output.tag_config("timeout", foreground="#ce9178")   # orange
        self._output.tag_config("info", foreground="#9cdcfe")      # light blue
        self._output.tag_config(
            "cmd_output", foreground="#d4d4d4", font=("Courier", 12)
        )

        # ── Status bar ─────────────────────────────────────────────────
        self._status_var = tk.StringVar(value="Ready")
        tk.Label(
            root,
            textvariable=self._status_var,
            anchor="w",
            relief=tk.SUNKEN,
            padx=6,
            pady=2,
            fg="gray",
        ).pack(fill=tk.X, side=tk.BOTTOM)

    # ------------------------------------------------------------------
    # Group management
    # ------------------------------------------------------------------

    def reload_groups(self) -> None:
        """Re-read machine_groups.txt and refresh the listbox."""
        self._groups = load_machine_groups(MACHINE_GROUPS_FILE)
        self._group_listbox.delete(0, tk.END)
        for name in self._groups:
            self._group_listbox.insert(tk.END, name)
        if self._groups:
            self._group_listbox.selection_set(0)
            self._on_group_select()
        else:
            self._status_var.set(
                "No groups found. Use ⚙ Settings to create machine_groups.txt."
            )

    def _on_group_select(self, _event: object = None) -> None:
        sel = self._group_listbox.curselection()
        if sel:
            name = self._group_listbox.get(sel[0])
            machines = self._groups.get(name, [])
            self._status_var.set(
                f"Group '{name}' — {len(machines)} machine(s): "
                + ", ".join(machines)
            )

    # ------------------------------------------------------------------
    # Settings
    # ------------------------------------------------------------------

    def _open_settings(self) -> None:
        SettingsWindow(self)

    def _open_add_group(self) -> None:
        AddGroupDialog(self)

    # ------------------------------------------------------------------
    # Run command
    # ------------------------------------------------------------------

    def _run(self) -> None:
        sel = self._group_listbox.curselection()
        if not sel:
            messagebox.showwarning(
                "No Group Selected", "Please select a machine group first."
            )
            return

        group_name = self._group_listbox.get(sel[0])
        machines = self._groups.get(group_name, [])
        command = self._cmd_var.get().strip()
        username = self._user_var.get().strip()
        private_key = self._key_var.get().strip()

        if not command:
            messagebox.showwarning(
                "No Command", "Please enter a command to execute."
            )
            return
        if not username:
            messagebox.showwarning(
                "No Username", "Please enter a username."
            )
            return
        if not machines:
            messagebox.showwarning(
                "Empty Group", f"Group '{group_name}' has no machines."
            )
            return

        self._run_btn.config(state="disabled")
        self._pending_machines = len(machines)

        self._append(
            f"Executing '{command}' on group {group_name} "
            f"({len(machines)} machine(s))…\n",
            "info",
        )

        for machine in machines:
            t = threading.Thread(
                target=ssh_worker,
                args=(private_key, username, machine, command, self._result_queue),
                daemon=True,
            )
            t.start()

        self._status_var.set(
            f"Running '{command}' on {len(machines)} machine(s)…"
        )
        self._poll_results()

    def _poll_results(self) -> None:
        """Check the result queue and schedule itself until all machines respond."""
        try:
            while True:
                machine, output, exit_status = self._result_queue.get_nowait()
                self._pending_machines -= 1

                if exit_status == 0:
                    self._append(f"✔ {machine} — success\n", "success")
                elif exit_status == 255:
                    self._append(
                        f"✘ {machine} — connection timed out or failed\n",
                        "timeout",
                    )
                else:
                    self._append(
                        f"✘ {machine} — error (exit {exit_status})\n", "error"
                    )

                if output:
                    self._append(output + "\n\n", "cmd_output")

        except queue.Empty:
            pass

        if self._pending_machines > 0:
            self.root.after(100, self._poll_results)
        else:
            self._run_btn.config(state="normal")
            self._status_var.set("Done.")

    # ------------------------------------------------------------------
    # Output helpers
    # ------------------------------------------------------------------

    def _append(self, text: str, tag: str = "") -> None:
        self._output.config(state="normal")
        if tag:
            self._output.insert(tk.END, text, tag)
        else:
            self._output.insert(tk.END, text)
        self._output.see(tk.END)
        self._output.config(state="disabled")

    def _clear_output(self) -> None:
        self._output.config(state="normal")
        self._output.delete("1.0", tk.END)
        self._output.config(state="disabled")
        self._status_var.set("Ready")

    # ------------------------------------------------------------------
    # Entry point
    # ------------------------------------------------------------------

    def run(self) -> None:
        self.root.mainloop()


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    RashApp().run()
