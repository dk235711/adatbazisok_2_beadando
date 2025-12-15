-- Kapitany David
-- L4YG0N

-- 1. Készítse el a kolcsonzesek táblát az alábbi leírás szerint!
--     a. Mezők:
--         i. id: állandó hosszúságú, 15 karakteres mező, nem lehet null
--         ii. jarmu: a kölcsönzéshez tartozó jármű rendszáma, típusa a jarmuvek tábla elsődleges kulcsának típusával egyezik meg, nem lehet null
--         iii. ugyfel: az ügyfél azonosítója, típusa az ugyfelek tábla elsődleges kulcsának típusával egyezik meg, nem lehet null
--         iv. kezdete: a kölcsönzés kezdetének dátuma, nem lehet null
--         v. vege: a kölcsönzés végének dátuma, értéke nem lehet null
--         vi. allapot: egy hosszú karakteres mező, amely a kölcsönzés státuszát jelöli (F - foglalva, K - kölcsönözve, V - visszavéve)
--         vii. osszeg: a kölcsönzés végén fizetendő összeg, 10 számjegyből álló szám, amelyből két számjegyet tizedesek tárolására használunk, értéke lehet null
--     b. Megszorítások:
--         i. A tábla elsődleges kulcsa legyen az id mező.
--         ii. A jarmu a jarmuvek táblára hivatkozó idegenkulcs megszorítás. iii. Az ugyfel az ugyfelek táblára hivatkozó idegenkulcs megszorítás.
--         iv. A jarmu mező esetén biztosítsuk, hogy csak a magyar rendszámoknak megfelelő rendszámokat fogadjunk el (a klasszikus három betű három szám kötőjellel elválasztva (pl. AAA-001), vagy az új típusú kétszer kétbetű és három szám kötőjellel elválasztva (AA-AA-001)).
--         v. A kezdete mező dátumértéke mindig kisebb, mint a vege mező dátumértéke.
--         vi. Az osszeg mező értéke (ha definiálva van) nagyobb, mint 0.
--         vii. Az allapot mezőbe csak F vagy K vagy V betű kerülhet.

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

commit;

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