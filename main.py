import tkinter as tk
from tkinter import ttk, scrolledtext
import threading
import queue
import os
import subprocess
import yt_dlp

SAVE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "saved_audio")


class LogHandler:
    def __init__(self, log_queue: queue.Queue):
        self.q = log_queue

    def debug(self, msg):
        if msg.startswith("[debug]"):
            return
        self.q.put(("log", msg))

    def info(self, msg):
        self.q.put(("log", msg))

    def warning(self, msg):
        self.q.put(("log", f"WARNING: {msg}"))

    def error(self, msg):
        self.q.put(("log", f"ERROR: {msg}"))


def download_audio(url: str, log_queue: queue.Queue):
    os.makedirs(SAVE_DIR, exist_ok=True)
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": os.path.join(SAVE_DIR, "%(title)s.%(ext)s"),
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }
        ],
        "logger": LogHandler(log_queue),
        "progress_hooks": [lambda d: _progress_hook(d, log_queue)],
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        log_queue.put(("done", "Download complete."))
    except Exception as e:
        log_queue.put(("error", str(e)))


def _progress_hook(d: dict, log_queue: queue.Queue):
    if d["status"] == "downloading":
        pct = d.get("_percent_str", "").strip()
        speed = d.get("_speed_str", "").strip()
        eta = d.get("_eta_str", "").strip()
        log_queue.put(("progress", f"Downloading… {pct}  speed: {speed}  ETA: {eta}"))
    elif d["status"] == "finished":
        log_queue.put(("log", f"Saved: {os.path.basename(d['filename'])}"))


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Audio Lifter")
        self.resizable(False, False)
        self._build_ui()
        self.log_queue: queue.Queue = queue.Queue()
        self._poll_queue()

    def _build_ui(self):
        header = tk.Label(
            self,
            text="Audio Lifter",
            font=("Helvetica", 22, "bold"),
        )
        header.pack(padx=20, pady=(20, 4))

        subtitle = tk.Label(
            self,
            text="Paste a YouTube URL below and click Download.",
            font=("Helvetica", 12),
            fg="#555555",
        )
        subtitle.pack(padx=20, pady=(0, 12))

        url_frame = tk.Frame(self)
        url_frame.pack(padx=20, fill="x")

        self.url_var = tk.StringVar()
        self.url_entry = tk.Entry(
            url_frame,
            textvariable=self.url_var,
            font=("Helvetica", 13),
            width=52,
            relief="solid",
            bd=1,
        )
        self.url_entry.pack(side="left", ipady=6, padx=(0, 8))
        self.url_entry.bind("<Return>", lambda _: self._start_download())

        self.dl_btn = tk.Button(
            url_frame,
            text="Download",
            font=("Helvetica", 13, "bold"),
            bg="#1a73e8",
            fg="white",
            activebackground="#1558b0",
            activeforeground="white",
            relief="flat",
            padx=14,
            pady=6,
            cursor="hand2",
            command=self._start_download,
        )
        self.dl_btn.pack(side="left")

        self.status_var = tk.StringVar(value="Ready.")
        status_label = tk.Label(
            self,
            textvariable=self.status_var,
            font=("Helvetica", 11),
            fg="#444444",
            anchor="w",
        )
        status_label.pack(padx=20, fill="x", pady=(10, 2))

        self.progress = ttk.Progressbar(self, mode="indeterminate", length=560)
        self.progress.pack(padx=20, pady=(0, 8))

        self.log_box = scrolledtext.ScrolledText(
            self,
            height=12,
            width=68,
            font=("Courier", 10),
            state="disabled",
            relief="solid",
            bd=1,
            bg="#f8f8f8",
        )
        self.log_box.pack(padx=20, pady=(0, 20))

        save_note = tk.Label(
            self,
            text=f"Files saved to: {SAVE_DIR}",
            font=("Helvetica", 10),
            fg="#888888",
        )
        save_note.pack(pady=(0, 14))

    def _log(self, text: str):
        self.log_box.configure(state="normal")
        self.log_box.insert("end", text + "\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def _start_download(self):
        url = self.url_var.get().strip()
        if not url:
            self.status_var.set("Please enter a YouTube URL.")
            return

        self.dl_btn.configure(state="disabled")
        self.url_entry.configure(state="disabled")
        self.progress.start(12)
        self.status_var.set("Downloading…")
        self.url_var.set("")

        thread = threading.Thread(
            target=download_audio,
            args=(url, self.log_queue),
            daemon=True,
        )
        thread.start()

    def _poll_queue(self):
        try:
            while True:
                kind, msg = self.log_queue.get_nowait()
                if kind == "progress":
                    self.status_var.set(msg)
                elif kind in ("log",):
                    self._log(msg)
                elif kind == "done":
                    self._log(msg)
                    self._finish()
                    subprocess.run(["open", SAVE_DIR])
                elif kind == "error":
                    self._log(f"Error: {msg}")
                    self.status_var.set("Error — see log above.")
                    self._finish()
        except queue.Empty:
            pass
        self.after(100, self._poll_queue)

    def _finish(self):
        self.progress.stop()
        self.dl_btn.configure(state="normal")
        self.url_entry.configure(state="normal")
        self.url_entry.focus_set()


def main():
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
