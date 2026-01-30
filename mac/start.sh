name: macOS VNC Access

on: workflow_dispatch

jobs:
  vnc-setup:
    runs-on: macos-latest
    
    steps:
      - name: Setup VNC Server
        env:
          NGROK_TOKEN: ${{ secrets.NGROK_TOKEN }}
        run: |
          set -e
          
          echo "🔧 Disabling Spotlight indexing..."
          sudo mdutil -i off -a
          
          echo "👤 Creating admin user..."
          sudo dscl . -create /Users/vncadmin
          sudo dscl . -create /Users/vncadmin UserShell /bin/bash
          sudo dscl . -create /Users/vncadmin RealName "VNC Admin"
          sudo dscl . -create /Users/vncadmin UniqueID 1001
          sudo dscl . -create /Users/vncadmin PrimaryGroupID 80
          sudo dscl . -create /Users/vncadmin NFSHomeDirectory /Users/vncadmin
          sudo dscl . -passwd /Users/vncadmin "P@ssw0rd!"
          sudo createhomedir -c -u vncadmin > /dev/null
          sudo dscl . -append /Groups/admin GroupMembership vncadmin
          
          echo "🖥️ Configuring VNC..."
          # Enable Remote Management for all users
          sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
            -activate \
            -configure \
            -access -on \
            -allowAccessFor -allUsers \
            -privs -all \
            -clientopts -setvnclegacy -vnclegacy yes
          
          # Set VNC password (metodo corretto per macOS 15)
          sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
            -configure \
            -clientopts -setvncpw -vncpw "P@ssw0rd!"
          
          # Restart VNC service
          sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
            -restart -agent -console
          
          echo "⏳ Waiting for VNC to start..."
          sleep 5
          
          # Verify VNC is running
          if lsof -iTCP:5900 -sTCP:LISTEN > /dev/null 2>&1; then
            echo "✅ VNC server is running on port 5900"
          else
            echo "❌ VNC server failed to start"
            exit 1
          fi
          
          echo "📦 Installing ngrok..."
          brew install --cask ngrok
          
          echo "🔗 Starting ngrok tunnel..."
          ngrok config add-authtoken "$NGROK_TOKEN"
          ngrok tcp 5900 --region=us > /dev/null &
          
          sleep 5
          
          echo "🌐 Retrieving ngrok URL..."
          NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; print(json.load(sys.stdin)['tunnels'][0]['public_url'])" 2>/dev/null || echo "")
          
          if [ -n "$NGROK_URL" ]; then
            echo "=========================================="
            echo "✅ VNC Access Ready!"
            echo "=========================================="
            echo "URL: ${NGROK_URL}"
            echo "Username: vncadmin"
            echo "Password: P@ssw0rd!"
            echo "=========================================="
          else
            echo "⚠️ Could not retrieve ngrok URL. Check manually at http://localhost:4040"
          fi
          
          # Keep the workflow running
          echo "🔄 Keeping session alive (6 hours max)..."
          sleep 21600
          
