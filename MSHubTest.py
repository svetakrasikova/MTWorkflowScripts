# -*- coding: utf-8 -*-


use requests


token = requests.post("https://datamarket.accesscontrol.windows.net/v2/OAuth2-13", data = {"scope": "http://api.microsofttranslator.com", "grant_type": "client_credentials", "client_id": "", "client_secret": ""})