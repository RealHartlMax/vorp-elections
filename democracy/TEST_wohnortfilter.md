# QA-Checkliste: Spielerfilter nach Ingame-Wohnort

## Positivtests
- Spieler ist in derselben State wie das Wahlbüro gemeldet und kann sich registrieren.
- Spieler ist im passenden County/Region gemeldet und kann für County-Ämter kandidieren.
- Spieler ist im passenden Town-ID-Eintrag gemeldet und kann für Local-Ämter kandidieren.
- Wahloptionen werden nur für Ämter angezeigt, die zur registrierten Wohnsitz-Zuordnung passen.

## Negativtests
- Spieler mit Wohnsitz in einer anderen State kann sich nicht registrieren.
- Spieler mit Wohnsitz in einer anderen Region kann nicht für County-Ämter kandidieren.
- Spieler mit unbekanntem oder nicht gemapptem Wohnsitz erhält die lokale Fehlermeldung.
- Alias-Fälle wie Saint Denis/St Denis werden auf denselben Ort normalisiert.

## Regressionstests
- Ein Spieler kann pro Rennen nur einmal abstimmen.
- Ein bereits registrierter Spieler bekommt beim erneuten Öffnen des Booths den Wohnsitz-Hinweis.
- Election officials können bei Bedarf per Override eingreifen und der Vorgang wird protokolliert.

## Rollout-Check
- Bestehende Datenbanken haben die neuen Indizes aus `residence_indices_migration.sql` erhalten.
- Neue Spielerdaten werden ohne manuelle Nacharbeit mit dem Wohnsitz-Check verarbeitet.

## Rollout-Plan
- Vor dem Rollout die Migration `residence_indices_migration.sql` auf bestehenden Datenbanken ausführen.
- Zuerst mit `Config.DevDebug = true` oder einem Testserver starten, damit Wohnsitz-Zuordnungen und Overrides nachvollziehbar sind.
- Einen Soft-Launch fahren, bei dem nur die Fehlermeldungen und Hinweise beobachtet werden.
- Nach erfolgreichem Test die Durchsetzung normal laufen lassen und die Warnmeldungen nur noch als Support-Hilfe nutzen.
- Bestandscharaktere ohne Wohnsitzdaten vorab im Government-System nachpflegen, bevor die harte Durchsetzung aktiv wird.