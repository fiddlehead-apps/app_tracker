# App Store Connect – Sola Tracker / Sola Tracker

Texte zum Einfügen in App Store Connect. Zeichenlimits sind geprüft (Name/Untertitel 30, Werbetext 170, Keywords 100 Bytes, Beschreibung 4000).

## Allgemein

| Feld | Wert |
| --- | --- |
| Bundle-ID | `eu.fiddlehead.sola.tracker` |
| SKU | `eu.fiddlehead.sola.tracker` |
| Plattformen | iPhone, iPad (das Projekt erlaubt iPad, siehe Hinweise), Apple Watch |
| Primärsprache | Deutsch (weitere: Englisch) |
| Kategorie | Gesundheit und Fitness (Health & Fitness) |
| Zweite Kategorie | Produktivität (Productivity) |
| Preis | Kostenlos |
| Copyright | 2026 Christoph Schneider |
| Support-URL | https://fiddlehead.eu/sola-tracker/support/ |
| Marketing-URL | https://fiddlehead.eu/sola-tracker/ |
| Datenschutz-URL | https://fiddlehead.eu/sola-tracker/privacy/ |
| Verschlüsselung | Im Info.plist erledigt (`ITSAppUsesNonExemptEncryption = NO`) |

## App-Datenschutz

Datenschutzangaben: „Daten werden nicht erfasst“ („Data Not Collected“). Die App schickt nichts an eigene Server; iCloud-Sync (nur wenn eingeschaltet) läuft über die private iCloud-Datenbank der Nutzerin bzw. des Nutzers, darauf hast du keinen Zugriff – das zählt bei Apple nicht als Datenerfassung durch dich.

## Altersfreigabe

Fast alle Fragen „Nein/Keine“. Einzige Grauzone: Es gibt Vorlagen „Alkohol“ und „Medikamente“ zum Mitzählen. Apple fragt nach „Alkohol, Tabak oder Drogen (Konsum oder Bezüge)“. Antwortest du „Selten/leicht“, wird die App 13+ statt 4+. Ein reiner Zähler ohne Bewerbung von Alkohol wird meist mit „Keine“ beantwortet – deine Entscheidung.

## Deutsch

**Name** (12/30)

Sola Tracker

**Untertitel / Subtitle** (27/30)

Zählen, was dir wichtig ist

**Werbetext / Promotional text** (128/170)

Wasser, Kaffee, Schlaf, Sport oder Stimmung: ein Tipp genügt. Alles bleibt auf deinem Gerät – ohne Konto, Werbung oder Tracking.

**Keywords** (97/100)

```
gewohnheit,wasser,kaffee,schlaf,stimmung,zähler,strichliste,tagebuch,ziel,serie,widget,watch,csv
```

**Beschreibung / Description** (1319/4000)

```
Sola Tracker zählt, was dir wichtig ist – schnell und ohne Schnickschnack.

Wasser, Kaffee, Schlaf, Sport, Stimmung, Medikamente oder etwas ganz Eigenes: Leg Tracker mit eigenem Namen, Symbol und Farbe an und gib ihnen genau die Felder, die du brauchst – Text, Auswahl, Zahl mit Einheit, Dauer, Bewertung von 1 bis 5 oder Ja/Nein. Oder starte mit einer von 21 Vorlagen.

EIN TIPP GENÜGT
• +1 trägt sofort mit deinen Standardwerten ein – oder öffnet ein Formular, wenn du Details willst.
• Tagesziel mit Fortschrittsring und Serie.
• Widgets für den Home-Bildschirm mit +1-Knopf, auch in der Kurzbefehle-App.
• Apple Watch: +1 tippen, fertig. Werte kannst du direkt auf der Uhr wählen oder später am iPhone ergänzen.

SEHEN, WIE ES LÄUFT
• Heute, Woche, Monat und insgesamt auf einen Blick.
• Kalender-Heatmap der letzten 15 Wochen.
• Verlaufsdiagramme über 14, 30 oder 90 Tage für jedes Feld.

DEINE DATEN BLEIBEN BEI DIR
• Alles wird lokal auf deinem Gerät gespeichert.
• iCloud-Synchronisierung über deine eigene iCloud – nur, wenn du sie einschaltest.
• Kein Konto, keine Werbung, kein Tracking, keine Analyse-Tools.
• Private Tracker lassen sich verstecken und nur mit Face ID oder Touch ID wieder anzeigen.
• CSV-Export und -Import.

Sola Tracker ist kostenlos und Open Source. Den Quellcode findest du auf GitHub.
```

## English

**Name** (12/30)

Sola Tracker

**Untertitel / Subtitle** (25/30)

Count what matters to you

**Werbetext / Promotional text** (131/170)

Water, coffee, sleep, workouts or mood: one tap is all it takes. Everything stays on your device – no account, no ads, no tracking.

