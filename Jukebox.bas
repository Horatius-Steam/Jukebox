;reserved
;serial out		= pinC.3		 resevierte Pins fuer serielle Kommunikation
;serial in		= pinC.4		 werden fuer Debug Zwecke genutzt

;variables
symbol upper	= b0			;10er Stelle des Nixie Display
symbol lower	= b1			;01er Stelle des Nixie Displays
symbol dial		= b2			;Variable fuer Nummernschalter
symbol result	= b3			;Resultat aus Wahl der zwei Ziffern
symbol counter	= b4			;Zaehler fuer diverse Aufgaben
symbol num   	= b5			;Variable fuer Ziffernwahl
symbol digit      = b6			;Zaehler fuer 2 Ziffernwahl
symbol lowcount	= b9			;Zaehler fuer geschachteltes Zaehlen
symbol highcount 	= b8			;Zaehler fuer geschachteltes Zaehlen
symbol helper	= b10			;Hilfsvariable
symbol stataudio  = b11			;Variable um Status des Audiorelais zu speichern
;inputs
symbol nsa		= pinC.5		;Abfrage des NummernSchalter Anschalt Kontaktes
symbol nsi		= pinC.6		;Abfrage des NummernSchalter Impuls Kontakt
symbol zpos		= pinC.7		;Anfrage der Null Position des Waehlers

;outputs
;MPPULSE		= C.0			;Uebergabe Wahl an ELV MP3 Player
;PULSE		= C.1			;Ansteuerung des Waehlermagneten
;AudioPower		= C.2			;Power fuer MP3 Player und Verst?rker

init:						;Initialisierung der Ein- und Ausgaenge
;inputs
input C.5, C.6, C.7			;PortC Pins 5, 6, 7 als Eingang

;outputs
output C.0, C.1, C.2			;Port C Pins 0 - 2 als Ausgang
dirsB = %11111111				;Port B, alle Pins als Ausgang

;Reset / Init alle Variablen
counter	= 0
num		= 0
digit		= 1				;Counter fuer Stelle auf 1 setzen
dial		= 0
upper		= 0
lower		= 0

gosub setzero				;Waehler definiert auf 0-Position fahren
;gosub testNIXIE				;Einmal alle Ziffern von 0 bis 9 duchzaehlen

;=================================================================================================
;Hauptprogramm
main:
digit1:
gosub getnumber				;Hole erste Ziffer
if num = 10 then				;Konvertiere 10 Impulse zur Ziffer "0"
  num = 0
endif
if num < 3 or num = 9 then		;Nur gueltige 1. Ziffern zulassen (0,1,2,5)
  if digit = 1 then			;Sicherstellen, dass erste Ziffer entriegelt wurde
    upper = num * 16			;Ziffer speichern und in oberes Nibbel schieben
    let pinsB = upper or %00001111	;Einer Stelle ungueltig maskieren und damit "blanken)
    digit = 2				;Zweite Stelle Freischalten
    num = 0					;Hilfsvariable zuruecksetzen
  endif
else
  let pinsB = %00000000	
  goto digit1				;Solange wiederholen, bis korrekte Nummer gwaehlt wurde
endif

digit2:
gosub getnumber				;2 Stelle holen, alle Ziffern erlaubt
if digit = 2 then				;Sicherstellen, dass zweite Ziffer entriegelt wurde
  if num = 10 then			;Knvertiere 10 Impulse zur Ziffer "0"
    num = 0
  endif
  lower = num				;Ziffer speichern
  result = lower or upper		;1. und 2. Ziffer verknuepfen
  let pinsB = result			;2 stellige Zahl anzeigen
  if upper = 2 and lower > 0 then	;Maximal 21 als Zahl erlaubt
    digit = 1				;Wieder erste Ziffer entriegeln
    num = 0					;Hilfsvariable zuruecksetzen
    goto digit1				;Warte auf korrekte Ziffer
  endif
  digit = 1					;Wieder erste Ziffer entriegeln
  num = 0					;Hilfsvariable zuruecksetzen
endif

