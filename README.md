
# alexa-remote-control
control Amazon Alexa from command Line

```
alexa-remote-control [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |
                    -b [list|<"AA:BB:CC:DD:EE:FF">] | -q | -r <"station name"|stationid> |
                    -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> |
                    -w <playlistId> | -i | -p | -P | -S | -a |  -l | -h |
                    -m <multiroom_device> [device_1 .. device_X] | -lastalexa

   -e : run command, additional SEQUENCECMDs:
        weather,traffic,flashbriefing,goodmorning,singasong,tellstory,
        speak:'<text>',automation:'<routine name>'
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






