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
from TwitchChannelPointsMiner.classes.Settings import Priority, Events, FollowersOrder
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
from TwitchChannelPointsMiner.utils import print_network_info

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
    enable_analytics=True,
    # Set to True at your own risk
    # and only to fix SSL: CERTIFICATE_VERIFY_FAILED error
    disable_ssl_cert_verification=False,
    # Set to True if you want to check for your nickname mentions
    # in the chat even without @ sign
    disable_at_in_nickname=True,
    logger_settings=LoggerSettings(
        save=False,
        console_level=logging.INFO,
        console_username=False,
        # Create a file rotation handler
        # with interval = 1D and backupCount = 7 if True (default)
        auto_clear=True,
        # Set a specific time zone for console and file loggers.
        # Use tz database names. Example: "America/Denver"
        time_zone="Europe/Berlin",
        file_level=logging.INFO,
        emoji=True,
        less=True,
        colored=False,
        color_palette=ColorPalette(  # Color allowed are: [BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, RESET].
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
# Option 1: Manual host specification (your current approach)
# twitch_miner.analytics(
#     host="0.0.0.0",  # Listen on all interfaces for Serv00
#     # Use environment PORT or default to 5050
#     port=int(os.environ.get("PORT", 5050)),
#     refresh=5,  # Refresh every 5 seconds
#     days_ago=30,  # Show data from last 30 days
# )

# Option 2: Auto-detect local IP (uncomment to use)

print_network_info()  # Show available network options
twitch_miner.analytics(
    auto_detect_host=True,  # Automatically detect local IP
    port=int(os.environ.get("PORT", 5050)),
    refresh=5,
    days_ago=30,
)

# Local development version (uncomment for local testing)

# twitch_miner.analytics(host='127.0.0.1', port=5050, refresh=5, days_ago=7)


twitch_miner.mine(
    [
        Streamer("warframe", settings=StreamerSettings(
            chat=ChatPresence.ONLINE)),
        "ralumyst",
        Streamer("xhenniii", settings=StreamerSettings(
            chat=ChatPresence.ONLINE)),
        "melvniely",
        "cypathic",
        "dessyy",
        "lauraa",
        "asleyia",
        "karmixxy",
        "matildathepotato",
        "chubssx",
        "martey0",
        "Xull",
        "vell",
        "shabs",
        "punzzl",
        "mathy",
        "Faellu",
        "kittxnlylol",
        "yourluckyclover",
        "helenalive",
        "thisispnut",
        "jenna",
        "faithcakee",
        "StPeach",
        "notaestheticallyhannah",
        "jilledwater",
        "peachzie",
        "jassie",
        "earthround",
        "crisette_",
        "aryssa614",
        "shan",
        "avivasofia",
        "ggxenia",
        "midoriopup",
        "yololaryy",
        "meowdalyn",
        "ladyxblake",
        "s0apy",
        "n4y0hmie",
        "mira004",
        "Witch_Sama",
        "nemuri_bun",
        "etain",
        "adorbie",
        "niiau",
        "smotheredbutta",
        "laurenp681",
        "strawberrytops",
        "suzie95",
        "rikkemor",
        "kartoffelschtriem",
        "mandycandysupersandy",
        "daeye",
        "kiilanie",
        "paranoidpixi3_za",
        "centane",
        "zylavale",
        "Snowmixy",
        "al3xxandra",
        "ashtronova",
        "smashedely",
        "terariaa",
        "emyym",
        "medumoon",
        "majijej",
        "hekimae",
        "loosh_",
        "ohKayBunny",
        "shaekitty",
        "laurenxburch",
        "juliaburch",
        "chloelock",
        "ibbaa",
        "itspinkwater",
        "justcallmemary",
        "kiaa",
        "rhyaree",
        "ki_pi",
        "hannahmelin",
        "maawlin",
        "Kunshikitty",
        "kdrkitten",
        "Ellie_m_",
        "marteemilie",
        "maryydlg",
        "manyissues",
        "LadyKandice",
        "rainingshady",
        "sambivalent",
        "saaravaa",
        "imSoff",
        "rachelkay",
        "jessamesa",
        "Maggie",
        "MissRage",
        "Siri",
        "smoodie",
        "lillithy",
        "suzikynz",
        "laurinchhhe",
        "alisa",
        "danucd",
        "BattleBuni",
        "carolinestormi",
    ],
    followers=False,
    followers_order=FollowersOrder.DESC,
)
