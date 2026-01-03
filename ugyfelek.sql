-- Tábla törlése, ha már létezne
-- DROP TABLE ugyfelek;

-- Tábla létrehozása
CREATE TABLE ugyfelek(
    id NUMBER(4) PRIMARY KEY,
    nev VARCHAR2(250),
    allapot CHAR(1) -- A: Aktív, I: Inaktív
);

-- Adatok feltöltése
-- 7 db Aktív (A) státuszú ügyfél
INSERT INTO ugyfelek (id, nev, allapot) VALUES (1, 'Kovács János', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (2, 'Nagy Éva', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (3, 'Szabó Péter', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (4, 'Tóth Tímea', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (5, 'Horváth Gábor', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (6, 'Varga Judit', 'A');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (7, 'Kiss László', 'A');

-- 3 db Inaktív (I) státuszú ügyfél (pl. nem fizettek, vagy törölték magukat)
INSERT INTO ugyfelek (id, nev, allapot) VALUES (8, 'Molnár Zsolt', 'I');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (9, 'Farkas Anna', 'I');
INSERT INTO ugyfelek (id, nev, allapot) VALUES (10, 'Balogh Tamás', 'I');

-- Változások véglegesítése
COMMIT;