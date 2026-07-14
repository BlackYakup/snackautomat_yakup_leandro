-- =====================================================================
-- DATABASE SETUP SCRIPT FOR SMART VENDING MACHINE (6x10 Grid)
-- SYSTEM-SPRACHE: Deutsch (German)
-- TARGET: SQLite / PostgreSQL (Standard SQL ANSI)
-- =====================================================================

-- STREAMING_CHUNK: Erstellung der Tabellenstruktur...

-- 1. TABELLE: kategorien
CREATE TABLE kategorien (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- 2. TABELLE: produkte
CREATE TABLE produkte (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schacht_nr VARCHAR(10) NOT NULL UNIQUE, -- UK Constraint (z. B. "A1", "C7")
    name VARCHAR(200) NOT NULL,
    preis_cent INTEGER NOT NULL,            -- Ganzzahl für Cent-Präzision
    lagerbestand INTEGER NOT NULL DEFAULT 0,
    schacht_breite INTEGER NOT NULL DEFAULT 1, -- 1 oder 2 Schächte breit
    kategorie_id INTEGER NOT NULL,
    bild_url TEXT,
    FOREIGN KEY (kategorie_id) REFERENCES kategorien(id) ON DELETE RESTRICT
);

-- 3. TABELLE: muenz_bestand
CREATE TABLE muenz_bestand (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    muenzwert_cent INTEGER NOT NULL UNIQUE,  -- UK Constraint (z. B. 5, 10, 20, 50, 100, 200)
    anzahl INTEGER NOT NULL DEFAULT 0
);

-- 4. TABELLE: transaktionen
CREATE TABLE transaktionen (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    produkt_id INTEGER NOT NULL,
    produktpreis_bei_kauf INTEGER NOT NULL, -- Historische Preissicherung
    eingezahlter_betrag_cent INTEGER NOT NULL,
    wechselgeld_cent INTEGER NOT NULL,
    zahlungsmethode VARCHAR(50) NOT NULL DEFAULT 'BAR', -- 'BAR', 'KARTE', 'NFC'
    status VARCHAR(50) NOT NULL,            -- 'ERFOLG', 'ABGEBROCHEN', 'FEHLER'
    zeitstempel DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produkt_id) REFERENCES produkte(id) ON DELETE RESTRICT
);

-- 5. TABELLE: transaktions_muenzen
CREATE TABLE transaktions_muenzen (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaktions_id INTEGER NOT NULL,
    muenzwert_cent INTEGER NOT NULL,
    anzahl INTEGER NOT NULL DEFAULT 1,
    bewegungstyp VARCHAR(20) NOT NULL,     -- 'EINWURF' oder 'AUSGABE'
    FOREIGN KEY (transaktions_id) REFERENCES transaktionen(id) ON DELETE CASCADE
);

-- STREAMING_CHUNK: Einfügen der Initialdaten...

-- ---------------------------------------------------------------------
-- INITIALDATEN EINFÜGEN (DML)
-- ---------------------------------------------------------------------

-- Kategorien einfügen
INSERT INTO kategorien (id, name) VALUES (1, 'Getränke');
INSERT INTO kategorien (id, name) VALUES (2, 'Snacks');
INSERT INTO kategorien (id, name) VALUES (3, 'Knabberzeug & Mints');
INSERT INTO kategorien (id, name) VALUES (4, 'Fitness & Riegel');

-- Münzbestand initialisieren (Automat wird mit Wechselgeld befüllt)
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (5, 50);
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (10, 100);
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (20, 100);
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (50, 80);
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (100, 120); -- 1 Euro
INSERT INTO muenz_bestand (muenzwert_cent, anzahl) VALUES (200, 45);  -- 2 Euro

-- Produkte aus dem 6x10 Belegungsplan einfügen
-- REIHE A (Getränke)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A1', 'Coca-Cola (Original)', 150, 10, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A2', 'Coca-Cola (Zero)', 150, 8, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A3', 'Fanta Orange', 150, 10, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A4', 'Sprite', 150, 7, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A5', 'Mezzo Mix', 150, 9, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A6', 'Apfelschorle', 180, 6, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A7', 'Wasser (Gas)', 120, 12, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A8', 'Wasser (Still)', 120, 15, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A9', 'Orangensaft', 200, 5, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('A10', 'Eistee Pfirsich', 180, 10, 1, 1);

-- REIHE B (Getränke)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B1', 'Red Bull (Original)', 250, 24, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B2', 'Red Bull (Sugarfree)', 250, 18, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B3', 'Monster Energy', 300, 12, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B4', 'Eistee Zitrone', 180, 10, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B5', 'Arizona Green Tea', 220, 8, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B6', 'Capri-Sun Orange', 100, 20, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B7', 'Club Mate', 220, 10, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B8', 'Paulaner Spezi', 180, 15, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B9', 'Volvic Touch Zitrone', 200, 8, 1, 1);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('B10', 'Wasser Premium', 250, 12, 1, 1);

-- REIHE C (Snacks & Riegel / 2er Breite Chips)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C1', 'Snickers', 120, 15, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C2', 'Mars', 120, 12, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C3', 'Twix', 120, 14, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C4', 'Bounty', 120, 10, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C5', 'Milky Way', 100, 16, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C6', 'KitKat', 120, 12, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C7', 'Lays Chips gesalzen', 220, 8, 2, 2); -- Belegt Schacht C7 & C8
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('C9', 'Lays Chips Paprika', 220, 7, 2, 2); -- Belegt Schacht C9 & C10

-- REIHE D (Süßwaren & Kekse)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D1', 'Duplo', 100, 20, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D2', 'Hanuta', 110, 15, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D3', 'Manner Schnitten', 150, 10, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D4', 'Oreo Kekse', 180, 8, 1, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D5', 'Haribo Goldbären', 190, 10, 2, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D7', 'Haribo Phantasia', 190, 9, 2, 2);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('D9', 'M&Ms Peanut', 250, 8, 2, 2);

-- REIHE E (Knabber & Mints)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E1', 'Kaugummi Mint', 150, 20, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E2', 'Kaugummi Spearmint', 150, 15, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E3', 'Airwaves Cherry', 130, 25, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E4', 'Tic Tac Mint', 150, 30, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E5', 'Skittles', 160, 12, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E6', 'Corny Classic', 100, 18, 1, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E7', 'Erdnüsse gesalzen', 180, 12, 2, 3);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('E9', 'Studentenfutter', 240, 10, 2, 3);

-- REIHE F (Fitness & Knabber)
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F1', 'Protein Riegel Schoko', 250, 15, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F2', 'Protein Riegel Vanille', 250, 14, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F3', 'Powerbar Sport-Riegel', 220, 10, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F4', 'Beef Jerky', 290, 12, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F5', 'Corny Free Schoko', 110, 20, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F6', 'Balisto Korn', 100, 25, 1, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F7', 'Doritos Cheese', 220, 8, 2, 4);
INSERT INTO produkte (schacht_nr, name, preis_cent, lagerbestand, schacht_breite, kategorie_id) VALUES ('F9', 'Pringles Sour Cream', 280, 11, 2, 4);