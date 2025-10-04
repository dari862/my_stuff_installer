#!/usr/bin/env python3

import os
import threading
import hashlib
import subprocess
import configparser
import sys
import signal
from tkinter import *
from tkinter import ttk

# --- Allow Ctrl+C to exit cleanly ---
signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))

# --- Get system GTK font from settings.ini ---
def get_gtk_font():
    ini_paths = [
        os.path.expanduser("~/.config/gtk-3.0/settings.ini"),
        os.path.expanduser("~/.config/gtk-4.0/settings.ini"),
    ]

    for path in ini_paths:
        if os.path.exists(path):
            config = configparser.ConfigParser()
            config.read(path)
            try:
                font_str = config["Settings"]["gtk-font-name"]
                *name_parts, size = font_str.strip().split()
                return " ".join(name_parts), int(size)
            except Exception:
                pass

    return "Sans", 10  # fallback

# --- Load wallpaper config from sourced shell files ---
def parse_shell_var(file_path, var_name):
    try:
        with open(file_path) as f:
            for line in f:
                if line.strip().startswith(f"{var_name}="):
                    return line.strip().split("=", 1)[1].strip('"')
    except Exception:
        pass
    return None

CONFIG_LIB = "/usr/share/my_stuff/lib/common/WM"
DISTRO_CONFIG_PATH = parse_shell_var(CONFIG_LIB, "Distro_config_file")
CURRENT_WALL_PATH = parse_shell_var(DISTRO_CONFIG_PATH, "wallpaper_are") if DISTRO_CONFIG_PATH else None

# --- App constants ---
WALLPAPER_DIR = "/usr/share/my_stuff/my_wallpapers"
CACHE_DIR = os.path.expanduser("~/.cache/wallpaper_selector")
FIT_MODES = ["scaled", "centered", "zoom", "tiled", "fit"]
os.makedirs(CACHE_DIR, exist_ok=True)

# --- GUI class ---
class WallpaperSelector:
    def __init__(self, root):
        self.root = root
        self.root.title("Wallpaper Picker")
        self.root.geometry("800x600")

        self.font_name, self.font_size = get_gtk_font()
        self.font = (self.font_name, self.font_size)

        self.mode_var = StringVar(value=FIT_MODES[0])
        self.selected_path = CURRENT_WALL_PATH
        self.applied = False

        self.root.protocol("WM_DELETE_WINDOW", self.on_cancel)

        self.build_ui()

    def build_ui(self):
        self.loading_label = ttk.Label(self.root, text="Loading wallpapers...", font=self.font)
        self.loading_label.pack(pady=20)

        self.root.after(100, self.load_images_async)

    def load_images_async(self):
        threading.Thread(target=self.load_images).start()

    def load_images(self):
        try:
            files = [f for f in os.listdir(WALLPAPER_DIR)
                     if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp', '.webp'))]
        except Exception as e:
            print(f"Error loading images: {e}")
            self.root.quit()
            return

        self.root.after(0, self.setup_ui, files)

    def setup_ui(self, files):
        self.loading_label.destroy()

        # Top bar with mode and buttons
        control_frame = Frame(self.root)
        control_frame.pack(fill=X, padx=5, pady=5)

        ttk.Label(control_frame, text="Fit Mode:", font=self.font).pack(side=LEFT, padx=5)
        mode_menu = ttk.Combobox(control_frame, textvariable=self.mode_var, values=FIT_MODES, state="readonly", font=self.font)
        mode_menu.pack(side=LEFT)

        Button(control_frame, text="OK", font=self.font, command=self.on_ok).pack(side=RIGHT, padx=5)
        Button(control_frame, text="Cancel", font=self.font, command=self.on_cancel).pack(side=RIGHT)

        # Canvas for thumbnails
        self.canvas = Canvas(self.root)
        self.scroll_y = Scrollbar(self.root, orient=VERTICAL, command=self.canvas.yview)
        self.frame = Frame(self.canvas)
        self.frame.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.create_window((0, 0), window=self.frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scroll_y.set)
        self.canvas.pack(side=LEFT, fill=BOTH, expand=True)
        self.scroll_y.pack(side=RIGHT, fill=Y)

        for idx, file in enumerate(files):
            full_path = os.path.join(WALLPAPER_DIR, file)
            threading.Thread(target=self.load_thumbnail, args=(full_path, idx)).start()

    def load_thumbnail(self, path, idx):
        try:
            hash_id = hashlib.md5(path.encode()).hexdigest()
            cache_path = os.path.join(CACHE_DIR, f"{hash_id}.png")
            orig_mtime = os.path.getmtime(path)

            if not os.path.exists(cache_path) or os.path.getmtime(cache_path) < orig_mtime:
                subprocess.run([
                    "ffmpeg", "-y", "-i", path, "-vf", "scale=96:-1", cache_path
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            thumb = PhotoImage(file=cache_path)
            self.root.after(0, self.add_thumbnail_button, thumb, path, idx)
        except Exception as e:
            print(f"Thumbnail error for {path}: {e}")

    def add_thumbnail_button(self, photo, path, idx):
        btn = Button(self.frame, image=photo, command=lambda p=path: self.on_image_select(p))
        btn.image = photo
        btn.grid(row=idx // 5, column=idx % 5, padx=5, pady=5)

    def on_image_select(self, path):
        self.selected_path = path
        layout = self.mode_var.get()
        subprocess.run(["setbg", "-R", path, layout])
        self.applied = True

    def on_ok(self):
        self.root.destroy()

    def on_cancel(self):
        #if self.selected_path != CURRENT_WALL_PATH:
        #    subprocess.run(["setbg", "-R", CURRENT_WALL_PATH])
        self.root.destroy()

if __name__ == "__main__":
    root = Tk()
    app = WallpaperSelector(root)
    root.mainloop()

