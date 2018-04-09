# SmartSwitch
## Unterputzmodul zur Steuerung von Rolläden bzw. der Realisierung einer Kreuzschaltung mittels ESP8266

**Vision**

Im Zuge des Neubaus unseres Hauses entschieden wir uns für elektrische Rolläden. Dise wurden im ersten Schritt lediglich mit konventionellen Rolladen-Tastern, direkt neben dem jeweiligen Fenster, ausgestattet.
Im zweiten Schritt möchte ich diese *smart* steuern können.

![SmartSwitch Modul](/images/SmartSwitch.jpg)

Inspiriert durch Leo-Andres Hofmann's 230V I/O Modul für ESP8266 ([LUANI](https://luani.de/projekte/esp8266-hvio/)), machte ich mich an die Entwicklung eines eigenen I/O-Moduls zur Abfrage der Rolladentaster bzw. Steuerung des Rolladenmotors. Basis des Moduls ist der ESP-12F, ein integriertes WLAN-Modul, welches über zwei Wechslerrelais die eigentliche Steuerung des Motors übernimmt.

Bedient wird das Modul entweder vor Ort, über die bereits vorhandenen Wandtaster, oder mittles MQTT-Befehle über WLAN, zentral gesteuert über [OpenHab2](https://docs.openhab.org/index.html) auf meinem Raspberry Pi Zero W. Damit ist beispielsweise auch eine Steuerung der Rolläden in Abhängligkeit von Zeiten oder des aktuellen Sonnenaufgang bzw. Sonnenuntergang (Astro Binding) möglich.

![PCB Top](/images/Top.png)   ![PCB Bottom](/images/Bottom.png)
