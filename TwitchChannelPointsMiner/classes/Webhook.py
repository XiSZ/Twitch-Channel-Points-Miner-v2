from textwrap import dedent

import requests

from TwitchChannelPointsMiner.classes.Settings import Events
from security import safe_requests


class Webhook(object):
    __slots__ = ["endpoint", "method", "events"]

    def __init__(self, endpoint: str, method: str, events: list):
        self.endpoint = endpoint
        self.method = method
        self.events = [str(e) for e in events]

    def send(self, message: str, event: Events) -> None:
        
        if str(event) in self.events:
            url = self.endpoint + f"?event_name={str(event)}&message={message}" 
            
            if self.method.lower() == "get":
                safe_requests.get(url=url, timeout=60)
            elif self.method.lower() == "post":
                requests.post(url=url, timeout=60)
            else:
                raise ValueError("Invalid method, use POST or GET")
