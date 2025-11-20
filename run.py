# -*- coding: utf-8 -*-
import logging
import os

# from colorama import Fore
from TwitchChannelPointsMiner import TwitchChannelPointsMiner
from TwitchChannelPointsMiner.logger import LoggerSettings, ColorPalette
from TwitchChannelPointsMiner.classes.Chat import ChatPresence
from TwitchChannelPointsMiner.classes.Discord import Discord
from TwitchChannelPointsMiner.classes.Webhook import Webhook
from TwitchChannelPointsMiner.classes.Telegram import Telegram
from TwitchChannelPointsMiner.classes.Matrix import Matrix
from TwitchChannelPointsMiner.classes.Pushover import Pushover
from TwitchChannelPointsMiner.classes.Gotify import Gotify
from TwitchChannelPointsMiner.classes.Settings import (
    Priority,
    Events,
    FollowersOrder,
)
from TwitchChannelPointsMiner.classes.entities.Bet import (
    Strategy,
    BetSettings,
    Condition,
    OutcomeKeys,
    FilterCondition,
    DelayMode,
)
from TwitchChannelPointsMiner.classes.entities.Streamer import (
    Streamer,
    StreamerSettings,
)
from TwitchChannelPointsMiner.utils import (
    print_network_info,
    get_local_ip,
    get_all_network_interfaces,
)

# import keep_alive
# #keep_alive.keep_alive()

user = os.getenv("USER")
password = os.getenv("PASSWORD")
webHook = os.getenv("WEBHOOK") or ""
chatID = os.getenv("CHATID")
telegramToken = os.getenv("TELEGRAMTOKEN")


twitch_miner = TwitchChannelPointsMiner(
    username="XiSZ_",
    password=password,
    claim_drops_startup=True,
    priority=[Priority.STREAK, Priority.DROPS, Priority.ORDER],
    enable_analytics=False,
    # Set to True at your own risk
    # and only to fix SSL: CERTIFICATE_VERIFY_FAILED error
    disable_ssl_cert_verification=False,
    # Set to True if you want to check for your nickname mentions
    # in the chat even without @ sign
    disable_at_in_nickname=True,
    logger_settings=LoggerSettings(
        save=True,
        console_level=logging.INFO,
        console_username=False,
        # Create a file rotation handler
        # with interval = 1D and backupCount = 7 if True (default)
        auto_clear=True,
        # Set a specific time zone for console and file loggers.
        # Use tz database names. Example: "America/Denver"
        time_zone="Europe/Berlin",
        file_level=logging.INFO,
        emoji=False,
        less=True,
        colored=False,
        # Color allowed are: BLACK, RED, GREEN, YELLOW,
        # BLUE, MAGENTA, CYAN, WHITE, RESET
        color_palette=ColorPalette(
            STREAMER_ONLINE="GREEN",
            STREAMER_OFFLINE="RED",
            BONUS_CLAIM="YELLOW",
            MOMENT_CLAIM="YELLOW",
            DROP_CLAIM="YELLOW",
            DROP_STATUS="MAGENTA",
            GAIN_FOR_RAID="BLUE",
            GAIN_FOR_CLAIM="YELLOW",
            GAIN_FOR_WATCH="BLUE",
            GAIN_FOR_WATCH_STREAK="BLUE",
            CHAT_MENTION="WHITE",
            # Only these events will be sent to the endpoint
        ),
        telegram=Telegram(
            chat_id=chatID,
            token=telegramToken,
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
                # Only these events will be sent to the endpoint
            ],
            disable_notification=True,
        ),
        discord=Discord(
            webhook_api=webHook,
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
            ],
            # Only these events will be sent to the endpoint
        ),
        webhook=Webhook(
            # Webhook URL
            endpoint="https://example.com/webhook",
            # GET or POST
            method="GET",
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
                # Only these events will be sent to the endpoint
            ],
        ),
        matrix=Matrix(
            # Matrix username (without homeserver)
            username="twitch_miner",
            # Matrix password
            password="...",
            # Matrix homeserver
            homeserver="matrix.org",
            # Room ID
            room_id="...",
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
                # Only these events will be sent
            ],
        ),
        pushover=Pushover(
            # Login to https://pushover.net/,
            # the user token is on the main page
            userkey="YOUR-ACCOUNT-TOKEN",
            # Create a application on the website,
            # and use the token shown in your application
            token="YOUR-APPLICATION-TOKEN",
            # Read more about priority here: https://pushover.net/api#priority
            priority=0,
            # A list of sounds can be found here:
            # https://pushover.net/api#sounds
            sound="pushover",
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
                # Only these events will be sent
            ],
        ),
        gotify=Gotify(
            endpoint="https://example.com/message?token=TOKEN",
            priority=8,
            events=[
                Events.STREAMER_ONLINE,
                Events.STREAMER_OFFLINE,
                Events.BONUS_CLAIM,
                Events.MOMENT_CLAIM,
                Events.DROP_CLAIM,
                Events.DROP_STATUS,
                Events.GAIN_FOR_RAID,
                Events.GAIN_FOR_CLAIM,
                Events.GAIN_FOR_WATCH,
                Events.GAIN_FOR_WATCH_STREAK,
                Events.CHAT_MENTION,
            ],
        ),
    ),
    streamer_settings=StreamerSettings(
        make_predictions=False,
        follow_raid=False,
        claim_drops=True,
        watch_streak=True,
        chat=ChatPresence.ONLINE,
        bet=BetSettings(
            strategy=Strategy.SMART,
            percentage=5,
            percentage_gap=20,
            max_points=50000,
            stealth_mode=True,
            delay_mode=DelayMode.FROM_END,
            delay=6,
            minimum_points=20000,
            filter_condition=FilterCondition(
                by=OutcomeKeys.TOTAL_USERS, where=Condition.LTE, value=800
            ),
        ),
    ),
)


