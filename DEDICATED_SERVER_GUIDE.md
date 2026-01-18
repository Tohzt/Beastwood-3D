# Beastwood Dedicated Server Implementation Guide

This guide covers deploying Beastwood to a DigitalOcean droplet as a headless dedicated server.

---

## Part 1: Code Modifications to world.gd

### Step 1: Add New Variables

After line 14 (`var enet_peer`), add:

```gdscript
var is_dedicated_server := false
var admin_peer_id := -1  # First player to connect becomes admin
```

### Step 2: Modify _ready() Function

Replace the current `_ready()` function with:

```gdscript
func _ready():
	ThreeOnOnePole.hide()
	color_picker.hide()
	pause_menu.hide()

	# Check for dedicated server mode via command line
	var args = OS.get_cmdline_args()
	if "--server" in args:
		_start_dedicated_server()
	else:
		login_menu.show()
```

### Step 3: Add Dedicated Server Functions

Add these new functions after `_ready()`:

```gdscript
func _start_dedicated_server():
	is_dedicated_server = true
	login_menu.hide()
	print("[SERVER] Starting dedicated server on port %d..." % PORT)

	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(PORT)
	if error != OK:
		print("[SERVER] Failed to create server: %s" % error_string(error))
		get_tree().quit(1)
		return

	enet_peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(enet_peer)
	multiplayer.peer_connected.connect(_on_peer_connected_dedicated)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected_dedicated)
	print("[SERVER] Server started successfully. Waiting for players...")

func _on_peer_connected_dedicated(peer_id):
	print("[SERVER] Player connected: %d" % peer_id)
	# First player becomes admin
	if admin_peer_id == -1:
		admin_peer_id = peer_id
		print("[SERVER] Player %d is now the admin" % peer_id)
	add_player(peer_id)

func _on_peer_disconnected_dedicated(peer_id):
	print("[SERVER] Player disconnected: %d" % peer_id)
	remove_player(peer_id)
	# If admin disconnects, promote the next player
	if peer_id == admin_peer_id:
		var players = get_tree().get_nodes_in_group("Players")
		if players.size() > 0:
			admin_peer_id = int(str(players[0].name))
			print("[SERVER] New admin: %d" % admin_peer_id)
		else:
			admin_peer_id = -1
			print("[SERVER] No players remaining, no admin")

func is_admin() -> bool:
	if is_dedicated_server:
		return false  # Server itself is never "admin" in gameplay sense
	# On client: check if we are the admin
	return multiplayer.get_unique_id() == admin_peer_id or multiplayer.is_server()
```

### Step 4: Update Admin Permission Checks

In `_unhandled_input()`, change line 26 from:

```gdscript
other_respawns.visible = is_multiplayer_authority()
```

To:

```gdscript
other_respawns.visible = is_admin()
```

### Step 5: Sync Admin ID to Clients (Optional but Recommended)

Add an RPC to notify clients who the admin is:

```gdscript
@rpc("authority", "call_remote", "reliable")
func _sync_admin_id(peer_id):
	admin_peer_id = peer_id
```

Then in `_on_peer_connected_dedicated()`, after setting admin, broadcast it:

```gdscript
if admin_peer_id == peer_id:
	_sync_admin_id.rpc(peer_id)
```

---

## Part 2: Export for Linux

### Step 1: Download Linux Export Template

1. In Godot, go to **Editor → Manage Export Templates**
2. Download templates for your Godot version (4.5.1)
3. Make sure the Linux template is installed

### Step 2: Create Linux Export Preset

1. Go to **Project → Export**
2. Click **Add...** and select **Linux**
3. Configure:
   - **Export Path**: `Exports/Linux/BeastwoodServer.x86_64`
   - **Architecture**: x86_64
   - **Embed PCK**: Enabled (creates single executable)

### Step 3: Export the Project

1. Click **Export Project**
2. Uncheck "Export With Debug" for production
3. Save to `Exports/Linux/BeastwoodServer.x86_64`

