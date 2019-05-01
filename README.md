
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
```
You will very likely want to set the language to:
```
export LANGUAGE='de,en-US;q=0.7,en;q=0.3'
```

```
alexa-remote-control [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |
                    -b [list|<"AA:BB:CC:DD:EE:FF">] | -q | -r <"station name"|stationid> |
                    -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> |
                    -w <playlistId> | -i | -p | -P | -S | -a |  -l | -h |
                    -m <multiroom_device> [device_1 .. device_X] | -lastalexa

   -e : run command, additional SEQUENCECMDs:
        weather,traffic,flashbriefing,goodmorning,goodnight,singasong,tellstory,speak:'<text>',joke,calendartoday,
        calendartomorrow,calendarnext,automation:'<routine name>'
   -b : connect/disconnect/list bluetooth device
   -q : query queue
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
   -l : logoff
   -h : help
```
 
There's also a "plain" version, which lacks some functionality (-i, -p, -P, -S and no radio station names and no routines) but doesn't require 'jq' for JSON processing.

http://blog.loetzimmer.de/2017/10/amazon-alexa-hort-auf-die-shell-echo.html






