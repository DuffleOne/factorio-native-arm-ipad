# Abgrenzung der enthaltenen Dateien

Die MIT-Lizenz dieses Repositorys gilt für den hier enthaltenen Portierungs-Code,
die Build-Werkzeuge und die Dokumentation. Sie erteilt keine Rechte an Factorio,
dessen ausführbaren Dateien, Grafiken, Audio, Spieldaten oder Marken.

Factorio und dessen Daten sind nicht Bestandteil dieses Repositorys. Der Build
liest eine eigene lokale macOS-Installation und erzeugt daraus ausschließlich
lokale Build-Produkte. Die darin enthaltenen Original-Lizenzdateien bleiben beim
Kopieren der Spieldaten erhalten. Die erzeugten Apps und Spielarchive sind nicht
Teil der zum Hochladen vorgesehenen Dateien.

SDL 2.30.9 oder SDL 3.4.14 wird passend zur Factorio-Version beim ersten Build
aus dem offiziellen SDL-Repository geladen.
SDL steht unter der zlib-Lizenz; die zugehörige LICENSE.txt bleibt im lokal
entpackten Quellcode unter build/vendor/SDL-release-2.30.9 beziehungsweise
build/vendor/SDL-release-3.4.14 erhalten. Das Projekt ergänzt das jeweilige
CMake-Ziel um probe/SDLInputBridge.c. Für SDL 3.4.14 passt der Build außerdem
die UIKit-Fensterinitialisierung an, damit auf dem iPhone Duo die aktive innere
Anzeige die Fenstergröße und den Eingabefokus bestimmt. Diese lokale Änderung
ist nicht Teil des offiziellen SDL-Releases.

Python/PyYAML, CMake und Apple SDKs werden lokal verwendet und nicht mit diesem
Repository ausgeliefert. Ihre jeweiligen Lizenzbedingungen bleiben bestehen.

Dieses Projekt ist ein unabhängiger experimenteller Portierungsversuch und kein
offizieller iPhone- oder iPad-Client von Wube Software.
