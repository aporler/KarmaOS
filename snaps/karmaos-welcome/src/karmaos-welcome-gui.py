#!/usr/bin/env python3
"""
KarmaOS Welcome - Graphical Setup Wizard
Live CD / First Boot experience
"""

import gi
gi.require_version('Gtk', '3.0')
# Try to load WebKit - prefer 6.0, fallback to 4.1, then 4.0
try:
    gi.require_version('WebKit', '6.0')
    from gi.repository import Gtk, GdkPixbuf, GLib, Gdk
    from gi.repository import WebKit as WebKit2
    WEBKIT_AVAILABLE = True
except (ValueError, ImportError):
    try:
        gi.require_version('WebKit2', '4.1')
        from gi.repository import Gtk, GdkPixbuf, GLib, Gdk, WebKit2
        WEBKIT_AVAILABLE = True
    except (ValueError, ImportError):
        try:
            gi.require_version('WebKit2', '4.0')
            from gi.repository import Gtk, GdkPixbuf, GLib, Gdk, WebKit2
            WEBKIT_AVAILABLE = True
        except (ValueError, ImportError):
            from gi.repository import Gtk, GdkPixbuf, GLib, Gdk
            WEBKIT_AVAILABLE = False
import os
import subprocess

if os.environ.get('SNAP'):
    ASSETS_DIR = os.path.join(os.environ['SNAP'], 'share', 'karmaos')
else:
    ASSETS_DIR = '/usr/share/karmaos'


