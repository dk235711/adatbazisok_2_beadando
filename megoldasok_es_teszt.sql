-- *** 0. Inicializálás: Korábbi táblák és segédeszközök törlése ***

-- Ez segít újrafuttatni a szkriptet hiba nélkül
drop table kolcsonzesek cascade constraints;
drop table jarmuvek cascade constraints;
drop table ugyfelek cascade constraints;

-- Függvények/eljárások törlése
drop function get_id;
drop procedure jarmu_visszahoz;

-- Visszajelzések bekapcsolása
   SET SERVEROUTPUT ON;


-- *** 1. Alap táblák létrehozása és feltöltése (Ahogy a kérésben volt) ***

-- 1.1 Jarmuvek tábla
create table jarmuvek (
   frsz    varchar2(10) primary key,
   statusz char(1)
);

insert into jarmuvek (
   frsz,
   statusz
) values ( 'ABC-123',
           'A' ); -- A: Aktív (teszthez)
insert into jarmuvek (
   frsz,
   statusz
) values ( 'LMP-404',
           'A' ); -- A: Aktív
insert into jarmuvek (
   frsz,
   statusz
) values ( 'AA-BB-123',
           'A' ); -- A: Aktív (Új rendszám)
insert into jarmuvek (
   frsz,
   statusz
) values ( 'SER-001',
           'S' ); -- S: Szerviz (hiba teszthez)
insert into jarmuvek (
   frsz,
   statusz
) values ( 'RENT-01',
           'K' ); -- K: Kölcsönözve (hiba teszthez)
insert into jarmuvek (
   frsz,
   statusz
) values ( 'TES-555',
           'A' ); -- A: Aktív (teszthez)
insert into jarmuvek (
   frsz,
   statusz
) values ( 'TES-556',
           'A' ); -- A: Aktív (teszthez)

-- 1.2 Ugyfelek tábla
create table ugyfelek (
   id      number(4) primary key,
   nev     varchar2(250),
   allapot char(1)
);

insert into ugyfelek (
   id,
   nev,
   allapot
) values ( 1,
           'Kovács János',
           'A' ); -- Aktív (teszthez)
insert into ugyfelek (
   id,
   nev,
   allapot
) values ( 8,
           'Molnár Zsolt',
           'I' ); -- Inaktív

create table kolcsonzesek (
   id      char(15) not null primary key,
   jarmu   varchar2(10) not null,
   ugyfel  number(4) not null,
   foreign key ( jarmu )
      references jarmuvek ( frsz ),
   foreign key ( ugyfel )
      references ugyfelek ( id ),
   kezdete date not null,
   vege    date not null,
   allapot char(1) not null check ( allapot in ( 'F',
                                                 'K',
                                                 'V' ) ),
   osszeg  number(10,2) check ( osszeg > 0 ),
   constraint kezdete_vege check ( kezdete < vege ),
   constraint jarmu_formatum
      check ( regexp_like ( jarmu,
                            '^[A-Z]{3}-[0-9]{3}$' )
          or regexp_like ( jarmu,
                           '^[A-Z]{2}-[A-Z]{2}-[0-9]{3}$' ) )
);

-- 2. Készítsen segédfüggvényt get_id néven, amely segítségével a kolcsonzes azonosítója generálható.
-- A függvény végrehajtásához legyen elegendő, ha ahhoz a felhasználó a függvényen kap futtatási jogot.

-- A függvény a hívás végén visszatér a megfelelő kölcsönzési azonosítóval (állandó hosszúságú, 15 karakteres szöveg).

-- A segédfüggvény paraméterben kapja a kölcsönzés kezdetét, ha ez a hívás során nem kerül beállításra (NULL értéket kap), akkor legyen az aktuális rendszerdátum. A tranzakció azonosítója két részből áll, az egyes részeket - karakterrel kell elválasztani. Az első rész az kölcsönzés kezdete dátum és hónap sorszámát tartalmazza 6 karakteren ÉÉÉÉHH formában (pl. 2024.11.26 esetén 202411), ezt követi (egy - után) a kölcsönzés sorszáma az adott év adott hónapjában. A sorszámot a balról töltse fel úgy vezető 0 karakterekkel, hogy az összefűzött azonosító hossza 15 karakter legyen.

