#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Example script showing how to use dynamic host detection for analytics.

This script demonstrates different ways to configure the analytics server
with dynamic or static host settings.
"""

import os
from TwitchChannelPointsMiner import TwitchChannelPointsMiner
from TwitchChannelPointsMiner.utils import (
    get_local_ip,
    get_all_network_interfaces,
    print_network_info
)

# Get environment variables
user = os.getenv("USER")
password = os.getenv("PASSWORD") or "your_password"  # Provide default

# Display available network options
print_network_info()

# Create the miner instance
twitch_miner = TwitchChannelPointsMiner(
    username="XiSZ_",
    password=password,
    enable_analytics=True,
    # ... other settings ...
)

# Example 1: Auto-detect local IP
print("\n=== Example 1: Auto-detect local IP ===")
detected_ip = get_local_ip()
print(f"Auto-detected IP: {detected_ip}")

# Uncomment to use auto-detection:
# twitch_miner.analytics(
#     auto_detect_host=True,  # Auto-detect local IP
#     port=int(os.environ.get("PORT", 5050)),
#     refresh=5,
#     days_ago=30
# )

# Example 2: Manual selection based on environment
print("\n=== Example 2: Environment-based selection ===")
if os.environ.get("HOSTING_PROVIDER") == "serv00":
    # For Serv00 hosting - bind to all interfaces
    analytics_host = "0.0.0.0"
    print("Using Serv00 configuration: 0.0.0.0")
elif os.environ.get("ENVIRONMENT") == "local":
    # For local development - use localhost
    analytics_host = "127.0.0.1"
    print("Using local development configuration: 127.0.0.1")
else:
    # Auto-detect for other environments
    analytics_host = get_local_ip()
    print(f"Using auto-detected configuration: {analytics_host}")

# Example 3: Get all available network interfaces and let user choose
print("\n=== Example 3: Available interfaces ===")
interfaces = get_all_network_interfaces()
for name, ip in interfaces.items():
    print(f"{name}: {ip}")

# Choose the configuration you want to use:
twitch_miner.analytics(
    host="0.0.0.0",  # Your current Serv00 configuration
    # host=analytics_host,  # Or use the environment-based selection
    # auto_detect_host=True,  # Or use auto-detection
    port=int(os.environ.get("PORT", 5050)),
    refresh=5,
    days_ago=30
)

print(f"\nAnalytics server will start on: {analytics_host}")
print("You can now start mining...")

# Start mining (commented out for this example)
# twitch_miner.mine([...])
