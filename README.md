# alexa-remote-control
control Amazon Alexa from command Line (set volume, select station from tunein or pandora) 

Please find more details here: https://www.gehrig.info/alexa/Alexa.html



More commands - not yet in a script... but easy for DIY:

Shuffle on/off:

CMD='{"type":"ShuffleCommand","shuffle":true}'

CMD='{"type":"ShuffleCommand","shuffle":false}'

Repeat on/off:

CMD='{"type":"RepeatCommand","repeat":true}'

CMD='{"type":"RepeatCommand","repeat":false}'

+30Sek / -30Sek (e.g. for Books)

CMD='{"type":"ForwardCommand"}'

CMD='{"type":"RewindCommand"}'
