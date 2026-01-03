CREATE TABLE kolcsonzesek (
    id CHAR(15) NOT NULL,
    jarmu VARCHAR2(10) NOT NULL,
    ugyfel NUMBER(4) NOT NULL,
    kezdete DATE NOT NULL,
    vege DATE NOT NULL,
    allapot CHAR(1) NOT NULL,
    osszeg NUMBER(10, 2),

    -- Elsődleges kulcs
    CONSTRAINT pk_kolcsonzesek PRIMARY KEY (id),

    -- Idegen kulcsok
    CONSTRAINT fk_kolcsonzesek_jarmu FOREIGN KEY (jarmu)
        REFERENCES jarmuvek(frsz),
    CONSTRAINT fk_kolcsonzesek_ugyfel FOREIGN KEY (ugyfel)
        REFERENCES ugyfelek(id),

    -- Logikai ellenőrzések (Check constraints)
    CONSTRAINT chk_datumok CHECK (kezdete < vege),
    CONSTRAINT chk_osszeg CHECK (osszeg > 0),
    CONSTRAINT chk_allapot CHECK (allapot IN ('F', 'K', 'V')),

    -- Rendszám formátum ellenőrzése (Régi vagy Új típus)
    CONSTRAINT chk_rendszam_formatum CHECK (
        REGEXP_LIKE(jarmu, '^[A-Z]{3}-[0-9]{3}$')
        OR
        REGEXP_LIKE(jarmu, '^[A-Z]{2}-[A-Z]{2}-[0-9]{3}$')
    )
);