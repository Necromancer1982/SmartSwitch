# SmartSwitch
## Unterputzmodul zur Steuerung von Rolläden bzw. der Realisierung einer Kreuzschaltung mittels ESP8266

**Vision**

Im Zuge des Neubaus unseres Hauses entschieden wir uns für elektrische Rolläden. Diese wurden im ersten Schritt lediglich mit konventionellen Rolladen-Tastern, direkt neben dem jeweiligen Fenster, ausgestattet.
Im zweiten Schritt möchte wir diese *smart* steuern können.

![SmartSwitch Modul](/images/SmartSwitch.jpg)

Inspiriert durch Leo-Andres Hofmann's 230V I/O Modul für ESP8266 ([LUANI](https://luani.de/projekte/esp8266-hvio/)), machte ich mich an die Entwicklung eines eigenen I/O-Moduls zur Abfrage der Rolladentaster bzw. Steuerung des Rolladenmotors. Basis des Moduls ist der ESP-12F, ein integriertes WLAN-Modul, welches über zwei Wechslerrelais die eigentliche Steuerung des Motors übernimmt.

Bedient wird das Modul entweder vor Ort, über die bereits vorhandenen Wandtaster, oder mittles MQTT-Befehle über WLAN, zentral gesteuert über [OpenHab2](https://docs.openhab.org/index.html) auf meinem Raspberry Pi Zero W. Damit ist beispielsweise auch eine Steuerung der Rolläden in Abhängligkeit von Zeiten oder des aktuellen Sonnenaufgang bzw. Sonnenuntergang (Astro Binding) möglich.

![PCB Top](/images/Top.png)   ![PCB Bottom](/images/Bottom.png)


**Hardware**

Neben dem WLAN-Modul und den beiden Relais (Schaltleistung 1500VA, 6A/250V), finden sich eine Spannungsversorgung, bestehend aus einem AC/DC-Wandler HI-Link HLK-PM01 (5V/600mA) für die Relais und einem Spannungsregler TS1117 (LowDrop 3V) für den Rest, eine 2-kanalige "Power Sense" Schaltung zur Detektion  von 230V Pegeln für den Controller, sowie Schnittstellen für UART, I²C und Analog- und Digital-IOs auf dem Board.

Über drei Lötjumper (Brücken) lassen sich die beiden Relais entweder als Kreuzschaltung, zur Implementierung des Moduls in bestehende Licht-Installationen oder aber als Rolladenschalter konfigurieren. Hier schaltet das erste Relais die Versorgungsspanung des Motors während das zweite Relais die Richtung ändert.

Die Stromversorgung des Moduls ist mit einer SMD-Sicherung mit 500mA gegen Überstrom, sowie mit einem Varistor gegen Überspannung abgesichert.


**Software**

Neben der Firmware ([NodeMCU](https://nodemcu.readthedocs.io/en/master/) befinden sich vier LUA-Programme im Speicher des Moduls. Die Init-Datei versucht eine Verbindung zum im Modul hinterlegten Access Point herzustellen. Gelingt das nicht, spannt das Modul selbst einen eigenen Access Point auf und startet ein Enduser Setup so daß beispielsweise bequem über ein Smart Phone die Zugangsdaten 
