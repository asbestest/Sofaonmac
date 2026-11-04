# Sofaonmac

Ein Sessel für den Mac-Schreibtisch. Dateien, Ordner, Links oder Text draufziehen, dann liegen sie auf dem Sessel statt auf dem Schreibtisch. Ein Klick fächert alles auf: öffnen, zurücklegen oder woandershin ziehen.

![Sofaonmac](docs/screenshot.jpg)

- Neun Sitzmöbel zur Auswahl, drei Größen, passend zu den Teppichen von Rugonmac
- Alles liegt in einem normalen Ordner, auch wenn die App nicht läuft
- Menüleisten-App, im Leerlauf ohne CPU-Last

## Installieren

1. `Sofaonmac.zip` unter [Releases](../../releases/latest) laden und entpacken.
2. `Sofaonmac.app` in den Programme-Ordner ziehen.
3. Einmal im Terminal ausführen, weil die App nicht notarisiert ist:
   ```sh
   xattr -dr com.apple.quarantine /Applications/Sofaonmac.app
   ```
4. Öffnen.

Benötigt macOS 14 und einen Mac mit Apple-Chip. Ausführlich: [Anleitung](Resources/Anleitung.txt).

## Bauen

Es reichen die Xcode Command Line Tools.

```sh
scripts/build.sh --install   # bauen, nach /Applications kopieren, starten
scripts/package.sh           # dist/Sofaonmac.zip zum Weitergeben
scripts/add-sofa.sh <bild> <id>   # neues Sitzmöbel freistellen, dann in SofaStyle.swift eintragen
```
