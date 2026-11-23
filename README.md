# KI-Training live

Die [Live-Anzeige](https://elias296.github.io/ki-training-live/) zeigt Fortschritt, Tempo, Prüfverlust und die voraussichtliche Endzeit.

Auf dem Trainingsrechner liest `sync-training.ps1` den lokalen Status und schreibt einmal pro Minute die Fortschrittswerte in `status.json` auf dem Branch `status`. Dafür braucht das Skript eine bestehende GitHub-CLI-Anmeldung mit Schreibzugriff auf dieses Repository. Bei Trainingsende oder nach zwölf Stunden beendet sich der Abgleich.