This creates two files:
- `BeastwoodServer.x86_64` (the executable)
- `BeastwoodServer.pck` (game data, embedded if you enabled it)

---

## Part 3: Droplet Setup

### Step 1: SSH into Your Droplet

```bash
ssh root@YOUR_DROPLET_IP
```

### Step 2: Create Game Directory

```bash
mkdir -p /opt/beastwood
cd /opt/beastwood
```

### Step 3: Upload Game Files

From your local Windows machine (use PowerShell or Git Bash):

```bash
scp Exports/Linux/BeastwoodServer.x86_64 root@YOUR_DROPLET_IP:/opt/beastwood/
scp Exports/Linux/BeastwoodServer.pck root@YOUR_DROPLET_IP:/opt/beastwood/  # If not embedded
```

### Step 4: Make Executable

On the droplet:

```bash
chmod +x /opt/beastwood/BeastwoodServer.x86_64
```

### Step 5: Configure Firewall

```bash
# If using ufw
ufw allow 8910/udp
ufw status

# If using iptables directly
iptables -A INPUT -p udp --dport 8910 -j ACCEPT
```

### Step 6: Install Required Libraries (if needed)

Godot headless may need some libraries:

```bash
apt update
apt install -y libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1
```

For truly headless (no X11), you might not need these, but they don't hurt.

---

## Part 4: Running the Server

### Option A: Direct Run (for testing)

```bash
cd /opt/beastwood
./BeastwoodServer.x86_64 --headless --server
```

### Option B: Run in Background with Screen

```bash
apt install screen
screen -S beastwood
./BeastwoodServer.x86_64 --headless --server
# Press Ctrl+A then D to detach
# Use 'screen -r beastwood' to reattach
```

### Option C: Systemd Service (Recommended for Production)

Create `/etc/systemd/system/beastwood.service`:

```ini
[Unit]
Description=Beastwood Game Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/beastwood
ExecStart=/opt/beastwood/BeastwoodServer.x86_64 --headless --server
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Then enable and start:

```bash
systemctl daemon-reload
systemctl enable beastwood
systemctl start beastwood

# Check status
systemctl status beastwood

# View logs
journalctl -u beastwood -f
```

---

## Part 5: Client Configuration

### Update the Server Address

In your local game, change the `Address` export variable in `world.gd`:

```gdscript
@export var Address = "YOUR_DROPLET_IP"  # e.g., "164.92.xxx.xxx"
```

Or set it in the Godot editor via the Inspector when selecting the world node.

### Connecting

1. Launch your local Windows game normally
2. Click **Join** (not Host)
3. You'll connect to the droplet server
4. First person to connect becomes the admin

---

## Part 6: Testing Checklist

### On the Droplet

```bash
# Check if server is running
systemctl status beastwood

# Check if port is listening
ss -tuln | grep 8910

# Check logs for connections
journalctl -u beastwood -f
```

### From Windows

```powershell
# Test UDP connectivity (requires nmap or similar)
# Or just try connecting with the game client
```

---

## Troubleshooting

### "Failed to create server" Error
- Port already in use: `ss -tuln | grep 8910` then kill the process
- Permission issue: Run as root or use a port > 1024

### Clients Can't Connect
- Check firewall: `ufw status` or `iptables -L`
- Verify port is listening: `ss -tuln | grep 8910`
- Check droplet's cloud firewall in DigitalOcean dashboard

### Server Crashes Immediately
- Check logs: `journalctl -u beastwood -n 50`
- Run manually to see errors: `./BeastwoodServer.x86_64 --headless --server`

### Missing Libraries
```bash
ldd ./BeastwoodServer.x86_64 | grep "not found"
# Install any missing libraries
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `systemctl start beastwood` | Start server |
| `systemctl stop beastwood` | Stop server |
| `systemctl restart beastwood` | Restart server |
| `journalctl -u beastwood -f` | View live logs |
| `ss -tuln \| grep 8910` | Check if port is listening |
| `ufw allow 8910/udp` | Open firewall port |
