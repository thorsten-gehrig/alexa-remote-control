
# alexa-remote-control
control Amazon Alexa from command Line

The settings can now be controlled via environment variables.
```
EMAIL     - your login email
PASSWORD  - your login password
BROWSER   - the User-Agent your browser sends in the request header
LANGUAGE  - the Accept-Language your browser sends in the request header
AMAZON    - your Amazon domain
ALEXA     - the URL you would use for the Alexa Web App
CURL      - location of your cURL binary
OPTS      - any cURL options you require
TMP       - location of the temp dir
OATHTOOL  - command line for oathtool MFA
MFA_SECRET- the MFA secret
SPEAKVOL  - the volume for speak messages ( if set to 0, volume levels are left untouched)
NORMALVOL - if no current playing volume can be determined, fall back to normal volume
VOLMAXAGE - max. age in minutes before volume is re-read from API
DEVICEVOLNAME   - a list of device names with specific volume settings (space separated)
DEVICEVOLSPEAK  - a list of speak volume levels - matching the devices above
DEVICEVOLNORMAL - a list of normal volume levels- matching the devices above
                  (current playing volume takes precedence for normal volume)
REFRESH_TOKEN - the new preference over EMAIL/PASSWORD can be obtained here: https://github.com/adn77/alexa-cookie-cli
```
You will very likely want to set the language to:
```
export LANGUAGE='de,en-US;q=0.7,en;q=0.3'
```

```
alexa-remote-control [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |
                    -b [list|<"AA:BB:CC:DD:EE:FF">] | -q | -n | -r <"station name"|stationid> |
                    -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> |
                    -w <playlistId> | -i | -p | -P | -S | -a | -z | -l | -h |
                    -m <multiroom_device> [device_1 .. device_X] | -lastalexa | -lastcommand

   -e : run command, additional SEQUENCECMDs:
        weather,traffic,flashbriefing,goodmorning,singasong,tellstory,
        speak:'<text/ssml>',automation:'<routine name>',sound:<soundeffect_name>,
        textcommand:'<anything you would otherwise say to Alexa>',
        playmusic:<channel e.g. TUNEIN, AMAZON_MUSIC>:'<music name>'

   -b : connect/disconnect/list bluetooth device
   -c : list 'playmusic' channels
   -q : query queue
   -n : query notifications
   -r : play tunein radio
   -s : play library track/library album
   -t : play Prime playlist
   -u : play Prime station
   -v : play Prime historical queue
   -w : play library playlist
   -i : list imported library tracks
   -p : list purchased library tracks
   -P : list Prime playlists
   -S : list Prime stations
   -a : list available devices
   -m : delete multiroom and/or create new multiroom containing devices
   -lastalexa : print device that received the last voice command
   -lastcommand : print last voice command or last voice command of specific device
   -login     : Logs in, without further command (downloads cookie)
   -z : print current volume level
   -l : logoff
   -h : help
```

There's also a (NOW DEPRECATED) "plain" version, which lacks some functionality (-z, -i, -p, -P, -S and no radio station names and no routines) but doesn't require 'jq' for JSON processing.

Old option MFA
----
In order to use MFA, one needs to obtain the MFA_SECRET from Amazon account:
1. You should have MFA using an App already working before proceeding
1. Add a new app
1. When presented with the QR-code select "can't scan code"
1. You will be presented with the MFA shared secret, something like `1234 5678 9ABC DEFG HIJK LMNO PQRS TUVW XYZ0 1234 5678 9ABC DEFG`
1. Now you have to generate a valid response code via `oathtool -b --totp "<MFA shared secret from above>"` and enter that in the web form
1. Going from here the MFA shared secret becomes the MFA_SECRET for the alexa_remote_control script;
*Treat that MFA_SECRET just like your password - DO NOT share it anywhere!!!*

It is assumed that MFA secured accounts are less likely to get a captcha response during login - that's why MFA might yield better results if the plain username/password didn't work for you.

New option REFRESH_TOKEN
----
The Alexa-App way of logging in is using a REFRESH_TOKEN which allows for obtaining the session cookies. This replaces EMAIL/PASSWORD/MFA so those will not be exposed in any scripts anymore. For convinience I created a binary, ready to run: https://github.com/adn77/alexa-cookie-cli

https://blog.loetzimmer.de/2021/09/alexa-remote-control-shell-script.html
