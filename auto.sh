#!/bin/bash

# Set your Bitcoin ABC directory
ABC_DIR="${1:-/root}"
USER="${2:-root}"

# Get the latest version from URL
LATEST_VER=$(curl -Ls https://download.bitcoinabc.org/latest | grep -oP 'fabien-sha256sums\.\K[0-9]+\.[0-9]+\.[0-9]+(?=\.asc)' | head -n 1)
echo "Latest version from URL is: $LATEST_VER"

# Check current version
CURRENT_VER=""
for dir in $ABC_DIR/bitcoin-abc-*; do
    if [[ -d $dir ]]; then
        ver=$(basename $dir)
        ver=${ver#"bitcoin-abc-"}
        if [[ "$ver" > "$CURRENT_VER" ]]; then
            CURRENT_VER=$ver
        fi
    fi
done
echo "Current installed version is: $CURRENT_VER"

# Download and extract new version
if [[ "$LATEST_VER" != "$CURRENT_VER" ]]; then
    echo "Latest version is different from current, update needed."
    echo "Downloading and extracting new version"
    wget -O bitcoin-abc-$LATEST_VER-x86_64-linux-gnu.tar.gz https://download.bitcoinabc.org/$LATEST_VER/linux/bitcoin-abc-$LATEST_VER-x86_64-linux-gnu.tar.gz
    tar xzf bitcoin-abc-$LATEST_VER-x86_64-linux-gnu.tar.gz
fi

# Update or create new systemd service configuration
if [[ -f /etc/systemd/system/ecashd.service ]]; then
    echo "Updating systemd service configuration"
    echo "Current version: $CURRENT_VER"
    echo "Latest version: $LATEST_VER"
    sed -i "s|bitcoin-abc-[0-9]*\.[0-9]*\.[0-9]*|bitcoin-abc-$LATEST_VER|g" /etc/systemd/system/ecashd.service
    echo "Service configuration after update:"
    cat /etc/systemd/system/ecashd.service
else
    echo "Creating new systemd service configuration"
    cat <<EOT > /etc/systemd/system/ecashd.service
[Unit]
Description=eCash node
After=network.target

[Service]
ExecStartPre=/bin/bash -c 'mv /root/.bitcoin/debug.log /root/.bitcoin/debug_$(date +%%Y%%m%%d%%H%%M%%S).log'
ExecStart=/root/bitcoin-abc-$LATEST_VER/bin/bitcoind -conf=/root/.bitcoin/bitcoin.conf -pid=/root/.bitcoin/bitcoind.pid
User=$USER
Type=forking
PIDFile=/root/.bitcoin/bitcoind.pid
Restart=unless-stopped
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=default.target
EOT
    echo "New service configuration content:"
    cat /etc/systemd/system/ecashd.service
fi

# Reload systemd configuration
systemctl daemon-reload

# If current version is different from latest, perform relevant actions
if [[ "$LATEST_VER" != "$CURRENT_VER" ]]; then
    if [[ $CURRENT_VER != "" ]]; then
        echo "Cleaning up old version and tarball"
        rm -rf $ABC_DIR/bitcoin-abc-$CURRENT_VER
        rm -f $ABC_DIR/bitcoin-abc-$CURRENT_VER-x86_64-linux-gnu.tar.gz
    fi
    rm -f bitcoin-abc-$LATEST_VER-x86_64-linux-gnu.tar.gz

    echo "Starting new version of node"
    ./bitcoin-abc-$LATEST_VER/bin/bitcoind -daemon
else
    echo "Already at latest version"
fi