create or replace function get_id (
   p_datum in date default null
) return char is
   v_datum     date;
   v_elso_resz char(7);
   v_count     number;
   v_sorszam   varchar2(8);
   v_id        char(15);
begin
   v_datum := nvl(
      p_datum,
      sysdate
   );
   v_elso_resz := to_char(
      v_datum,
      'YYYYMM'
   )
                  || '-';
   select count(*)
     into v_count
     from kolcsonzesek;
   v_sorszam := lpad(
      v_count + 1,
      8,
      '0'
   );
   v_id := v_elso_resz || v_sorszam;
   return v_id;
end;
/

-- 3. Készítse el a kolcsonzesek táblához a megfelelő triggert (vagy triggereket). A feladatot megoldhatja
-- egyetlen trigger létrehozásával vagy több triggert is létrehozhat.
--     a. Beszúrás esetén a kölcsönzés azonosítóját a megvalósított segédfüggvénnyel generálja.
--     b. Nem lehet S (szerviz) státuszban lévő járművet kölcsönözni, ekkor dobjunk kivételt.
--     c. Nem lehet K (kölcsönözve) státuszú járművet kölcsönözni, ekkor dobjunk kivételt.
--     d. Új kölcsönzés esetén a kapcsolódó jármű státuszát állítsuk (K) kölcsönözve státuszra.
--     e. Ha a kölcsönzés állapota V (visszavéve) státuszra módosult, akkor állítsa vissza a jármű állapotát A (aktív) értékre.

create or replace trigger trg_kolcsonzes_ellenorzes before
   insert on kolcsonzesek
   for each row
declare
   v_statusz char(1);
begin
   select statusz
     into v_statusz
     from jarmuvek
    where frsz = :new.jarmu;
   if v_statusz = 'S' then
      raise_application_error(
         -20001,
         'Hiba, az auto szervizben van! Rendszam: ' || :new.jarmu
      );
   end if;

   if v_statusz = 'K' then
      raise_application_error(
         -20002,
         'Hiba, az auto mar ki van kolcsonozve! Rendszám: ' || :new.jarmu
      );
   end if;

   if :new.id is null then
      :new.id := get_id(:new.kezdete);
   end if;
end;
/

create or replace trigger trg_kolcsonzes_jarmu_allapot after
   insert or update of allapot on kolcsonzesek
   for each row
begin
   if inserting then
      update jarmuvek
         set
         statusz = 'K'
       where frsz = :new.jarmu;
   elsif
      updating
      and :new.allapot = 'V'
   then
      update jarmuvek
         set
         statusz = 'A'
       where frsz = :new.jarmu;
   end if;
end;
/

-- 4. Készítsen tárolt eljárást jarmu_visszahoz néven!
-- Az eljárás paraméterei:
-- - jarmu, bemenő paraméter, a jármű rendszámának megfelelő adattípus
-- - fizetendo, kimenő paraméter, maximum 15 számjegyű szám, amelyből 2 számjegy tizedesjegy

-- A hívás során zárja le a paraméterben kapott járműhöz kapcsolódó kölcsönzések közül azokat, amelyek függőben vannak (az osszeg mező értéke definiálatlan és kölcsönzés vége múltbéli dátum).

-- Alapértelmezés szerint a kölcsönzés 5 napra történik, ennek díja egységesen 50 000 Ft, ezt a díjat rövidebb kölcsönzés esetén is meg kell fizetni. Hosszabb kölcsönzés esetén minden egyes újabb nappal az eddigi kölcsönzési összeg 1,5-szeresét kell fizetni (pl. 6. nap: 1,5 * 50 000 = 75 000, 7. nap: 1,5 * 75 000 = 112 500, stb).

