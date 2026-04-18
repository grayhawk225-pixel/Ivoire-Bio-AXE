import urllib.request
import base64
import os

urls = {
    'wave': 'https://play-lh.googleusercontent.com/I5GqK5fG49IeT4Z2cQ5B8S1l7P_S_SXYP8K_jQK_T3j5n8-U4eP_M9r9l31X9_P_W51p=w240',
    'mtn': 'https://raw.githubusercontent.com/ElishaChebii/momo_api/master/logo.png',
    'orange': 'https://raw.githubusercontent.com/NabilMh/orange-money-api/master/logo.png',
    'moov': 'https://raw.githubusercontent.com/bodev-1/Moov-Money-API/master/moov.png'
}

dart = 'class AppLogos {\n'

for name, url in urls.items():
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=10).read()
        b64 = base64.b64encode(data).decode('utf-8')
        dart += f'  static const String {name} = "{b64}";\n'
    except Exception as e:
        print(f"Failed {name}: {e}")
        dart += f'  static const String {name} = "";\n'

dart += '}\n'

os.makedirs('lib/utils', exist_ok=True)
with open('lib/utils/logos.dart', 'w') as f:
    f.write(dart)

print("logos.dart successfully created.")
