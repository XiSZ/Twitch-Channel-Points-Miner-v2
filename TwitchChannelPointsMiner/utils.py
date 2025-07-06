import platform
import re
import socket
import time
from copy import deepcopy
from datetime import datetime, timezone
from os import path

import requests
from millify import millify

from TwitchChannelPointsMiner.constants import USER_AGENTS, GITHUB_url
import secrets


def _millify(input, precision=2):
    return millify(input, precision)


def get_streamer_index(streamers: list, channel_id) -> int:
    try:
        return next(
            i for i, x in enumerate(streamers) if str(x.channel_id) == str(channel_id)
        )
    except StopIteration:
        return -1


def float_round(number, ndigits=2):
    return round(float(number), ndigits)


def server_time(message_data):
    return (
        datetime.fromtimestamp(
            message_data["server_time"], timezone.utc).isoformat()
        + "Z"
        if message_data is not None and "server_time" in message_data
        else datetime.fromtimestamp(time.time(), timezone.utc).isoformat() + "Z"
    )


# https://en.wikipedia.org/wiki/Cryptographic_nonce
def create_nonce(length=30) -> str:
    nonce = ""
    for i in range(length):
        char_index = secrets.SystemRandom().randrange(0, 10 + 26 + 26)
        if char_index < 10:
            char = chr(ord("0") + char_index)
        elif char_index < 10 + 26:
            char = chr(ord("a") + char_index - 10)
        else:
            char = chr(ord("A") + char_index - 26 - 10)
        nonce += char
    return nonce

# for mobile-token


def get_user_agent(browser: str) -> str:
    """try:
        return USER_AGENTS[platform.system()][browser]
    except KeyError:
        # return USER_AGENTS["Linux"]["FIREFOX"]
        # return USER_AGENTS["Windows"]["CHROME"]"""
    return USER_AGENTS["Android"]["TV"]
    # return USER_AGENTS["Android"]["App"]


def remove_emoji(string: str) -> str:
    emoji_pattern = re.compile(
        "["
        "\U0001F600-\U0001F64F"  # emoticons
        "\U0001F300-\U0001F5FF"  # symbols & pictographs
        "\U0001F680-\U0001F6FF"  # transport & map symbols
        "\U0001F1E0-\U0001F1FF"  # flags (iOS)
        "\U00002500-\U00002587"  # chinese char
        "\U00002589-\U00002BEF"  # I need Unicode Character “█” (U+2588)
        "\U00002702-\U000027B0"
        "\U00002702-\U000027B0"
        "\U000024C2-\U00002587"
        "\U00002589-\U0001F251"
        "\U0001f926-\U0001f937"
        "\U00010000-\U0010ffff"
        "\u2640-\u2642"
        "\u2600-\u2B55"
        "\u200d"
        "\u23cf"
        "\u23e9"
        "\u231a"
        "\ufe0f"  # dingbats
        "\u3030"
        "\u231b"
        "\u2328"
        "\u23cf"
        "\u23e9"
        "\u23ea"
        "\u23eb"
        "\u23ec"
        "\u23ed"
        "\u23ee"
        "\u23ef"
        "\u23f0"
        "\u23f1"
        "\u23f2"
        "\u23f3"
        "]+",
        flags=re.UNICODE,
    )
    return emoji_pattern.sub(r"", string)


def at_least_one_value_in_settings_is(items, attr, value=True):
    for item in items:
        if getattr(item.settings, attr) == value:
            return True
    return False


def copy_values_if_none(settings, defaults):
    values = list(
        filter(
            lambda x: x.startswith("__") is False
            and callable(getattr(settings, x)) is False,
            dir(settings),
        )
    )

    for value in values:
        if getattr(settings, value) is None:
            setattr(settings, value, getattr(defaults, value))
    return settings


def set_default_settings(settings, defaults):
    # If no settings was provided use the default settings ...
    # If settings was provided but maybe are only partial set
    # Get the default values from Settings.streamer_settings
    return (
        deepcopy(defaults)
        if settings is None
        else copy_values_if_none(settings, defaults)
    )


'''def char_decision_as_index(char):
    return 0 if char == "A" else 1'''


def internet_connection_available(host="8.8.8.8", port=53, timeout=3):
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
        return True
    except socket.error:
        return False


def percentage(a, b):
    return 0 if a == 0 else int((a / b) * 100)


def create_chunks(lst, n):
    return [lst[i: (i + n)] for i in range(0, len(lst), n)]  # noqa: E203


def download_file(name, fpath):
    r = requests.get(
        path.join(GITHUB_url, name),
        headers={"User-Agent": get_user_agent("FIREFOX")},
        stream=True,
        timeout=60)
    if r.status_code == 200:
        with open(fpath, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024):
                if chunk:
                    f.write(chunk)
    return True


def read(fname):
    return open(path.join(path.dirname(__file__), fname), encoding="utf-8").read()


def init2dict(content):
    return dict(re.findall(r"""__([a-z]+)__ = "([^"]+)""", content))


def check_versions():
    try:
        current_version = init2dict(read("__init__.py"))
        current_version = (
            current_version["version"] if "version" in current_version else "0.0.0"
        )
    except Exception:
        current_version = "0.0.0"
    try:
        r = requests.get(
            "/".join(
                [
                    s.strip("/")
                    for s in [GITHUB_url, "TwitchChannelPointsMiner", "__init__.py"]
                ]
            ),
            timeout=60)
        github_version = init2dict(r.text)
        github_version = (
            github_version["version"] if "version" in github_version else "0.0.0"
        )
    except Exception:
        github_version = "0.0.0"
    return current_version, github_version


def get_local_ip() -> str:
    """
    Get the local IP address of the machine.
    Returns the local IP that would be used to connect to the internet.
    Falls back to localhost if detection fails.
    """
    try:
        # Create a socket and connect to a remote address to determine local IP
        # This doesn't send data, just determines which interface would be used
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            # Use Google's public DNS server as the remote address
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            return local_ip
    except Exception:
        # Fallback to localhost if detection fails
        return "127.0.0.1"


def get_hostname() -> str:
    """
    Get the hostname of the machine.
    """
    try:
        return socket.gethostname()
    except Exception:
        return "localhost"


def get_all_network_interfaces() -> dict:
    """
    Get information about available network interfaces.
    Returns a dictionary with interface details.
    """
    interfaces = {
        "localhost": "127.0.0.1",
        "all_interfaces": "0.0.0.0",
        "local_ip": get_local_ip(),
        "hostname": get_hostname()
    }

    try:
        # Get the fully qualified domain name
        interfaces["fqdn"] = socket.getfqdn()
    except Exception:
        interfaces["fqdn"] = get_hostname()

    return interfaces


def print_network_info():
    """
    Print information about available network interfaces and options.
    Useful for understanding what host options are available.
    """
    interfaces = get_all_network_interfaces()

    print("=== Network Interface Information ===")
    print(f"Localhost (loopback): {interfaces['localhost']}")
    print(f"All interfaces (bind to all): {interfaces['all_interfaces']}")
    print(f"Detected local IP: {interfaces['local_ip']}")
    print(f"Hostname: {interfaces['hostname']}")
    print(f"FQDN: {interfaces['fqdn']}")
    print()
    print("Host Configuration Options:")
    print("- Use '127.0.0.1' for local access only")
    print("- Use '0.0.0.0' to listen on all interfaces (public access)")
    print(f"- Use '{interfaces['local_ip']}' for local network access")
    print("- Use auto_detect_host=True for automatic local IP detection")
    print("==========================================")
