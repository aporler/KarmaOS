#!/usr/bin/env python3
"""
KarmaOS Welcome - Graphical Setup Wizard
Main GUI application
"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Vte', '2.91')
from gi.repository import Gtk, GdkPixbuf, Vte, GLib, Gdk
import os
import sys
import subprocess
import json

if os.environ.get('SNAP'):
    ASSETS_DIR = os.path.join(os.environ['SNAP'], 'share', 'karmaos')
else:
    ASSETS_DIR = '/usr/share/karmaos'

class KarmaOSWelcome(Gtk.Window):
    def __init__(self):
        super().__init__(title="KarmaOS Setup")
        self.set_default_size(800, 600)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_decorated(True)
        
        # State
        self.current_page = 0
        self.user_data = {}
        self.selected_apps = []
        self.is_live = self.detect_live_session()
        
        # Create notebook for pages
        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.add(self.notebook)
        
        # Create pages
        self.create_welcome_page()
        self.create_network_page()
        if not self.is_live:
            self.create_apps_page()
            self.create_install_page()
        else:
            self.create_live_install_page()
        self.create_finish_page()

    def detect_live_session(self) -> bool:
        """Return True when running from live media (casper)."""
        try:
            with open('/proc/cmdline', 'r', encoding='utf-8') as f:
                cmdline = f.read()
            if 'boot=casper' in cmdline or 'casper' in cmdline:
                return True
        except Exception:
            pass

        # Common live paths
        return os.path.exists('/cdrom') or os.path.exists('/run/casper') or os.path.exists('/rofs')

    def create_live_install_page(self):
        """Live-only page: explain and launch installer."""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(30)
        page.set_margin_bottom(30)
        page.set_valign(Gtk.Align.CENTER)

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Install KarmaOS</span>')
        page.pack_start(title, False, False, 0)

        desc = Gtk.Label()
        desc.set_text(
            "You are running the LiveCD.\n"
            "To install KarmaOS on your disk, launch the installer."
        )
        desc.set_justify(Gtk.Justification.CENTER)
        page.pack_start(desc, False, False, 0)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_halign(Gtk.Align.CENTER)

        installer_btn = Gtk.Button.new_with_label("Launch Installer")
        installer_btn.set_size_request(220, 45)
        installer_btn.connect("clicked", lambda w: self.launch_installer())
        btn_box.pack_start(installer_btn, False, False, 0)

        next_btn = Gtk.Button.new_with_label("Next")
        next_btn.connect("clicked", lambda w: self.next_page())
        btn_box.pack_start(next_btn, False, False, 0)

        page.pack_start(btn_box, False, False, 0)
        self.notebook.append_page(page)

    def launch_installer(self):
        """Launch Calamares installer."""
        for cmd in (["pkexec", "calamares"], ["sudo", "-E", "calamares"], ["calamares"]):
            try:
                subprocess.Popen(cmd)
                return
            except Exception:
                continue
        self.show_error("Installer not found or could not be started")

    def ensure_network(self):
        """Try to bring up networking using NetworkManager."""
        cmds = [
            ["sudo", "systemctl", "restart", "NetworkManager"],
            ["sudo", "nmcli", "networking", "on"],
            ["sudo", "nmcli", "radio", "wifi", "on"],
        ]
        for cmd in cmds:
            try:
                subprocess.run(cmd, check=False)
            except Exception:
                pass

        # Try to connect any wired device
        try:
            out = subprocess.check_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"], text=True)
            for line in out.splitlines():
                parts = line.split(':')
                if len(parts) >= 3:
                    dev, dev_type, state = parts[0], parts[1], parts[2]
                    if dev_type == 'ethernet' and state != 'connected':
                        subprocess.run(["sudo", "nmcli", "device", "connect", dev], check=False)
        except Exception:
            pass
        
    def create_welcome_page(self):
        """Page 1: Welcome"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(50)
        page.set_margin_bottom(50)
        page.set_valign(Gtk.Align.CENTER)
        
        # Logo
        logo_path = f"{ASSETS_DIR}/KarmaOSLogoPixel.png"
        if os.path.exists(logo_path):
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 200, 200, True)
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            page.pack_start(image, False, False, 0)
        
        # Welcome text
        welcome = Gtk.Label()
        welcome.set_markup('<span size="xx-large" weight="bold">Welcome to KarmaOS 26.01</span>')
        page.pack_start(welcome, False, False, 0)
        
        subtitle = Gtk.Label()
        subtitle.set_markup('<span size="large">A beautiful Ubuntu Core desktop experience</span>')
        subtitle.set_opacity(0.7)
        page.pack_start(subtitle, False, False, 0)
        
        # Description
        desc = Gtk.Label()
        desc.set_text("This wizard will guide you through the initial setup:\n" +
                      "• Network configuration\n" +
                      "• User account creation\n" +
                      "• Application installation")
        desc.set_justify(Gtk.Justification.LEFT)
        page.pack_start(desc, False, False, 20)
        
        # Next button
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        button_box.set_halign(Gtk.Align.END)
        next_btn = Gtk.Button.new_with_label("Get Started")
        next_btn.set_size_request(150, 40)
        next_btn.connect("clicked", lambda w: self.next_page())
        button_box.pack_end(next_btn, False, False, 0)
        page.pack_end(button_box, False, False, 0)
        
        self.notebook.append_page(page)
    
    def create_network_page(self):
        """Page 2: Network Configuration"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(30)
        page.set_margin_bottom(30)
        
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Network Configuration</span>')
        title.set_halign(Gtk.Align.START)
        page.pack_start(title, False, False, 0)
        
        desc = Gtk.Label()
        desc.set_text("Configure network connection for updates and app installation")
        desc.set_halign(Gtk.Align.START)
        desc.set_opacity(0.7)
        page.pack_start(desc, False, False, 0)
        
        # Network interfaces list
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        
        self.network_listbox = Gtk.ListBox()
        self.network_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        scroll.add(self.network_listbox)
        
        # Populate network interfaces
        self.populate_network_list()
        
        page.pack_start(scroll, True, True, 0)
        
        # Actions
        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        actions.set_halign(Gtk.Align.START)

        fix_btn = Gtk.Button.new_with_label("Fix Network (DHCP)")
        fix_btn.connect("clicked", lambda w: self.ensure_network())
        actions.pack_start(fix_btn, False, False, 0)

        skip_btn = Gtk.Button.new_with_label("Skip")
        skip_btn.connect("clicked", lambda w: self.next_page())
        actions.pack_start(skip_btn, False, False, 0)

        page.pack_start(actions, False, False, 0)
        
        # Navigation buttons
        nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        nav_box.set_spacing(10)
        back_btn = Gtk.Button.new_with_label("Back")
        back_btn.connect("clicked", lambda w: self.prev_page())
        next_btn = Gtk.Button.new_with_label("Next")
        next_btn.connect("clicked", lambda w: self.next_page())
        nav_box.pack_start(back_btn, False, False, 0)
        nav_box.pack_end(next_btn, False, False, 0)
        page.pack_end(nav_box, False, False, 0)
        
        self.notebook.append_page(page)
    
    def create_user_page(self):
        """Page 3: User Account Creation"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(30)
        page.set_margin_bottom(30)
        
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Create Your Account</span>')
        title.set_halign(Gtk.Align.START)
        page.pack_start(title, False, False, 0)
        
        # Form
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(15)
        
        # Full name
        grid.attach(Gtk.Label(label="Full Name:", halign=Gtk.Align.END), 0, 0, 1, 1)
        self.fullname_entry = Gtk.Entry()
        self.fullname_entry.set_placeholder_text("John Doe")
        self.fullname_entry.set_hexpand(True)
        grid.attach(self.fullname_entry, 1, 0, 1, 1)
        
        # Username
        grid.attach(Gtk.Label(label="Username:", halign=Gtk.Align.END), 0, 1, 1, 1)
        self.username_entry = Gtk.Entry()
        self.username_entry.set_placeholder_text("admin")
        grid.attach(self.username_entry, 1, 1, 1, 1)
        
        # Password
        grid.attach(Gtk.Label(label="Password:", halign=Gtk.Align.END), 0, 2, 1, 1)
        self.password_entry = Gtk.Entry()
        self.password_entry.set_visibility(False)
        self.password_entry.set_placeholder_text("Enter password")
        grid.attach(self.password_entry, 1, 2, 1, 1)
        
        # Confirm password
        grid.attach(Gtk.Label(label="Confirm:", halign=Gtk.Align.END), 0, 3, 1, 1)
        self.confirm_entry = Gtk.Entry()
        self.confirm_entry.set_visibility(False)
        self.confirm_entry.set_placeholder_text("Confirm password")
        grid.attach(self.confirm_entry, 1, 3, 1, 1)
        
        page.pack_start(grid, False, False, 20)
        
        # Navigation
        nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        nav_box.set_spacing(10)
        back_btn = Gtk.Button.new_with_label("Back")
        back_btn.connect("clicked", lambda w: self.prev_page())
        next_btn = Gtk.Button.new_with_label("Next")
        next_btn.connect("clicked", lambda w: self.validate_user_and_next())
        nav_box.pack_start(back_btn, False, False, 0)
        nav_box.pack_end(next_btn, False, False, 0)
        page.pack_end(nav_box, False, False, 0)
        
        self.notebook.append_page(page)
    
    def create_apps_page(self):
        """Page 4: Application Selection"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(30)
        page.set_margin_bottom(30)
        
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Select Applications</span>')
        title.set_halign(Gtk.Align.START)
        page.pack_start(title, False, False, 0)
        
        desc = Gtk.Label()
        desc.set_text("Choose which applications to install (you can add more later)")
        desc.set_halign(Gtk.Align.START)
        desc.set_opacity(0.7)
        page.pack_start(desc, False, False, 0)
        
        # App checkboxes
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        
        app_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        app_box.set_margin_start(20)
        app_box.set_margin_top(10)
        
        self.app_checks = {}
        apps = [
            ("firefox", "Firefox", "Mozilla web browser", True, True),
            ("libreoffice", "LibreOffice", "Office suite", True, False),
            ("thunderbird", "Thunderbird", "Email client", True, False),
            ("vlc", "VLC Media Player", "Video player", True, False),
        ]
        
        for snap_name, display_name, description, enabled, default in apps:
            check = Gtk.CheckButton.new_with_label(f"{display_name} - {description}")
            check.set_active(default)
            check.set_sensitive(enabled)
            self.app_checks[snap_name] = check
            app_box.pack_start(check, False, False, 0)
        
        scroll.add(app_box)
        page.pack_start(scroll, True, True, 0)
        
        # Navigation
        nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        nav_box.set_spacing(10)
        back_btn = Gtk.Button.new_with_label("Back")
        back_btn.connect("clicked", lambda w: self.prev_page())
        install_btn = Gtk.Button.new_with_label("Install")
        install_btn.connect("clicked", lambda w: self.start_installation())
        nav_box.pack_start(back_btn, False, False, 0)
        nav_box.pack_end(install_btn, False, False, 0)
        page.pack_end(nav_box, False, False, 0)
        
        self.notebook.append_page(page)
    
    def create_install_page(self):
        """Page 5: Installation Progress"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(30)
        page.set_margin_bottom(30)
        page.set_valign(Gtk.Align.CENTER)
        
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Installing KarmaOS</span>')
        page.pack_start(title, False, False, 0)
        
        self.install_label = Gtk.Label()
        self.install_label.set_text("Preparing installation...")
        page.pack_start(self.install_label, False, False, 0)
        
        self.install_progress = Gtk.ProgressBar()
        self.install_progress.set_show_text(True)
        page.pack_start(self.install_progress, False, False, 0)
        
        # Terminal output
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        self.install_terminal = Vte.Terminal()
        self.install_terminal.set_size(80, 24)
        scroll.add(self.install_terminal)
        page.pack_start(scroll, True, True, 10)
        
        self.notebook.append_page(page)
    
    def create_finish_page(self):
        """Page 6: Finish"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        page.set_margin_start(50)
        page.set_margin_end(50)
        page.set_margin_top(50)
        page.set_margin_bottom(50)
        page.set_valign(Gtk.Align.CENTER)
        
        # Success icon (checkmark)
        title = Gtk.Label()
        title.set_markup('<span size="xx-large">✓</span>')
        page.pack_start(title, False, False, 0)
        
        success = Gtk.Label()
        success.set_markup('<span size="x-large" weight="bold">KarmaOS is Ready!</span>')
        page.pack_start(success, False, False, 0)
        
        desc = Gtk.Label()
        desc.set_text("Your system has been configured successfully.\nClick Finish to start using KarmaOS.")
        desc.set_justify(Gtk.Justification.CENTER)
        page.pack_start(desc, False, False, 10)
        
        # Finish button
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        button_box.set_halign(Gtk.Align.CENTER)
        finish_btn = Gtk.Button.new_with_label("Finish & Reboot")
        finish_btn.set_size_request(200, 50)
        finish_btn.connect("clicked", lambda w: self.finish_setup())
        button_box.pack_start(finish_btn, False, False, 0)
        page.pack_start(button_box, False, False, 20)
        
        self.notebook.append_page(page)
    
    def populate_network_list(self):
        """Populate network interfaces"""
        row = Gtk.ListBoxRow()
        label = Gtk.Label(label="DHCP (Automatic) - Recommended", xalign=0)
        label.set_margin_start(10)
        label.set_margin_end(10)
        label.set_margin_top(10)
        label.set_margin_bottom(10)
        row.add(label)
        self.network_listbox.add(row)
    
    def validate_user_and_next(self):
        """Validate user input before proceeding"""
        username = self.username_entry.get_text()
        password = self.password_entry.get_text()
        confirm = self.confirm_entry.get_text()
        fullname = self.fullname_entry.get_text()
        
        if not username or not password:
            self.show_error("Please fill in all fields")
            return
        
        if password != confirm:
            self.show_error("Passwords do not match")
            return
        
        if len(password) < 4:
            self.show_error("Password must be at least 4 characters")
            return
        
        self.user_data = {
            'username': username,
            'password': password,
            'fullname': fullname or username
        }
        
        self.next_page()
    
    def start_installation(self):
        """Start the installation process"""
        # Collect selected apps
        self.selected_apps = [
            snap for snap, check in self.app_checks.items() 
            if check.get_active()
        ]
        
        self.next_page()
        GLib.timeout_add(500, self.run_installation)
    
    def run_installation(self):
        """Run the actual installation"""
        total_apps = len(self.selected_apps)
        current = 0
        
        # Install each app
        for pkg in self.selected_apps:
            self.install_label.set_text(f"Installing {pkg}...")
            self.install_progress.set_fraction(0 if total_apps == 0 else (current / total_apps))
            self.install_apt(pkg)
            current += 1
        
        # Configure wallpaper
        self.configure_system()
        
        self.install_progress.set_fraction(1.0)
        self.install_label.set_text("Installation complete!")
        
        GLib.timeout_add(2000, self.next_page)
        return False
    
    def install_apt(self, package_name: str):
        """Install a deb package via apt."""
        cmd = ["sudo", "apt-get", "update"]
        self.run_command(cmd)
        cmd = ["sudo", "apt-get", "install", "-y", package_name]
        self.run_command(cmd)
    
    def configure_system(self):
        """Configure system settings"""
        # Set wallpaper (will be applied when user logs in)
        wallpaper_path = f"{ASSETS_DIR}/KarmaOSBack.png"
        if os.path.exists(wallpaper_path):
            user_home = f"/home/{self.user_data['username']}"
            subprocess.run(["sudo", "cp", wallpaper_path, f"{user_home}/.wallpaper.png"])
    
    def run_command(self, cmd):
        """Run command and display in terminal"""
        if isinstance(cmd, list):
            cmd = ' '.join(cmd)
        self.install_terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT,
            os.environ['HOME'],
            ["/bin/bash", "-c", cmd],
            [],
            GLib.SpawnFlags.DO_NOT_REAP_CHILD,
            None,
            None,
        )
    
    def finish_setup(self):
        """Finish setup and reboot"""
        subprocess.run(["sudo", "reboot"])
        Gtk.main_quit()
    
    def show_error(self, message):
        """Show error dialog"""
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=message
        )
        dialog.run()
        dialog.destroy()
    
    def next_page(self):
        """Go to next page"""
        self.current_page += 1
        self.notebook.set_current_page(self.current_page)
    
    def prev_page(self):
        """Go to previous page"""
        self.current_page -= 1
        self.notebook.set_current_page(self.current_page)

def main():
    win = KarmaOSWelcome()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    win.fullscreen()  # Fullscreen pour l'expérience immersive
    Gtk.main()

if __name__ == "__main__":
    main()
