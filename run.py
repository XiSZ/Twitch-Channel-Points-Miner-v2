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

# import keep_alive
# #keep_alive.keep_alive()

USER = os.getenv("USER")
PASSWORD = os.getenv("PASSWORD") or ""
WEBHOOK = os.getenv("WEBHOOK") or ""
CHAT_ID = int(os.getenv("CHATID") or 0)
TELEGRAMTOKEN = str(os.getenv("TELEGRAMTOKEN") or "")


twitch_miner = TwitchChannelPointsMiner(
    username="XiSZ_",
    password=PASSWORD,
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
            chat_id=CHAT_ID,
            token=TELEGRAMTOKEN,
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
            webhook_api=WEBHOOK,
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

twitch_miner.mine(
    [
        Streamer("warframe", settings=StreamerSettings(
            chat=ChatPresence.ONLINE)),
        Streamer("wudijo", settings=StreamerSettings(
                    chat=ChatPresence.ONLINE)),
        "ralumyst",
        "xhenniii",
        "melvniely",
        "cypathic",
        "adorbie",
        "luki",
        "chubssx",
        "Xull",
        "vell",
        "stpeach",
        "dessyy",
        "Faellu",
        "freyja",
        "helenalive",
        "crisettee",
        "helenanailtech",
        "nieckaa",
        "Snowmixy",
        "al3xxandra",
        "lauraa",
        "shabs",
        "paranoidpixi3_za",
        "kiilanie",
        "kiaa",
        "kittxnlylol",
        "charlyne",
        "matildathepotato",
        "yourluckyclover",
        "thisispnut",
        "ladyxblake",
        "peachzie",
        "jilledwater",
        "CyborgAngel",
        "berta",
        "belluhz",
        "justcallmemary",
        "rhyaree",
        "ki_pi",
        "smoodie",
        "meowdalyn",
        "jaycgee",
        "zylavale",
        "ashtronova",
        "faithcakee",
        "swag_charhar",
        "jessihar",
        "kartoffelschtriem",
        "mandycandysupersandy"
    ],
    followers=False,
    followers_order=FollowersOrder.DESC,
)
