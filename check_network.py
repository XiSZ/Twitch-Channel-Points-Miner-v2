#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Network Detection Utility

This script helps you understand what network interfaces are available
and which host configuration would be best for your analytics server.
"""

from TwitchChannelPointsMiner.utils import (
    get_local_ip,
    print_network_info
)
import sys
import os

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def main():
    print("=== Twitch Channel Points Miner - Network Detection ===\n")

    # Display detailed network information
    print_network_info()

    # Show specific recommendations
    print("\n=== Recommendations ===")

    local_ip = get_local_ip()

    print("For different hosting scenarios:")
    print()

    print("1. Local development (access only from this machine):")
    print("   host='127.0.0.1'")
    print()

    print("2. Local network access (other devices on your network):")
    print(f"   host='{local_ip}'")
    print()

    print("3. Public hosting (like Serv00, access from anywhere):")
    print("   host='0.0.0.0'")
    print()

    print("4. Automatic detection:")
    print("   auto_detect_host=True")
    print(f"   (This would currently use: {local_ip})")
    print()

    # Test if we can bind to different addresses
    print("=== Testing Network Binding ===")
    import socket

    test_addresses = [
        ("127.0.0.1", "Localhost"),
        (local_ip, "Local IP"),
        ("0.0.0.0", "All interfaces")
    ]

    for addr, name in test_addresses:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind((addr, 0))  # Bind to any available port
                port = s.getsockname()[1]
                print(f"✅ {name} ({addr}): Can bind (test port: {port})")
        except Exception as e:
            print(f"❌ {name} ({addr}): Cannot bind - {e}")

    print("\n=== Current Configuration Analysis ===")

    # Check environment variables
    hosting_provider = os.environ.get("HOSTING_PROVIDER", "unknown")
    port = os.environ.get("PORT", "5050")

    print(f"Environment PORT: {port}")
    print(f"Hosting provider: {hosting_provider}")

    if hosting_provider.lower() == "serv00":
        print("✅ Serv00 detected - recommended host: '0.0.0.0'")
    elif local_ip.startswith(("192.168.", "10.")):
        print(f"🏠 Local network detected - you can use '{local_ip}' "
              "for network access")
    else:
        print(f"🌐 Public IP detected - '{local_ip}' may be publicly "
              "accessible")

    print(f"\nAnalytics URL would be: http://{local_ip}:{port}/")


if __name__ == "__main__":
    main()