class KarmaOSWelcome(Gtk.Window):
    def __init__(self):
        super().__init__(title="KarmaOS Welcome")
        self.set_default_size(900, 650)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_decorated(True)

        # State
        self.current_page = 0
        self.is_live = self.detect_live_session()
        self.selected_keyboard = "ca"

        # Main container
        self.notebook = Gtk.Notebook()
        self.notebook.set_show_tabs(False)
        self.notebook.set_show_border(False)
        self.add(self.notebook)

        # Build pages based on context
        if self.is_live:
            self.create_live_pages()
        else:
            self.create_installed_pages()

    # ─────────────────────────────────────────────────────────────
    # Detection
    # ─────────────────────────────────────────────────────────────
    def detect_live_session(self) -> bool:
        """Return True when running from live media (casper)."""
        try:
            with open('/proc/cmdline', 'r', encoding='utf-8') as f:
                cmdline = f.read()
            if 'boot=casper' in cmdline or 'casper' in cmdline:
                return True
        except Exception:
            pass
        return os.path.exists('/cdrom') or os.path.exists('/run/casper') or os.path.exists('/rofs')

    # ─────────────────────────────────────────────────────────────
    # LIVE CD pages
    # ─────────────────────────────────────────────────────────────
    def create_live_pages(self):
        self.create_page_welcome()
        self.create_page_network()
        self.create_page_vision()
        self.create_page_keyboard()
        self.create_page_choice()
        self.create_page_web()

    # Page 1: Welcome
    def create_page_welcome(self):
        page = self._page_box()

        logo_path = f"{ASSETS_DIR}/KarmaOSLogoPixel.png"
        if os.path.exists(logo_path):
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 180, 180, True)
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            page.pack_start(image, False, False, 0)

        title = Gtk.Label()
        title.set_markup('<span size="xx-large" weight="bold">Bienvenue dans KarmaOS 26.01</span>')
        page.pack_start(title, False, False, 10)

        subtitle = Gtk.Label()
        subtitle.set_markup('<span size="large">Le système d\'exploitation fait au Québec</span>')
        subtitle.set_opacity(0.7)
        page.pack_start(subtitle, False, False, 0)

        btn = Gtk.Button.new_with_label("Commencer")
        btn.set_size_request(180, 45)
        btn.connect("clicked", lambda w: self.next_page())
        page.pack_start(btn, False, False, 30)

        self.notebook.append_page(page)

    # Page 2: Network
    def create_page_network(self):
        page = self._page_box()

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Connexion Internet</span>')
        page.pack_start(title, False, False, 0)

        desc = Gtk.Label()
        desc.set_text("Assurez-vous d'être connecté à Internet pour télécharger les mises à jour.")
        desc.set_line_wrap(True)
        desc.set_max_width_chars(60)
        desc.set_justify(Gtk.Justification.CENTER)
        page.pack_start(desc, False, False, 10)

        # Status label
        self.net_status = Gtk.Label()
        self.net_status.set_markup('<span foreground="gray">Vérification...</span>')
        page.pack_start(self.net_status, False, False, 10)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btn_box.set_halign(Gtk.Align.CENTER)

        fix_btn = Gtk.Button.new_with_label("Réparer le réseau")
        fix_btn.connect("clicked", self.on_fix_network)
        btn_box.pack_start(fix_btn, False, False, 0)

        refresh_btn = Gtk.Button.new_with_label("Actualiser")
        refresh_btn.connect("clicked", lambda w: self.check_network())
        btn_box.pack_start(refresh_btn, False, False, 0)

        page.pack_start(btn_box, False, False, 10)

        nav = self._nav_box(back=True, next_label="Suivant")
        page.pack_end(nav, False, False, 0)

        self.notebook.append_page(page)
        GLib.timeout_add(500, self.check_network)

    def check_network(self):
        """Check internet connectivity."""
        try:
            ret = subprocess.run(
                ["ping", "-c", "1", "-W", "2", "8.8.8.8"],
                capture_output=True, timeout=5
            )
            if ret.returncode == 0:
                self.net_status.set_markup('<span foreground="green">✓ Connecté à Internet</span>')
            else:
                self.net_status.set_markup('<span foreground="orange">⚠ Pas de connexion Internet</span>')
        except Exception:
            self.net_status.set_markup('<span foreground="red">✗ Erreur réseau</span>')
        return False

    def on_fix_network(self, widget):
        """Try to fix networking."""
        self.net_status.set_markup('<span foreground="gray">Réparation en cours...</span>')
        cmds = [
            ["sudo", "systemctl", "restart", "NetworkManager"],
            ["sudo", "nmcli", "networking", "on"],
            ["sudo", "nmcli", "radio", "wifi", "on"],
        ]
        for cmd in cmds:
            try:
                subprocess.run(cmd, check=False, timeout=10)
            except Exception:
                pass
        # Try wired connect
        try:
            out = subprocess.check_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"], text=True, timeout=5)
            for line in out.splitlines():
                parts = line.split(':')
                if len(parts) >= 3 and parts[1] == 'ethernet' and parts[2] != 'connected':
                    subprocess.run(["sudo", "nmcli", "device", "connect", parts[0]], check=False, timeout=10)
        except Exception:
            pass
        GLib.timeout_add(2000, self.check_network)

    # Page 3: Vision
    def create_page_vision(self):
        page = self._page_box()

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Notre Vision</span>')
        page.pack_start(title, False, False, 0)

        vision_text = (
            "Offrir un système d'exploitation fait au Québec qui respecte l'utilisateur :\n"
            "ouvert, communautaire et libre de tout logiciel propriétaire imposé.\n\n"
            "Une solution pour ceux qui veulent passer à Linux sans se compliquer la vie,\n"
            "que leur ordinateur soit neuf ou vieillissant !"
        )
        vision = Gtk.Label()
        vision.set_text(vision_text)
        vision.set_line_wrap(True)
        vision.set_max_width_chars(70)
        vision.set_justify(Gtk.Justification.CENTER)
        page.pack_start(vision, False, False, 20)

        # English version (smaller)
        en_text = (
            "To offer a Quebec-made operating system that respects the user:\n"
            "open, community-driven, and free of imposed proprietary software.\n"
            "A solution for people who want to switch to Linux without making their lives complicated,\n"
            "whether their computer is new or aging!"
        )
        en_label = Gtk.Label()
        en_label.set_markup(f'<span size="small" style="italic" foreground="gray">{en_text}</span>')
        en_label.set_line_wrap(True)
        en_label.set_max_width_chars(80)
        en_label.set_justify(Gtk.Justification.CENTER)
        page.pack_start(en_label, False, False, 10)

        nav = self._nav_box(back=True, next_label="Suivant")
        page.pack_end(nav, False, False, 0)

        self.notebook.append_page(page)

    # Page 4: Keyboard
    def create_page_keyboard(self):
        page = self._page_box()

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Configuration du clavier</span>')
        page.pack_start(title, False, False, 0)

        desc = Gtk.Label()
        desc.set_text("Sélectionnez la disposition de votre clavier :")
        page.pack_start(desc, False, False, 10)

        # Keyboard combo
        keyboard_store = Gtk.ListStore(str, str)
        keyboards = [
            ("ca", "Canadien français"),
            ("us", "Anglais (US)"),
            ("fr", "Français (AZERTY)"),
            ("gb", "Anglais (UK)"),
            ("de", "Allemand"),
            ("es", "Espagnol"),
        ]
        for code, name in keyboards:
            keyboard_store.append([code, name])

        self.keyboard_combo = Gtk.ComboBox.new_with_model(keyboard_store)
        renderer = Gtk.CellRendererText()
        self.keyboard_combo.pack_start(renderer, True)
        self.keyboard_combo.add_attribute(renderer, "text", 1)
        self.keyboard_combo.set_active(0)  # Default: ca (Canadien français)
        self.keyboard_combo.connect("changed", self.on_keyboard_changed)
        page.pack_start(self.keyboard_combo, False, False, 10)

        # Test entry
        test_label = Gtk.Label()
        test_label.set_text("Testez votre clavier ici :")
        page.pack_start(test_label, False, False, 10)

        self.keyboard_test = Gtk.Entry()
        self.keyboard_test.set_placeholder_text("Tapez pour tester...")
        self.keyboard_test.set_size_request(300, -1)
        page.pack_start(self.keyboard_test, False, False, 0)

        nav = self._nav_box(back=True, next_label="Suivant")
        page.pack_end(nav, False, False, 0)

        self.notebook.append_page(page)

    def on_keyboard_changed(self, combo):
        tree_iter = combo.get_active_iter()
        if tree_iter:
            model = combo.get_model()
            code = model[tree_iter][0]
            self.selected_keyboard = code
            try:
                subprocess.run(["setxkbmap", code], check=False, timeout=5)
            except Exception:
                pass

    # Page 5: Choice (Install or Try)
    def create_page_choice(self):
        page = self._page_box()

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Que voulez-vous faire ?</span>')
        page.pack_start(title, False, False, 0)

        desc = Gtk.Label()
        desc.set_text("Vous pouvez essayer KarmaOS sans l'installer, ou l'installer maintenant.")
        desc.set_line_wrap(True)
        page.pack_start(desc, False, False, 20)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        btn_box.set_halign(Gtk.Align.CENTER)

        install_btn = Gtk.Button()
        install_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        install_box.set_margin_top(10)
        install_box.set_margin_bottom(10)
        install_box.set_margin_start(30)
        install_box.set_margin_end(30)
        install_title = Gtk.Label()
        install_title.set_markup('<span weight="bold" size="large">Installer KarmaOS</span>')
        install_desc = Gtk.Label()
        install_desc.set_text("Installe KarmaOS sur votre disque dur")
        install_desc.set_opacity(0.7)
        install_box.pack_start(install_title, False, False, 0)
        install_box.pack_start(install_desc, False, False, 0)
        install_btn.add(install_box)
        install_btn.set_size_request(350, 80)
        install_btn.connect("clicked", self.on_install_clicked)
        btn_box.pack_start(install_btn, False, False, 0)

        try_btn = Gtk.Button()
        try_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        try_box.set_margin_top(10)
        try_box.set_margin_bottom(10)
        try_box.set_margin_start(30)
        try_box.set_margin_end(30)
        try_title = Gtk.Label()
        try_title.set_markup('<span weight="bold" size="large">Essayer KarmaOS</span>')
        try_desc = Gtk.Label()
        try_desc.set_text("Découvrez KarmaOS sans modifier votre ordinateur")
        try_desc.set_opacity(0.7)
        try_box.pack_start(try_title, False, False, 0)
        try_box.pack_start(try_desc, False, False, 0)
        try_btn.add(try_box)
        try_btn.set_size_request(350, 80)
        try_btn.connect("clicked", self.on_try_clicked)
        btn_box.pack_start(try_btn, False, False, 0)

        page.pack_start(btn_box, False, False, 0)

        back_btn = Gtk.Button.new_with_label("Retour")
        back_btn.connect("clicked", lambda w: self.prev_page())
        back_box = Gtk.Box()
        back_box.set_halign(Gtk.Align.START)
        back_box.pack_start(back_btn, False, False, 0)
        page.pack_end(back_box, False, False, 0)

        self.notebook.append_page(page)

    def on_install_clicked(self, widget):
        """Launch installer and go to final page."""
        self.launch_installer()
        self.next_page()

    def on_try_clicked(self, widget):
        """Just go to final page."""
        self.next_page()

    def launch_installer(self):
        """Launch Calamares installer."""
        try:
            subprocess.Popen(["/usr/local/bin/karmaos-installer"])
        except Exception:
            try:
                subprocess.Popen(["sudo", "-E", "calamares"])
            except Exception:
                self.show_error("Impossible de lancer l'installateur")

    # Page 6: Web page + Close
    def create_page_web(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_start(20)
        page.set_margin_end(20)
        page.set_margin_top(20)
        page.set_margin_bottom(20)

        title = Gtk.Label()
        title.set_markup('<span size="large" weight="bold">Ressources KarmaOS</span>')
        page.pack_start(title, False, False, 0)

        if WEBKIT_AVAILABLE:
            # WebKit WebView
            self.webview = WebKit2.WebView()
            self.webview.load_uri("https://karmaos.ovh/karmaos-welcome/")
            self.webview.set_vexpand(True)
            self.webview.set_hexpand(True)

            scroll = Gtk.ScrolledWindow()
            scroll.set_vexpand(True)
            scroll.add(self.webview)
            page.pack_start(scroll, True, True, 0)
        else:
            # Fallback: show link as text
            info = Gtk.Label()
            info.set_markup(
                '<span size="large">Pour plus d\'informations, visitez :\n\n'
                '<a href="https://karmaos.ovh/karmaos-welcome/">https://karmaos.ovh/karmaos-welcome/</a></span>'
            )
            info.set_justify(Gtk.Justification.CENTER)
            info.set_line_wrap(True)
            page.pack_start(info, True, True, 0)

        # Close button
        close_btn = Gtk.Button.new_with_label("Fermer")
        close_btn.set_size_request(150, 45)
        close_btn.connect("clicked", lambda w: Gtk.main_quit())
        btn_box = Gtk.Box()
        btn_box.set_halign(Gtk.Align.CENTER)
        btn_box.pack_start(close_btn, False, False, 0)
        page.pack_start(btn_box, False, False, 10)

        self.notebook.append_page(page)

    # ─────────────────────────────────────────────────────────────
    # INSTALLED system pages (first boot after install)
    # ─────────────────────────────────────────────────────────────
    def create_installed_pages(self):
        self.create_installed_welcome()

    def create_installed_welcome(self):
        page = self._page_box()

        logo_path = f"{ASSETS_DIR}/KarmaOSLogoPixel.png"
        if os.path.exists(logo_path):
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 150, 150, True)
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            page.pack_start(image, False, False, 0)

        title = Gtk.Label()
        title.set_markup('<span size="xx-large" weight="bold">Bienvenue dans KarmaOS !</span>')
        page.pack_start(title, False, False, 10)

        desc = Gtk.Label()
        desc.set_text(
            "Votre installation est terminée.\n"
            "Profitez de votre nouveau système d'exploitation québécois !"
        )
        desc.set_justify(Gtk.Justification.CENTER)
        page.pack_start(desc, False, False, 20)

        btn = Gtk.Button.new_with_label("Commencer à utiliser KarmaOS")
        btn.set_size_request(280, 50)
        btn.connect("clicked", lambda w: Gtk.main_quit())
        page.pack_start(btn, False, False, 0)

        self.notebook.append_page(page)

    # ─────────────────────────────────────────────────────────────
    # Helpers
    # ─────────────────────────────────────────────────────────────
    def _page_box(self):
        """Create a standard page container."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box.set_margin_start(50)
        box.set_margin_end(50)
        box.set_margin_top(40)
        box.set_margin_bottom(40)
        box.set_valign(Gtk.Align.CENTER)
        box.set_halign(Gtk.Align.CENTER)
        return box

    def _nav_box(self, back=False, next_label="Suivant"):
        """Create navigation buttons."""
        nav = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        nav.set_margin_top(20)
        if back:
            back_btn = Gtk.Button.new_with_label("Retour")
            back_btn.connect("clicked", lambda w: self.prev_page())
            nav.pack_start(back_btn, False, False, 0)
        next_btn = Gtk.Button.new_with_label(next_label)
        next_btn.connect("clicked", lambda w: self.next_page())
        nav.pack_end(next_btn, False, False, 0)
        return nav

    def next_page(self):
        self.current_page += 1
        self.notebook.set_current_page(self.current_page)

    def prev_page(self):
        self.current_page -= 1
        self.notebook.set_current_page(self.current_page)

    def show_error(self, message):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=message
        )
        dialog.run()
        dialog.destroy()


def main():
    win = KarmaOSWelcome()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