-- A kölcsönzés hosszába a kezdő és zárónapot egyaránt bele kell számolni! Frissítsük a megfelelő rekord összeg mezőjét a számítás eredménye alapján, valamint, ha a kölcsönzést még nem módosítottuk V státuszra, akkor ezt is végezze el.

-- Ha bármilyen hiba merül fel a végrehajtás során, akkor görgessük vissza az eljárás során végzett összes módosító utasítást. A hívás végén a kimenő paraméterben kerüljön az összes fizetendő összeg, amelyet rögzítettünk az egyes rekordok esetén. Bármilyen hiba esetén a kimenő parméter értéke legyen -1.

create or replace procedure jarmu_visszahoz (
   p_jarmu     in varchar2,
   p_fizetendo out number
) is
   v_napok          number;
   v_dij   number(
      10,
      2
   );

   cursor c_kolcsonzesek is
   select id,
          kezdete,
          vege
     from kolcsonzesek
    where jarmu = p_jarmu
      and osszeg is null
      and vege < sysdate
   for update of osszeg,
                 allapot;

begin
   p_fizetendo := 0;
   -- Megyjegyzes: szerintem itt maximum egy darab rekordunk lehetne (egy jarmu egyszerre nem lehet tobb helyen kikolcsonozve),
   -- de a feladatkiirast kovetve loopolunk rajta egyet
   for r_kolcsonzes in c_kolcsonzesek loop
      -- Beleszamoljuk a vege napot is
      v_napok := trunc(r_kolcsonzes.vege) - trunc(r_kolcsonzes.kezdete) + 1;
      v_dij := 50000;
      if v_napok > 5 then
         for i in 6..v_napok loop
            v_dij := v_dij * 1.5;
         end loop;
      end if;

      update kolcsonzesek
         set osszeg = v_dij,
             allapot = 'V'
       where current of c_kolcsonzesek;

      p_fizetendo := p_fizetendo + v_dij;
   end loop;

   if p_fizetendo > 0 then
      commit;
   end if;
exception
   when others then
      rollback;
      p_fizetendo := -1;
      dbms_output.put_line('Hiba tortent: ' || sqlerrm);
end;
/


-- *** 5. Tesztelés: Anonim PL/SQL blokk ***

declare
   v_fizetendo     number(
      15,
      2
   );
   v_jarmu_statusz char(1);
   v_hiba_uzenet   varchar2(255);
