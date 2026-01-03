-- Tábla törlése, ha már létezne (opcionális, de hasznos teszteléskor)
-- DROP TABLE jarmuvek;

-- Tábla létrehozása
CREATE TABLE jarmuvek(
    frsz VARCHAR2(10) PRIMARY KEY,
    statusz CHAR(1) -- A: Aktív, S: Szerviz, K: Kölcsönözve
);

-- Adatok feltöltése
-- 5 db Aktív (A) státuszú jármű
INSERT INTO jarmuvek (frsz, statusz) VALUES ('ABC-123', 'A');
INSERT INTO jarmuvek (frsz, statusz) VALUES ('LMP-404', 'A');
INSERT INTO jarmuvek (frsz, statusz) VALUES ('AA-BB-123', 'A'); -- Új típusú rendszám
INSERT INTO jarmuvek (frsz, statusz) VALUES ('XYZ-987', 'A');
INSERT INTO jarmuvek (frsz, statusz) VALUES ('AE-JC-202', 'A'); -- Új típusú rendszám

-- 2 db Szervizben (S) lévő jármű
INSERT INTO jarmuvek (frsz, statusz) VALUES ('SER-001', 'S');
INSERT INTO jarmuvek (frsz, statusz) VALUES ('ZZZ-999', 'S');

-- 3 db Kölcsönzött (K) státuszú jármű
INSERT INTO jarmuvek (frsz, statusz) VALUES ('RENT-01', 'K');
INSERT INTO jarmuvek (frsz, statusz) VALUES ('AA-AA-001', 'K'); -- Új típusú rendszám
INSERT INTO jarmuvek (frsz, statusz) VALUES ('KOL-123', 'K');

-- Változások véglegesítése
COMMIT;