;
select case result			;Pruefen, ob Reset "00" angefordert
  case 00					;Wurde "00" gewaehlt, MP3 Player ausschalten
	gosub audio_off
	gosub setzero			;Waehler auf "0"
  case 01 to 09				;Ziffern 0 - 9 werden direkt ?bergeben
    gosub setpos				;Ansonsten neue Positionierung
  case 16 to 25				;Durch die Umrechnug fuer das Display Anpassung n?tig
    result = result -6			;dadurch korrekte Werte.
    gosub setpos
  case 32					;Anderer Umrechnungsfaktor f?r Werte ab 20
    result = result - 12
   gosub setpos
  case 144					;Zahl 90
    gosub testNIXIE			;Nixietest
  case 145					;Zahl 91
    gosub testCOUNT			;Voller Z?hler 0 - 99
  case 146					;Zahl 92
    gosub testAS				;W?hler testen
  case 147					;Zahl 93
    gosub audio_on			;Schaltet Audiokreis fuer Testzwecke ein, Nixies aus.
endselect
;
;debug
goto main
;=================================================================================================
;Subroutinen
getnumber:					;Auf Nummerschalter warten
dial = 0					;Zaehler auf 0 setzen
do until dial <> 0			;Schleife ausfuehren, bis eine Ziffer gew?ehlt wurde
  do while nsa = 0			;Wenn NSA Kontakt geschlossen...
  gosub audio_off
    if nsi = 1 then			;...und NSI offen
      pause 45				;kurze Wartezeit zum Entprellen
      if nsi = 1 then			;NSI immer noch offen...
        dial = dial + 1			;...dann erhoehe ZAhler
      endif
  endif
 loop
loop
num = dial					;Speichern der Ziffer
return
setpos:					;setzt den Waehler auf gewaehlte Position
gosub audio_off				;Audio aus
pause 500
gosub setzero				;Waehler auf Nullposition
pause 500
select case	result			;Wenn 01 - 10 ausgewaehlt wurde direktes Anwaehlen
  case 01 to 10
    for counter = 1 to result
      gosub pulsemagnet			;W?hlermagnet ansteuern
    next counter
  pause 500
  gosub audio_on				;MP3 Playr einschalten
  pause 500					;Kurze Pause zum Initialisieren
  gosub pulse_mp3_short			;Kurzer Impuls aktiviert MP3 - Datei
  ;
 case 11 to 20				;Wenn 11 - 20 ausgewaehlt wurde
   for counter = 11 to result		
     gosub pulsemagnet
  next counter
  pause 500
  gosub audio_on				;MP3 Playr einschalten
  pause 500					;Kurze Pause zum Initialisieren
  gosub pulse_mp3_long			;Langer Impuls waehlt Playlist aus
endselect

return
;=================================================================================================
;Hilfsroutine					;setzt den Waehler auf 0 Position
setzero:					;setzt den Waehler auf 0 Position
gosub audio_off				;MP3 Playerr ausschalten
do while zpos = 1						;laeuft solange, bis Waehler auf 0-Kontakt laeuft
  gosub pulsemagnet
loop
return
pulsemagnet:				;schaltet den Magneten definiert einmal ein und aus
  high C.1
  pause 60
  low C.1					;und wieder aus
  pause 70
return
pulse_mp3_short:				;Aktiviert eine MP3-Datei
  high C.0
  pause 500
  low C.0
return
pulse_mp3_long:				;Aktiviert eine Playlist
  high C.0
  pause 2500
  low C.0
return
audio_on:					;Schaltet Verst?rker und MP3 ein, Nixies aus
high C.2
stataudio = 1				;Status Audio ist on
return
audio_off:					;Schaltet Verst?rker und MP3 aus, Nixies ein
low C.2
stataudio = 0				;Status Audio is off
return
;=================================================================================================
;Testroutinen
testNIXIE:					;Testet alle Nixie Ziffern von 0 bis 9
pause 500
for counter = 0 to 9			;zuerst die 01er Stellen
  let pinsB = counter
  pause 200 
next counter
pause 200
for counter = 0 to 9			;dann die 10er Stellen
  let pinsB = counter * 16
  pause 200
next counter
pause 500
let pinsB = 00
counter = 0
return
testCOUNT:					;Beide Stellen gleichzeitig
for counter = 0 to 9			;von 0 bis 9		
  upper = counter * 16
  lower = counter
  helper = upper or lower
  pinsB = helper
  pause 500
next counter
pause 500
for counter = 9 to 0 step -1		;von 9 bis 0		
  upper = counter * 16
  lower = counter
  helper = upper or lower
  pinsB = helper
  pause 500
next counter
counter = 0
return
testAS:					;Testet den Anrufsucher
  gosub setzero				;Auf Nullposition fahren
  pause 500
  for counter = 1 to 10			;5 Positionen
    gosub pulsemagnet
    pause 500				;1 Sekunde warten
  next counter
  pause 500
  gosub setzero				;Wieder auf Nullposition
  let pinsB = 00
return