begin
   dbms_output.put_line('--- Tesztelés indítása ---');

    -- 1. Teszt: Sikeres kölcsönzés (ABC-123 Aktív, 1-es ügyfél Aktív)
   dbms_output.put_line('1. Teszt: Sikeres kölcsönzés (ABC-123, 3 nap)');
   insert into kolcsonzesek (
      jarmu,
      ugyfel,
      kezdete,
      vege,
      allapot
   ) values ( 'ABC-123',
              1,
              sysdate,
              sysdate + 3,
              'K' );
   commit; -- A trigger fut, ABC-123 státusza 'K' lesz.

   select statusz
     into v_jarmu_statusz
     from jarmuvek
    where frsz = 'ABC-123';
   dbms_output.put_line('ABC-123 új státusza a kölcsönzés után: ' || v_jarmu_statusz);


    -- 2. Teszt: Sikertelen kölcsönzés (Már kölcsönzött autó)
   dbms_output.put_line(chr(10) || '2. Teszt: Már kölcsönzött autó kölcsönzése (ABC-123)');
   begin
      insert into kolcsonzesek (
         jarmu,
         ugyfel,
         kezdete,
         vege,
         allapot
      ) values ( 'ABC-123',
                 1,
                 sysdate,
                 sysdate + 2,
                 'K' );
      dbms_output.put_line('HIBA! Sikeresen beszúrtuk, pedig nem lett volna szabad.');
   exception
      when others then
         if sqlcode = -20002 then
            dbms_output.put_line('Sikeres hiba elkapás: ' || sqlerrm);
            rollback;
         else
            dbms_output.put_line('Váratlan hiba: ' || sqlerrm);
         end if;
   end;

    -- 3. Teszt: Sikertelen kölcsönzés (Szervizben lévő autó)
   dbms_output.put_line(chr(10) || '3. Teszt: Szervizben lévő autó kölcsönzése (SER-001)');
   begin
      insert into kolcsonzesek (
         jarmu,
         ugyfel,
         kezdete,
         vege,
         allapot
      ) values ( 'SER-001',
                 1,
                 sysdate,
                 sysdate + 1,
                 'K' );
      dbms_output.put_line('HIBA! Sikeresen beszúrtuk, pedig nem lett volna szabad.');
   exception
      when others then
         if sqlcode = -20001 then
            dbms_output.put_line('Sikeres hiba elkapás: ' || sqlerrm);
            rollback;
         else
            dbms_output.put_line('Váratlan hiba: ' || sqlerrm);
         end if;
   end;


    -- 4. Teszt: Kölcsönzés lezárása (Jarmu_visszahoz eljárás)
   dbms_output.put_line(chr(10) || '4. Teszt: Jarmu_visszahoz futtatása (ABC-123)');

    -- Beszúrunk egy teszt kölcsönzést a múltba, ami függőben van (3 napos, vege: tegnap)
   insert into kolcsonzesek (
      jarmu,
      ugyfel,
      kezdete,
      vege,
      allapot
   ) values ( 'TES-555',
              1,
              sysdate - 5,
              sysdate - 3,
              'K' ); -- 3 napos kölcsönzés (3 nap < 5 nap)

    -- Beszúrunk egy 7 napos kölcsönzést is
   insert into kolcsonzesek (
      jarmu,
      ugyfel,
      kezdete,
      vege,
      allapot
   ) values ( 'TES-556',
              1,
              sysdate - 8,
              sysdate - 2,
              'K' ); -- 7 napos kölcsönzés (progresszív)
   commit; -- Az eljárás csak a committált adatokat látja

   jarmu_visszahoz(
      'TES-555',
      v_fizetendo
   );
   dbms_output.put_line('A TES-555 járműnél a fizetendő végösszeg: '
                        || v_fizetendo || ' Ft');

   jarmu_visszahoz(
      'TES-556',
      v_fizetendo
   );
   dbms_output.put_line('A TES-556 járműnél a fizetendő végösszeg: '
                        || v_fizetendo || ' Ft');

    -- Ellenőrzés: Az eljárás utáni állapot
   select statusz
     into v_jarmu_statusz
     from jarmuvek
    where frsz = 'TES-555';
   dbms_output.put_line('TES-555 új státusza a visszahozatal után: ' || v_jarmu_statusz);

    -- Ellenőrzés: Az eljárás utáni állapot
   select statusz
     into v_jarmu_statusz
     from jarmuvek
    where frsz = 'TES-556';
   dbms_output.put_line('TES-556 új státusza a visszahozatal után: ' || v_jarmu_statusz);

    -- Várható eredmények (Összegek):
    -- 3 nap: 50000.00 Ft
    -- 7 nap: $50000 \times 1.5^2 \times 1.5 \times 1.5 = 50000 + 75000 + 112500$ (Ez a számítási mód eltér a megfogalmazástól. A feladat szerint az *eddigi összeg* 1,5-szerese a plusz nap díja.)

    -- Számítás a feladat alapján:
    -- 1-5. nap: 50.000 Ft (az 5 napos díj)
    -- 6. nap: 50000 * 1.5 = 75000.00 Ft
    -- 7. nap: 75000 * 1.5 = 112500.00 Ft
    -- Összesen 7 napra: 112500.00 Ft (az utolsó nap díja)

    -- Teszt 4 eredménye:
    -- 3 napos díj: 50000.00
    -- 7 napos díj: 112500.00
    -- Összesen: 162500.00

   dbms_output.put_line('--- Tesztelés befejezése ---');
end;
/