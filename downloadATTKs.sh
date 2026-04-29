#!/bin/bash

# Quick download script for Minh-CTF-2026 Attacks folder
echo "Creating Attacks directory..."
mkdir -p Attacks
cd Attacks

BASE_URL="https://raw.githubusercontent.com/SeanLee1274/Minh-CTF-2026/main/Attacks"

FILES=(
    "ACK_flood.sh"
    "Double_flood.sh"
    "Double_flood_client23.sh"
    "install.sh"
    "link_exploit.sh"
    "ping_flood.sh"
    "rst_attack.sh"
    "slowhttpattack.sh"
    "sm_boom.sh"
    "udp_flood.sh"
)

echo "Downloading attack scripts from public repo..."
for file in "${FILES[@]}"; do
    echo "Downloading $file..."
    curl -sS -O "$BASE_URL/$file"
    
    if [ $? -eq 0 ]; then
        echo "✓ $file downloaded"
        chmod +x "$file"
    else
        echo "✗ Failed to download $file"
    fi
done

echo ""
echo "Download complete! Files are in the Attacks directory."
ls -lh