**Keywords** (90/100)

```
habit,water,coffee,sleep,mood,counter,tally,log,journal,streak,goal,widget,watch,csv,diary
```

**Beschreibung / Description** (1186/4000)

```
Sola Tracker counts what matters to you – quick and simple.

Water, coffee, sleep, workouts, mood, medication or something of your own: create trackers with their own name, icon and color, and give them exactly the fields you need – text, choice, number with unit, duration, 1–5 rating or yes/no. Or start from one of 21 templates.

ONE TAP IS ENOUGH
• +1 logs right away with your default values – or opens a form when you want details.
• Daily goal with progress ring and streak.
• Home Screen widgets with a +1 button, also available in the Shortcuts app.
• Apple Watch: tap +1 and you're done. Pick values right on the watch or add them later on your iPhone.

SEE HOW IT'S GOING
• Today, this week, this month and all time at a glance.
• Calendar heatmap of the last 15 weeks.
• Timeline charts over 14, 30 or 90 days for every field.

YOUR DATA STAYS WITH YOU
• Everything is stored locally on your device.
• Sync through your own iCloud – only if you turn it on.
• No account, no ads, no tracking, no analytics.
• Hide private trackers and show them again only with Face ID or Touch ID.
• CSV export and import.

Sola Tracker is free and open source. The source code is on GitHub.
```

## Hinweise für die Prüfung (App Review Information)

Anmeldedaten: keine (Haken bei „Anmeldung erforderlich“ weglassen). Kontakt: dein Name, Telefonnummer und support@fiddlehead.eu.

```
Keine Anmeldung nötig. Zum Ausprobieren auf dem Startbildschirm „Tracker erstellen“ antippen und eine Vorlage wählen, dann +1 antippen.

Versteckte Tracker (dokumentierte Datenschutzfunktion, kein verstecktes Feature): Einen Tracker fünfmal schnell antippen versteckt ihn. Fünfmal auf das Datum über den Trackern tippen (oder auf die Versionszeile in den Einstellungen) und mit Face ID / Touch ID bestätigen zeigt die versteckten Tracker an.

iCloud-Sync ist standardmäßig aus und wird in den Einstellungen eingeschaltet. Die Apple-Watch-App spricht direkt mit dem iPhone (WatchConnectivity).

English: No sign-in needed. Tap "Create a tracker" and pick a template, then tap +1. Hidden trackers (a documented privacy feature): tapping a tracker five times quickly hides it; tapping the date above the trackers five times and confirming with Face ID / Touch ID shows hidden trackers. iCloud sync is off by default and can be turned on in Settings.
```

## Screenshots

In `appstore/screenshots/<sprache>/`, in der Reihenfolge der Nummern hochladen. Größen: iPhone 6,9" (1320 × 2868), iPad 13" (2064 × 2752), Apple Watch Ultra (422 × 514).

Entstanden im Simulator mit Demodaten: Debug-Build mit dem Startargument `-demoData YES` (siehe `DemoData.swift`; im Release-Build nicht enthalten). Alle Namen und Bilder sind erfunden.

- `screenshots/de/ipad-1.png`
- `screenshots/de/ipad-2.png`
- `screenshots/de/ipad-3.png`
- `screenshots/de/iphone-1.png`
- `screenshots/de/iphone-2.png`
- `screenshots/de/iphone-3.png`
- `screenshots/de/watch-1.png`
- `screenshots/en/ipad-1.png`
- `screenshots/en/ipad-2.png`
- `screenshots/en/ipad-3.png`
- `screenshots/en/iphone-1.png`
- `screenshots/en/iphone-2.png`
- `screenshots/en/iphone-3.png`
- `screenshots/en/watch-1.png`

## Vor dem Einreichen

- In der Datenschutzerklärung auf fiddlehead.eu steht noch `TODO: ladungsfähige Anschrift` bei „Verantwortlich“ – Adresse ergänzen (DSGVO).
- In App Store Connect unter Business den **EU-Händlerstatus (DSA)** angeben, sonst erscheint die App in der EU nicht.
- Archiv bauen: Xcode → Product → Archive (Release, Schema der App) → Distribute App → App Store Connect.
- **CloudKit-Schema auf Production deployen** (CloudKit Console → Container `iCloud.eu.fiddlehead.sola.tracker` → Deploy Schema Changes). Sonst funktioniert der iCloud-Sync in TestFlight/App-Store-Builds nicht.
- Die App ist auch fürs iPad freigegeben (`TARGETED_DEVICE_FAMILY = 1,2`), deshalb sind iPad-Screenshots nötig. Soll sie nur aufs iPhone, im Projekt auf `1` stellen; auf fiddlehead.eu steht bisher „iPhone und Apple Watch“.
