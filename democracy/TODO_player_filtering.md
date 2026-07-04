# TODO: Spielerfilter nach Ingame-Wohnort

1. Datenquelle festlegen
- Klären, wo der Wohnort verlässlich gespeichert wird (z. B. characters, housing resource, custom profile table).
- Feldmapping dokumentieren: Stadt, County/Region, Staat.

2. Normalisierung einführen
- Einheitliche Schreibweise für Ortsdaten definieren (Trim, Casefold, Alias-Liste).
- Mapping-Tabelle für Synonyme pflegen (z. B. Saint Denis/St Denis).

3. Registrierung an Wohnort koppeln
- Beim Registrieren prüfen, ob Spieler-Wohnort mit Booth-Standort kompatibel ist.
- Fehlertexte für "nicht im Wahlkreis wohnhaft" ergänzen.

4. Kandidatur an Wohnort koppeln
- Für Local/County-Ämter Wohnortpflicht erzwingen.
- Für State-Ämter staatliche Zugehörigkeit prüfen.

5. Abstimmungsrechte präzisieren
- Optional: Nur Wohnort-Booth erlaubt oder alle Booths im selben Wahlkreis.
- Regel je Jurisdiction (Local/County/State) dokumentieren.

6. Performance verbessern
- Wohnortdaten beim Join/Spawn cachen (in-memory mit invalidation).
- SQL-Indizes für Wohnortfelder setzen.

7. Admin-Ausnahmen definieren
- Konfigurierbare Override-Rollen für Tests/Support.
- Audit-Log für Overrides (wer, wann, warum).

8. UI/UX ergänzen
- NUI-Hinweis "Du bist registriert in ..." anzeigen.
- Klare Fehlermeldung bei fehlender Wohnort-Berechtigung.

9. Testszenarien erstellen
- Positivtests: korrekt registriert/abstimmbar pro Scope.
- Negativtests: falscher Wohnort, grenznahe Cities, fehlende Wohnortdaten.
- Regressionstest für einmalige Stimmabgabe pro Rennen.

10. Rollout-Plan
- Migration für bestehende Spieler ohne Wohnortdaten.
- Soft-Launch mit Warnungen, danach harte Durchsetzung.
