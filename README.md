# SmartSwitch
## Unterputzmodul zur Steuerung von Rolläden bzw. der Realisierung einer Kreuzschaltung mittels ESP8266

**Vision**

Im Zuge des Neubaus unseres Hauses entschieden wir uns für elektrische Rolläden. Diese wurden im ersten Schritt lediglich mit konventionellen Rolladen-Tastern, direkt neben dem jeweiligen Fenster, ausgestattet.
Im zweiten Schritt möchten wir diese *smart* steuern können.

![SmartSwitch Modul](/images/SmartSwitch.jpg)

Inspiriert durch Leo-Andres Hofmann's 230V I/O Modul für ESP8266 ([LUANI](https://luani.de/projekte/esp8266-hvio/)), machte ich mich an die Entwicklung eines eigenen I/O-Moduls zur Abfrage der Rolladentaster bzw. Steuerung des Rolladenmotors. Basis des Moduls ist der ESP-12F, ein integriertes WLAN-Modul, welches über zwei Wechslerrelais die eigentliche Steuerung des Motors übernimmt.

Bedient wird das Modul entweder vor Ort, über die bereits vorhandenen Wandtaster, oder mittels MQTT-Befehle über WLAN, zentral gesteuert über [OpenHab2](https://docs.openhab.org/index.html) auf meinem Raspberry Pi Zero W. Damit ist beispielsweise auch eine Steuerung der Rolläden in Abhängigkeit von Zeiten oder Events beispielsweise dem Zeitpunkt des aktuellen Sonnenaufgang bzw. Sonnenuntergang ([Astro Bindings](https://docs.openhab.org/addons/bindings/astro/readme.html)) möglich. Auch eine Automatische Abschattung in Abhängigkeit des Sonnenwinkels, der aktuellen Globalstrahlung der Sonne und der Außen- bzw. Raumtemperatur wäre denkbar. 

![PCB Top](/images/Top.png)   ![PCB Bottom](/images/Bottom.png)


**Hardware**

Neben dem WLAN-Modul und den beiden Relais (Schaltleistung 1500VA, 6A/250V), finden sich eine Spannungsversorgung, bestehend aus einem AC/DC-Wandler HI-Link HLK-PM01 (5V/600mA) für die Relais und einem Spannungsregler TS1117 (LowDrop 3V) für den Rest, eine 2-kanalige "Power Sense" Schaltung zur Detektion  von 230V Pegeln für den Controller, sowie Schnittstellen für UART, I²C und Analog- und Digital-IOs auf dem Board.

Über drei Lötjumper (Brücken) lassen sich die beiden Relais entweder als Kreuzschaltung, zur Implementierung des Moduls in bestehende Licht-Installationen oder aber als Rolladenschalter konfigurieren. Hier schaltet das erste Relais die Versorgungsspanung des Motors während das zweite Relais die Richtung ändert.

Die Stromversorgung des Moduls ist mit einer SMD-Sicherung mit 500mA gegen Überstrom, sowie mit einem Varistor gegen Überspannung abgesichert.


**Software**

Außer der Firmware ([NodeMCU](https://nodemcu.readthedocs.io/en/master/)) befinden sich vier LUA-Programme im Speicher des Moduls.

Die Init-Datei versucht eine Verbindung zum im Modul hinterlegten Access Point (Router) herzustellen. Gelingt das nicht, spannt das Modul selbst einen eigenen Access Point auf und startet ein Enduser Setup so daß, beispielsweise bequem über ein Smart Phone, die Zugangsdaten des WLAN-Routers eingegeben werden können.

Anschließend werden zwei Softwaremodule geladen. Das MQTT-Modul übernimmt die Konfiguration des MQTT-Client, verbindet sich mit dem in der MQTT.ini hinterlegten Broker und stellt diverse Prozeduren zur MQTT-Kommunikation bereit.
Das INI-Handling-Modul stellt wie der Name schon sagt zwei Prozeduren zum einfachen Zugriff auf INI-Dateien über Key- und Value-Werte zur Verfügung.

Final wir das eigentliche Hauptprogramm gestartet.


**Funktion**

Das Hauptprogramm ermöglich unter anderem über die beiden Power-Sense Eingänge die Abfrage der Rolladentaster. Werden beide Taster gleichzeitig gedrückt, geht das Modul in den Teaching-Modus. Da die einfachen Rolladenmotore kein Feedback über die aktuelle Position geben können, kann nun durch Fahren des Rolladen in die beiden Endpositionen, die Zeit, die für die Verfahrwege benötigt wird, im Modul gespeichert werden.
Durch kurzes Betätigen eines Tasters, fährt der Rolladen nun in die jeweilige Endposition. Wird der Taster hingegen länger als 1s betätigt, fährt der Rolladen bis zum Loslassen des Tasters bzw. Erreichen der Endposition weiter. Beim Loslassen wird über die betätigte Zeit die Position des Rolladens berechnet und im Modul hinterlegt. Dadurch ist auch das Anfahren einer bzw. Losfahren von einer bestimmten Position möglich.

Da der Rolladen aber nicht nur manuell mittels Taster getriggert werden können soll, ist wie erwähnt ein MQTT-Client im Modul integriert. Über das MQTT-Topic, welches ebenfalls in der Datei MQTT.ini hinterlegt ist kann mit den Befehlen "UP" und "DOWN" die Endposition angefahren werden. Wird hingegen ein Wert zwischen 0 und 100 an das Modul gesendet, fährt der Rolladen die entsprechende Position in Prozent an. Bei Erreichen der Position bzw. des Endwertes, wird die aktuelle Position, ebenfalls als MQTT-Message an den Broker zurückgegeben. So ist die Anzeige der aktuelle Position des Rolladens z.B. im [HabPanel von OpenHab](https://docs.openhab.org/addons/uis/habpanel/readme.html) möglich.
