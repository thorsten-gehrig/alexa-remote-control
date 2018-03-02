
# alexa-remote-control
control Amazon Alexa from command Line

```
alexa-remote-control [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|vol:<0-100>> |
                    -b [list|<\"AA:BB:CC:DD:EE:FF\">] | -q | -r <\"station name\"|stationid> |
                    -s <trackID> | -t <ASIN> | -u <seedID> | -v <queueID> | -w <playlistId> |
                    -i | -p | -a | -P | -S | -m <multiroom_device> [device_1 .. device_X] |
                     -lastalexa | -l | -h
   -e : run command
   -q : query queue
   -b : connect/disconnect/list bluetooth device
   -r : play tunein radio
   -s : play library track
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
 
There's also a "plain" version, which lacks some functionality (-i, -p, -P, -S and no radio station names) but doesn't require 'jq' for JSON processing.

http://blog.loetzimmer.de/2017/10/amazon-alexa-hort-auf-die-shell-echo.html






