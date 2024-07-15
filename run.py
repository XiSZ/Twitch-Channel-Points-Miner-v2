# -*- coding: utf-8 -*-
import logging,os
from colorama import Fore
from TwitchChannelPointsMiner import TwitchChannelPointsMiner
from TwitchChannelPointsMiner.logger import LoggerSettings, ColorPalette
from TwitchChannelPointsMiner.classes.Chat import ChatPresence
from TwitchChannelPointsMiner.classes.Discord import Discord
from TwitchChannelPointsMiner.classes.Webhook import Webhook
from TwitchChannelPointsMiner.classes.Telegram import Telegram
from TwitchChannelPointsMiner.classes.Matrix import Matrix
from TwitchChannelPointsMiner.classes.Pushover import Pushover
from TwitchChannelPointsMiner.classes.Settings import Priority, Events, FollowersOrder
from TwitchChannelPointsMiner.classes.entities.Bet import Strategy, BetSettings, Condition, OutcomeKeys,FilterCondition, DelayMode
from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer, StreamerSettings
# import keep_alive 

# #keep_alive.keep_alive()

user = os.getenv('User')
password = os.getenv('Password')
webHook = os.getenv('WebHook')
chatID = os.getenv('ChatID')
telegramToken = os.getenv('TelegramToken')


twitch_miner = TwitchChannelPointsMiner(
    username=user,
    password=password,  
    claim_drops_startup=True,  
    priority=[  
        Priority.STREAK,  
        Priority.DROPS,   
        Priority.ORDER  
    ],
    enable_analytics=True,
    disable_ssl_cert_verification=False,        # Set to True at your own risk and only to fix SSL: CERTIFICATE_VERIFY_FAILED error
    disable_at_in_nickname=False,               # Set to True if you want to check for your nickname mentions in the chat even without @ sign
    logger_settings=LoggerSettings(
        save=True,  
        console_level=logging.INFO,
        console_username=False,
        auto_clear=True,                        # Create a file rotation handler with interval = 1D and backupCount = 7 if True (default)
        time_zone="Europe/Berlin",              # Set a specific time zone for console and file loggers. Use tz database names. Example: "America/Denver"
        file_level=logging.INFO,
        emoji=True,  
        less=True,  
        colored=True,  
        color_palette=ColorPalette(             # Color allowed are: [BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, RESET].
                STREAMER_ONLINE=Fore.GREEN,
                STREAMER_OFFLINE=Fore.RED,

                BONUS_CLAIM=Fore.YELLOW,
                MOMENT_CLAIM=Fore.YELLOW,
                
                DROP_CLAIM=Fore.YELLOW,
                DROP_STATUS=Fore.MAGENTA,
                
                GAIN_FOR_RAID=Fore.BLUE,
                GAIN_FOR_CLAIM=Fore.YELLOW,
                GAIN_FOR_WATCH=Fore.BLUE,
                GAIN_FOR_WATCH_STREAK=Fore.BLUE,

                CHAT_MENTION=Fore.WHITE
        ),                                                                                        # Only these events will be sent to the endpoint
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
                
                Events.CHAT_MENTION
            ],                                                                                  # Only these events will be sent to the endpoint
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
                
                Events.CHAT_MENTION
            ],
            ),                                                                                  # Only these events will be sent to the endpoint
            webhook=Webhook(
            endpoint="https://example.com/webhook",                                             # Webhook URL
            method="GET",                                                                       # GET or POST
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
                
                Events.CHAT_MENTION
            ],                                                                                  # Only these events will be sent to the endpoint
            ),
            matrix=Matrix(
            username="twitch_miner",                                                            # Matrix username (without homeserver)
            password="...",                                                                     # Matrix password
            homeserver="matrix.org",                                                            # Matrix homeserver
            room_id="...",                                                                      # Room ID
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
                
                Events.CHAT_MENTION
            ],                                                                                  # Only these events will be sent
            ),
            pushover=Pushover(
            userkey="YOUR-ACCOUNT-TOKEN",                                                       # Login to https://pushover.net/, the user token is on the main page
            token="YOUR-APPLICATION-TOKEN",                                                     # Create a application on the website, and use the token shown in your application
            priority=0,                                                                         # Read more about priority here: https://pushover.net/api#priority
            sound="pushover",                                                                   # A list of sounds can be found here: https://pushover.net/api#sounds
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
                
                Events.CHAT_MENTION
            ],                                                                                  # Only these events will be sent
        )
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
                by=OutcomeKeys.TOTAL_USERS,
                where=Condition.LTE,
                value=800
            )
        )
    )
)


twitch_miner.analytics(host="0.0.0.0", port=os.environ.get('PORT', 5050), refresh=5, days_ago=7)  # Start the Analytics web-server


twitch_miner.mine(
    [     
        Streamer("warframe",    settings=StreamerSettings(chat=ChatPresence.ONLINE)),
        "ralumyst",
        Streamer ("xhenniii",   settings=StreamerSettings(chat=ChatPresence.ONLINE)),
        "dessyy",
        "melvniely", 
        "cypathic",
        "lauraa",
        "martey0",
        "mathy",
        "punzzl",
        "karmixxy",
        "kittxnlylol",
        "lillithy",
        "Witch_Sama",
        "nemuri_bun",
        "etain",
        "adorbie",
        "shabs",
        "ladyxblake",
        "niiau",
        "smotheredbutta",
        "sambivalent",
        "laurenp681",
        "strawberrytops",
        "ggxenia",
        # "faithcakee",
        "Xull",
        "helenalive",
        "Faellu",
        "kiilanie",
        "paranoidpixi3_za",
        "suzie95",
        "rikkemor",
        "kartoffelschtriem",
        "mandycandysupersandy",
        "daeye",
        "awkspewroo2",
        "Snowmixy",
        "terariaa",
        "emyym",
        "medumoon",
        "StPeach",
        "majijej", 
        "Ellie_m_",
        "hekimae",
        "ibbaa", 
        "itspinkwater",
        "justcallmemary",
        "kiaa", 
        "ki_pi",
        "hannahmelin",
        "maawlin",
        "Kunshikitty",
        "kdrkitten",
        "yololaryy",
        "marteemilie",
        "maryydlg",
        "manyissues", 
        "rainingshady",
        "saara_maria",
        "imSoff",
        "Margareta",
        "MissRage",
        "smoodie", 
        "midoriopup",
        "chloelock",
        "suzikynz",
        "laurinchhhe",
        "alisa",
        "furinaburada"
    ],
    followers=False,  
    followers_order=FollowersOrder.DESC
)
