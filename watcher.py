import sys
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

WATCHED_FILES = ['run.py']  # Add more files if needed
SUPERVISORCTL = '/usr/local/bin/supervisorctl'  # Path to supervisorctl

class ChangeHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if any(event.src_path.endswith(f) for f in WATCHED_FILES):
            print(f"{event.src_path} changed, restarting miner...")
            subprocess.run([SUPERVISORCTL, 'restart', 'twitch_miner'])

if __name__ == "__main__":
    path = '.'
    event_handler = ChangeHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=True)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()