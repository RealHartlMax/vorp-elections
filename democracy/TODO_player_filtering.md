# TODO: Spielerfilter nach Ingame-Wohnort

1. Datenquelle festlegen
- Erledigt: Wohnsitz wird ueber RPE_Government `politics_residents` bereitgestellt.
- Feldmapping dokumentiert: `town_id`, `address_line`, `state` und Zuordnung ueber `config/locations.lua`.

2. Normalisierung einführen
- Erledigt: Normalisierung fuer Booth- und Wohnsitz-Abgleich ist serverseitig aktiv.
- Erledigt: Alias-Liste fuer Sonderfaelle/Schreibvarianten deckt bekannte Ortsvarianten wie Saint Denis/St Denis ab.

3. Registrierung an Wohnort koppeln
- Erledigt: Registrierung prueft jetzt den aktiven Wohnsitz gegen den Booth-Staat.
- Erledigt: Fehlertexte fuer fehlenden Wohnsitz / State-Mismatch sind vorhanden.

4. Kandidatur an Wohnort koppeln
- Erledigt: Local-Ämter sind stadtgebunden, County-Ämter regiongebunden, State-Ämter staatsgebunden.
- Erledigt: Kandidatur wird serverseitig blockiert, wenn der Wohnsitz nicht passt.

5. Abstimmungsrechte präzisieren
- Erledigt: Sichtbare Wahloptionen werden an den Wohnsitz gekoppelt und pro Jurisdiction gefiltert.
- Erledigt: Admin-Overrides sind vorhanden und werden über den vorhandenen Audit-/Webhook-Pfad protokolliert.
- Erledigt: Grenzfaelle sind aktuell durch die festen Regeln abgedeckt; Local = Stadt, County = Region, State = Staat, mit Alias-Normalisierung fuer bekannte Ortsvarianten.

6. Performance verbessern
- Erledigt: Wohnortdaten werden serverseitig in-memory mit TTL und Disconnect-Invalidation gecached.
- Erledigt: SQL-Indizes für die relevanten Wohnort- und Wahl-Lookup-Spalten sind in `SQLSetup.sql` und `residence_indices_migration.sql` enthalten.

7. Admin-Ausnahmen definieren
- Erledigt: Konfigurierbare Override-Rollen fuer Tests/Support sind ueber `Config.ElectionOfficials` abgedeckt.
- Erledigt: Audit-Log fuer Overrides wird ueber die vorhandenen Discord/Webhook-Logs geschrieben.

8. UI/UX ergänzen
- Erledigt: NUI-Hinweis "Du bist registriert in ..." ist im Registrierungsmodus sichtbar.
- Erledigt: Klare Fehlermeldungen bei fehlender Wohnort-Berechtigung sind lokalisiert.

9. Testszenarien erstellen
- Erledigt: Konkrete QA-Checkliste fuer Registrierung, Kandidatur, Abstimmung, Alias-Normalisierung und Admin-Overrides ist in `TEST_wohnortfilter.md` dokumentiert.

10. Rollout-Plan
- Erledigt: Migration für bestehende Spieler ohne Wohnortdaten ist in der QA-Checkliste dokumentiert.
- Erledigt: Soft-Launch mit Warnungen und anschließende harte Durchsetzung sind im Rollout-Plan beschrieben.
