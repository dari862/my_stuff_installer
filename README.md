# experimental

# my-stuff-script

```
bash <(wget -q -O - https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/installer.sh 2>/dev/null || curl -s https://raw.githubusercontent.com/dari862/my_stuff_installer/main/core/installer.sh 2>/dev/null)
```

# my-stuff-script (deploy dev env)

```

bash <(wget -q -O - https://raw.githubusercontent.com/dari862/my_stuff_installer/main/For_dev/pre_dev_env 2>/dev/null || curl -s https://raw.githubusercontent.com/dari862/my_stuff_installer/main/For_dev/pre_dev_env 2>/dev/null)
```

<details>
	<summary><h1>to fix</h1></summary>
	
		# exisitng terminator
		<window.Window object at 0x7fcaf812cc80 (terminatorlib+window+Window at 0x2b92280)> is not in registered window list
		
		# unknown
		thunar-volman: Unsupported USB device type "usb".
		thunar-volman: Unsupported USB device type "usbhid".
		
		(xfce4-power-manager:1935): GLib-CRITICAL **: 15:08:33.727: g_variant_unref: assertion 'value != NULL' failed
		
		(openbox:1282): GLib-CRITICAL **: 14:42:09.553: Source ID 129 was not found when attempting to remove it
		
</details>

<details>	
	<summary><h1>bugges</h1></summary>

		# qt5 and kvantom and feather as root
		QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to '/tmp/runtime-root'

		#  runing terminator as root
		Unable to open ‘/etc/xdg/terminator/config’ for reading and/or writting.
		([Errno 2] No such file or directory: '/etc/xdg/terminator/config')
		ConfigBase::load: Unable to open /etc/xdg/terminator/config ([Errno 2] No such file or directory: '/etc/xdg/terminator/config')
		
		# nano as root
		[355 14:44:00.567276] [PARSE ERROR] Unknown char after ESC: 0x6b
		[355 14:44:00.567317] [PARSE ERROR] Unknown char after ESC: 0x5c
		[355 14:44:00.567327] [PARSE ERROR] Unknown char after ESC: 0x6b
		[355 14:44:00.567413] [PARSE ERROR] Unknown char after ESC: 0x5c
		
		# ranger as root
		[355 14:45:46.215095] [PARSE ERROR] Unrecognized DCS code: 0x7a
		[355 14:45:46.215127] [PARSE ERROR] Unknown CSI code: 'm' with start_modifier: '' and end_modifier: '%' and parameters: '0'
		[355 14:45:46.236393] [PARSE ERROR] Unknown terminfo property: PS
		[355 14:45:46.236469] [PARSE ERROR] Unknown terminfo property: PE
		
		# qt5 config as root
		Configuration path: "/root/.config/qt5ct"
		Shared QSS paths: ("/root/.local/share/qt5ct/qss", "/usr/local/share/qt5ct/qss", "/usr/share/qt5ct/qss")
		Shared color scheme paths: ("/root/.local/share/qt5ct/colors", "/usr/local/share/qt5ct/colors", "/usr/share/qt5ct/colors")
		/usr/share/my_stuff/bin/rofi/apps_as_root: line 55:  4625 Segmentation fault      sudo -A ${command_2_run}
		
		# plank
		[CRITICAL 14:38:22.855476] [Wnck] wnck_set_client_type: changing the client type is not supported.
		[WARN 14:38:23.672428] [Preferences:192] '/usr/share/plank/themes/Default/dock.theme' is read-only!
		[WARN 14:38:24.064730] Creating surface took WAY TOO LONG (41ms), enabled downscaling for this cache!
		[WARN 14:41:46.438192] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.472304] Failed to fetch type: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.508960] Failed to fetch monitor: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.550823] Failed to fetch maximized state: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.581311] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.612146] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 14:41:46.642666] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.494623] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.525799] Failed to fetch type: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.561358] Failed to fetch monitor: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.603246] Failed to fetch maximized state: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.633729] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.664108] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 16:14:51.694406] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.717666] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.750609] Failed to fetch type: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.786699] Failed to fetch monitor: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.830850] Failed to fetch maximized state: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.877043] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.909080] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”
		[WARN 20:46:07.939848] Failed to fetch xid: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: Object does not exist at path “/org/ayatana/bamf/window/62914852”

</details>