# For Serv00 hosting - Analytics dashboard
# Option 1: Manual host specification (previous approach)
# twitch_miner.analytics(
#     host="0.0.0.0",  # Listen on all interfaces for Serv00
#     # Use environment PORT or default to 6060
#     port=int(os.environ.get("PORT", 6060)),
#     refresh=5,  # Refresh every 5 seconds
#     days_ago=30,  # Show data from last 30 days
# )

# twitch_miner.analytics(host='127.0.0.1', port=6060, refresh=60, days_ago=30)

# Option 2: Auto-detect local IP ( uses the utility function to get local IP)
# Show available network options
# print_network_info()
# Get your local IP
# local_ip = get_local_ip()
# print(f"Detected local IP: {local_ip}")
# Get all available interfaces
# interfaces = get_all_network_interfaces()
# print(f"Available interfaces: {interfaces}")
# twitch_miner.analytics(
#     auto_detect_host=True,  # Automatically detect local IP
#     port=int(os.environ.get("PORT", 6060)),
#     refresh=60,
#     days_ago=30,
# )

# Option 3: Manual Detection with Utilities
# Use the new utility functions to get network information:
# Get your local IP
# local_ip = get_local_ip()
# print(f"Detected local IP: {local_ip}")
# Get all available interfaces
# interfaces = get_all_network_interfaces()
# print(f"Available interfaces: {interfaces}")
# Use the detected IP
# twitch_miner.analytics(host=local_ip, port=6060)

# Option 4: Environment-Based Selection
# Create dynamic host selection based on your environment
# Dynamic host selection
# if os.environ.get("HOSTING_PROVIDER") == "serv00":
#     host = "0.0.0.0"  # For Serv00 hosting
# elif os.environ.get("ENVIRONMENT") == "local":
#     host = "127.0.0.1"  # For local development
# else:
#     host = get_local_ip()  # Auto-detect for other cases
# twitch_miner.analytics(host=host, port=6060)

twitch_miner.mine(
    [
        Streamer("warframe", settings=StreamerSettings(
            chat=ChatPresence.ONLINE)),
        "ralumyst",
        Streamer("xhenniii", settings=StreamerSettings(
            chat=ChatPresence.ONLINE)),
        "melvniely",
        "cypathic",
        "lauraa",
        "luki",
        "dessyy",
        "karmixxy",
        "matildathepotato",
        "chubssx",
        "Xull",
        "vell",
        "shabs",
        "Faellu",
        "kiaa",
        "kittxnlylol",
        "yourluckyclover",
        "helenalive",
        "thisispnut",
        "ladyxblake",
        "peachzie",
        "jilledwater",
        "Snowmixy",
        "al3xxandra",
        "berta",
        "crisette_",
        "nemuri_bun",
        "kartoffelschtriem",
        "mandycandysupersandy",
        "kiilanie",
        "paranoidpixi3_za",
        "CyborgAngel",
        "ariana_a7",
        "centane",
        "zylavale",
        "justcallmemary",
        "rhyaree",
        "ki_pi",
        "ashtronova",
        "smoodie",
    ],
    followers=False,
    followers_order=FollowersOrder.DESC,
)
