# -*- coding: utf-8 -*-
import logging,os
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
from TwitchChannelPointsMiner.classes.entities.Bet import Strategy, BetSettings, Condition, OutcomeKeys,FilterCondition, DelayMode
from TwitchChannelPointsMiner.classes.entities.Streamer import Streamer, StreamerSettings

# import keep_alive 
# #keep_alive.keep_alive()

user = os.getenv("USER")
password = os.getenv('PASSWORD')
webHook = os.getenv('WEBHOOK')
chatID = os.getenv('CHATID')
telegramToken = os.getenv('TELEGRAMTOKEN')


twitch_miner = TwitchChannelPointsMiner(
    username="XiSZ_",
    password=password,  
    claim_drops_startup=True,  
    priority=[  
        Priority.STREAK,  
        Priority.DROPS,   
        Priority.ORDER  
    ],
    enable_analytics=False,
    disable_ssl_cert_verification=False,        # Set to True at your own risk and only to fix SSL: CERTIFICATE_VERIFY_FAILED error
    disable_at_in_nickname=True,               # Set to True if you want to check for your nickname mentions in the chat even without @ sign
    logger_settings=LoggerSettings(
        save=False,  
        console_level=logging.INFO,
        console_username=False,
        auto_clear=True,                        # Create a file rotation handler with interval = 1D and backupCount = 7 if True (default)
        time_zone="Europe/Berlin",              # Set a specific time zone for console and file loggers. Use tz database names. Example: "America/Denver"
        file_level=logging.INFO,
        emoji=True,  
        less=True,  
        colored=False,  
        color_palette=ColorPalette(             # Color allowed are: [BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, RESET].
                STREAMER_ONLINE='GREEN',
                STREAMER_OFFLINE='RED',

                BONUS_CLAIM='YELLOW',
                MOMENT_CLAIM='YELLOW',
                
                DROP_CLAIM='YELLOW',
                DROP_STATUS='MAGENTA',
                
                GAIN_FOR_RAID='BLUE',
                GAIN_FOR_CLAIM='YELLOW',
                GAIN_FOR_WATCH='BLUE',
                GAIN_FOR_WATCH_STREAK='BLUE',

                CHAT_MENTION='WHITE'
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
                
                Events.CHAT_MENTION
                ],  
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


# twitch_miner.analytics(host='0.0.0.0', port=os.environ.get('PORT', 5050), refresh=5, days_ago=7)  # Start the Analytics web-server

# twitch_miner.analytics(host='127.0.0.1', port=5050 , refresh=5, days_ago=7)  # Start the Analytics web-server


twitch_miner.mine(
    [     
        Streamer("warframe",    settings=StreamerSettings(chat=ChatPresence.ONLINE)),
        "ralumyst",
        Streamer ("xhenniii",   settings=StreamerSettings(chat=ChatPresence.ONLINE)),
        "melvniely", 
        "cypathic",
        "dessyy",
        "lauraa",
        "asleyia",
        "karmixxy",
        "matildathepotato",
        "martey0",
        "shabs",
        "punzzl",
        "mathy",
        "Faellu",
        "kittxnlylol",
        "yourluckyclover",
        "helenalive",
        "jenna",
        "faithcakee",
        "StPeach",
        "Xull",
        "vell",
        "chubssx",
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
        "strawbeariem1lk",
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
        "Margareta",
        "MissRage",
        "Siri",
        "smoodie", 
        "lillithy",
        "suzikynz",
        "laurinchhhe",
        "alisa",
        "danucd",
        "BattleBuni",
        "carolinestormi"
    ],
    followers=False,  
    followers_order=FollowersOrder.DESC
)
