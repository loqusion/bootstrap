# GNOME

These are steps to perform after first logging in to a GNOME session:

1. Extensions (gnome-shell-extensions)

   - Removable Drive Menu
   - Status Icons
   - System Monitor
   - User Themes
   - Workspace Indicator

1. Extensions (Extra)

   - Blur my Shell
   - Caffeine
   - Clipboard Indicator
   - Dash to Dock
   - WireGuardVPN-extension

1. Enable experimental features:

   ```sh
   gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer', 'variable-refresh-rate']"
   ```

   - Then enable variable refresh rate (VRR) via Settings:
     Displays > \[Display\] > Refresh Rate > Variable Refresh Rate
