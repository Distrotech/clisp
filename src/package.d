# Package-Verwaltung für CLISP
# Bruno Haible 1990-2002
# Sam Steingold 1999-2002

#include "lispbibl.c"
#include "arilev0.c" # für Hashcode-Berechnung

# Datenstruktur des Symbols: siehe LISPBIBL.D
# Datenstruktur der Symboltabelle:
# ein Vektor mit 3 Slots:
#   size    Fixnum >0, <2^16, = Länge der table
#   table   Vektor der Länge size,
#             enthält einzelne Symbole (/= NIL) und Symbollisten
#   count   Anzahl der Symbole in der Table, Fixnum >=0
  #define Symtab_size(symtab)  (TheSvector(symtab)->data[0])
  #define Symtab_table(symtab)  (TheSvector(symtab)->data[1])
  #define Symtab_count(symtab)  (TheSvector(symtab)->data[2])
# Konsistenzregel:
# Zu jedem String gibt es in der Tabelle höchstens ein Symbol mit diesem
# Printnamen.

# UP: Kreiert eine neue leere Symboltabelle.
# make_symtab(size)
# > size: gewünschte Größe der Tabelle (ungerade, >0, <2^16)
# < ergebnis: neue Symboltabelle dieser Größe
# can trigger GC
  local object make_symtab (uintL size);
  local object make_symtab(size)
    var uintL size;
    {
      var object table = allocate_vector(size); # Vektor mit size NIL-Einträgen
      pushSTACK(table);
      var object symtab = allocate_vector(3); # Vektor der Länge 3
      Symtab_table(symtab) = popSTACK(); # table einfüllen
      Symtab_size(symtab) = fixnum(size); # size einfüllen
      Symtab_count(symtab) = Fixnum_0; # count := 0 einfüllen
      return symtab;
    }

# UP: berechnet den Hashcode eines Strings. Dies ist eine 16-Bit-Zahl.
# string_hashcode(string)
# > string: ein String.
# < ergebnis: der Hashcode des Strings
  local uint16 string_hashcode (object string);
  local uint16 string_hashcode(string)
    var object string;
    {
      var uintL len;
      var uintL offset;
      string = unpack_string_ro(string,&len,&offset);
      SstringDispatch(string,
        {
          var const chart* charptr = &TheSstring(string)->data[offset];
          # ab charptr kommen len Zeichen
          var uint32 hashcode = 0; # Hashcode, nur die unteren 16 Bit sind wesentlich
          var uintC count;
          dotimesC(count, (len>16 ? 16 : len), { # min(len,16) mal:
            # hashcode um 5 Bit nach links rotieren:
            hashcode = hashcode << 5; hashcode = hashcode | high16(hashcode);
            # und nächstes Byte dazuXORen:
            hashcode = hashcode ^ (uint32)as_cint(*charptr++);
          });
          return (uint16)hashcode;
        },
        {
          var const scint* charptr = &TheSmallSstring(string)->data[offset];
          # ab charptr kommen len Zeichen
          var uint32 hashcode = 0; # Hashcode, nur die unteren 16 Bit sind wesentlich
          var uintC count;
          dotimesC(count, (len>16 ? 16 : len), { # min(len,16) mal:
            # hashcode um 5 Bit nach links rotieren:
            hashcode = hashcode << 5; hashcode = hashcode | high16(hashcode);
            # und nächstes Byte dazuXORen:
            hashcode = hashcode ^ (uint32)(cint)(*charptr++);
          });
          return (uint16)hashcode;
        }
        );
    }

# UP: Reorganisiert eine Symboltabelle, nachdem sie gewachsen ist, und
# versucht dabei Conses zu sparen.
# rehash_symtab(symtab)
# > symtab: Symboltabelle
# < ergebnis: reorganisierte Symboltabelle (EQ zur ersten).
# nur bei gesetzter BREAK_SEM_2 aufzurufen
# can trigger GC
  local object rehash_symtab (object symtab);
  #
  # Hilfsfunktionen:
  #
  # Entnimmt ein Cons aus free-conses oder liefert ein frisches.
  # new_cons()
  # < ergebnis: neues Cons.
  # Stackaufbau: free-conses, newtable, listr, symbol, entry.
  # can trigger GC
    local object new_cons (void);
    local object new_cons()
      {
        var object free = STACK_4; # free-conses
        if (!nullp(free)) {
          STACK_4 = Cdr(free); # free-conses verkürzen
          return free;
        } else {
          return allocate_cons(); # neues Cons aus der Speicherverwaltung anfordern
        }
      }
  #
  # Fügt ein Symbol zusätzlich in die neue Tabelle ein.
  # newinsert(sym,size);
  # > sym: Symbol
  # Stackaufbau: tab, oldtable, free-conses, newtable, listr.
  # can trigger GC
    local void newinsert (object sym, uintWL size);
    local void newinsert(sym,size)
      var object sym;
      var uintWL size;
      {
        var uintL index = # Index = Hashcode mod size
                  (uintL)(string_hashcode(Symbol_name(sym)) % size);
        var object entry = TheSvector(STACK_1)->data[index]; # entry in der newtable
        if ((!nullp(entry)) || nullp(sym)) {
          # Ist entry=NIL und sym/=NIL, so ist einfach sym einzutragen.
          # Sonst muss entry durch Consen erweitert werden:
          pushSTACK(sym); # Symbol retten
          pushSTACK(entry); # entry retten
          if (!listp(entry)) {
            # Falls entry keine Liste ist, durch (new-cons entry NIL) ersetzen:
            var object new_entry = new_cons();
            Cdr(new_entry) = NIL; Car(new_entry) = STACK_0;
            STACK_0 = new_entry;
          }
          # und Symbol davorconsen:
          var object new_entry = new_cons();
          Cdr(new_entry) = popSTACK(); # entry bzw. Liste als CDR eintragen
          Car(new_entry) = popSTACK(); # Symbol als CAR eintragen
          sym = new_entry; # und dann new_entry eintragen
        }
        TheSvector(STACK_1)->data[index] = sym; # neue Entry in newtable eintragen
      }
  #
  local object rehash_symtab(symtab)
    var object symtab;
    {
      pushSTACK(symtab); # Symboltabelle retten
      var uintL oldsize = posfixnum_to_L(Symtab_size(symtab)); # alte Größe
      var uintL newsize; # neue Größe
      var object size; # neue Größe (als Fixnum)
      pushSTACK(Symtab_table(symtab)); # oldtable = alter Tabellenvektor
      pushSTACK(NIL); # free-conses := NIL
      # neue Größe = min(floor(oldsize*1.6),65535)
      {
        # multipliziere oldsize (>0, <2^16) mit 1.6*2^15, dann durch 2^15 :
        var uint32 prod = mulu16(oldsize,52429UL);
        newsize = (prod < (1UL<<31) ? prod>>15 : (1UL<<16)-1 );
      } # newsize ist jetzt >= oldsize > 0 und < 2^16
      # newsize durch Abrunden ungerade machen:
      newsize = (newsize - 1) | 1 ;
      # size berechnen:
      size = fixnum(newsize);
      # Bei newsize <= oldsize braucht die Tabelle nicht vergrößert zu werden:
      if (newsize <= oldsize) {
        skipSTACK(3);
        return symtab;
      }
      {
        var object newtable = allocate_vector(newsize); # neuer Vektor mit size NILs
        pushSTACK(newtable); # retten
      }
      # Hier könnte man gegen Unterbrechungen schützen.
      # Stackaufbau: tab, oldtable, free-conses, newtable.
      # Symbole von oldtable nach newtable übertragen:
        # Erst die Symbole verarbeiten, die auf Listen sitzen
        # (dabei werden evtl. Conses frei):
        {
          var object* offset = 0; # offset = sizeof(object)*index
          var uintC count;
          dotimespC(count,oldsize, {
            var object oldentry = # Eintrag mit Nummer index in oldtable
                *(object*)(pointerplus(&TheSvector(STACK_2)->data[0],(aint)offset));
            if (consp(oldentry)) # diesmal nur nichtleere Symbollisten verarbeiten
              do {
                pushSTACK(Cdr(oldentry)); # Restliste retten
                Cdr(oldentry) = STACK_2; STACK_2 = oldentry; # oldentry vor free-conses consen
                newinsert(Car(oldentry),newsize); # Symbol in die neue Tabelle eintragen
                oldentry = popSTACK(); # Restliste
              } while (consp(oldentry));
            offset++;
          });
        }
        # Dann die Symbole verarbeiten, die kollisionsfrei dasitzen:
        {
          var object* offset = 0; # offset = sizeof(object)*index
          var uintC count;
          dotimespC(count,oldsize, {
            var object oldentry = # Eintrag mit Nummer index in oldtable
                *(object*)(pointerplus(&TheSvector(STACK_2)->data[0],(aint)offset));
            if (!listp(oldentry)) { # diesmal nur Symbole /= NIL verarbeiten
              pushSTACK(oldentry); # Dummy, damit der Stack stimmt
              newinsert(oldentry,newsize); # in die neue Tabelle eintragen
              skipSTACK(1);
            }
            offset++;
          });
        }
        # Stackaufbau: tab, oldtable, free-conses, newtable.
      # tab aktualisieren:
      {
        var object newtable = popSTACK(); # newtable
        skipSTACK(2);
        symtab = popSTACK(); # tab
        Symtab_size(symtab) = size;
        Symtab_table(symtab) = newtable;
      }
      # Hier könnte man Unterbrechungen wieder zulassen.
      return symtab;
    }

# UP: Sucht ein Symbol gegebenen Printnamens in einer Symboltabelle.
# symtab_lookup(string,symtab,&sym)
# > string: String
# > symtab: Symboltabelle
# < ergebnis: true falls gefunden, false falls nicht gefunden.
# falls gefunden:
#   < sym: das Symbol aus der Symboltabelle, das den gegebenen Printnamen hat
  local bool symtab_lookup (object string, object symtab, object* sym_);
  local bool symtab_lookup(string,symtab,sym_)
    var object string;
    var object symtab;
    var object* sym_;
    {
      var uintL index = # Index = Hashcode mod size
          (uintL)(string_hashcode(string) % (uintW)(posfixnum_to_L(Symtab_size(symtab))));
      var object entry = TheSvector(Symtab_table(symtab))->data[index]; # entry in der table
      if (!listp(entry)) {
        # entry ist ein einzelnes Symbol
        # erster String und Printname des gefundenen Symbols gleich ?
        if (string_gleich(string,Symbol_name(entry))) {
          if (sym_) { *sym_ = entry; }
          return true;
        } else {
          return false;
        }
      } else {
        # entry ist eine Symbolliste
        while (consp(entry)) {
          # erster String und Printname des Symbols gleich ?
          if (string_gleich(string,Symbol_name(Car(entry))))
            goto found;
          entry = Cdr(entry);
        }
        return false; # nicht gefunden
       found: # gefunden als CAR von entry
        if (sym_) { *sym_ = Car(entry); }
        return true;
      }
    }

# UP: Sucht ein gegebenes Symbol in einer Symboltabelle.
# symtab_find(sym,symtab)
# > sym: Symbol
# > symtab: Symboltabelle
# < ergebnis: true wenn gefunden
  local bool symtab_find (object sym, object symtab);
  local bool symtab_find(sym,symtab)
    var object sym;
    var object symtab;
    {
      var uintL index = # Index = Hashcode mod size
          (uintL)(string_hashcode(Symbol_name(sym)) % (uintW)(posfixnum_to_L(Symtab_size(symtab))));
      var object entry = TheSvector(Symtab_table(symtab))->data[index]; # entry in der table
      if (!listp(entry)) {
        # entry ist ein einzelnes Symbol
        # sym und gefundenes Symbol gleich ?
        if (eq(sym,entry))
          return true;
        else
          return false;
      } else {
        # entry ist eine Symbolliste
        while (consp(entry)) {
          # sym und Symbol aus entry gleich ?
          if (eq(sym,Car(entry)))
            goto found;
          entry = Cdr(entry);
        }
        return false; # nicht gefunden
       found: # gefunden als CAR von entry
        return true;
      }
    }

# UP: Fügt ein gegebenes Symbol in eine Symboltabelle ein (destruktiv).
# symtab_insert(sym,symtab)
# > sym: Symbol
# > symtab: Symboltabelle
# < ergebnis: neue Symboltabelle, EQ zur alten
# nur bei gesetzter BREAK_SEM_2 aufzurufen
# can trigger GC
  local object symtab_insert (object sym, object symtab);
  local object symtab_insert(sym,symtab)
    var object sym;
    var object symtab;
    {
      # erst der Test, ob Reorganisieren nötig ist:
      {
        var uintL size = posfixnum_to_L(Symtab_size(symtab));
        var uintL count = posfixnum_to_L(Symtab_count(symtab));
        # Bei count>=2*size muss die Tabelle reorganisiert werden:
        if (count >= 2*size) {
          pushSTACK(sym); # Symbol retten
          symtab = rehash_symtab(symtab);
          sym = popSTACK();
        }
      }
      # Dann das Symbol einfügen:
      var uintL index = # Index = Hashcode mod size
          (uintL)(string_hashcode(Symbol_name(sym)) % (uintW)(posfixnum_to_L(Symtab_size(symtab))));
      var object entry = TheSvector(Symtab_table(symtab))->data[index]; # entry in der table
      if (!nullp(entry) || nullp(sym)) {
        # Ist entry=NIL und sym/=NIL, so ist einfach sym einzutragen.
        # Sonst muss entry durch Consen erweitert werden:
        pushSTACK(symtab); # symtab retten
        pushSTACK(sym); # Symbol retten
        pushSTACK(entry); # entry retten
        if (!listp(entry)) {
          # Falls entry keine Liste ist, durch (cons entry NIL) ersetzen:
          var object new_entry = allocate_cons();
          Car(new_entry) = STACK_0;
          STACK_0 = new_entry;
        }
        # und Symbol davorconsen:
        {
          var object new_entry = allocate_cons();
          Cdr(new_entry) = popSTACK(); # entry bzw. Liste als CDR eintragen
          Car(new_entry) = popSTACK(); # Symbol als CAR eintragen
          sym = new_entry; # und dann new_entry eintragen
        }
        symtab = popSTACK();
      }
      TheSvector(Symtab_table(symtab))->data[index] = sym; # neue Entry eintragen
      Symtab_count(symtab) = fixnum_inc(Symtab_count(symtab),1); # (incf count)
      return symtab;
    }

# UP: Entfernt aus einer Symboltabelle ein darin vorkommendes Symbol.
# symtab_delete(sym,symtab)
# > sym: Symbol
# > symtab: Symboltabelle
  local void symtab_delete (object sym, object symtab);
  local void symtab_delete(sym,symtab)
    var object sym;
    var object symtab;
    {
      var uintL index = # Index = Hashcode mod size
          (uintL)(string_hashcode(Symbol_name(sym)) % (uintW)(posfixnum_to_L(Symtab_size(symtab))));
      var object* entryptr = &TheSvector(Symtab_table(symtab))->data[index];
      var object entry = *entryptr; # entry in der table
      if (!listp(entry)) {
        # entry ist ein einzelnes Symbol
        # sym und gefundenes Symbol gleich ?
        if (!eq(sym,entry))
          goto notfound;
        # entry durch NIL ersetzen:
        *entryptr = NIL;
      } else {
        # entry ist eine Symbolliste
        while (consp(entry)) {
          # sym und Symbol aus entry gleich ?
          if (eq(sym,Car(entry)))
            goto found;
          entryptr = &Cdr(entry); entry = *entryptr;
        }
        goto notfound; # nicht gefunden
       found: # gefunden als CAR von *entryptr = entry
              # -> ein Listenelement streichen:
        *entryptr = Cdr(entry); # entry durch Cdr(entry) ersetzen
      }
      # schließlich noch den Symbolzähler um 1 erniedrigen:
      Symtab_count(symtab) = fixnum_inc(Symtab_count(symtab),-1); # (decf count)
      return;
      # nicht gefunden
     notfound:
      pushSTACK(unbound); # "Wert" für Slot PACKAGE von PACKAGE-ERROR
      pushSTACK(sym);
      fehler(package_error,
             GETTEXT("symbol ~ cannot be deleted from symbol table")
            );
    }

# Check whether there is an inherited symbol with the given name.
# inherited_lookup(string,pack,symb)
# Return true iff string is found in (package-use-list pack).
# STRING is a Lisp string object
# PACK is a Lisp package object
# The symbol found is returned in *SYM_ (if SYM_ is not NULL).
local bool inherited_lookup (object string, object pack, object* sym_)
{
  var object packlistr = ThePackage(pack)->pack_use_list;
  while (consp(packlistr)) {
    var object usedpack = Car(packlistr);
    if (symtab_lookup(string,ThePackage(usedpack)->pack_external_symbols,sym_))
      return true;
    packlistr = Cdr(packlistr);
  }
  return false;
}

# Check whether the symbol is inherited by the package.
# inherited_find(symbol,pack)
# SYMBOL is a Lisp symbol object
# PACK is a Lisp package object
local bool inherited_find (object symbol, object pack)
{
  var object list = ThePackage(pack)->pack_use_list;
  while (consp(list)) {
    if (symtab_find(symbol,ThePackage(Car(list))->pack_external_symbols))
      return true;
    list = Cdr(list);
  }
  return false;
}

# Datenstruktur der Package siehe LISPBIBL.D.
# Komponenten:
# pack_external_symbols   Symboltabelle der extern präsenten Symbole
# pack_internal_symbols   Symboltabelle der intern präsenten Symbole
# pack_shadowing_symbols  Liste der Shadowing-Symbole
# pack_use_list           Use-List, eine Liste von Packages
# pack_used_by_list       Used-by-List, eine Liste von Packages
# pack_name               der Name, ein immutable Simple-String
# pack_nicknames          die Nicknames, eine Liste von immutablen Simple-Strings

# consistency rules:
# 1. All packages are listed in ALL_PACKAGES exactly once.
# 2. The union over ALL_PACKAGES of { name } U nicknames is disjoint.
# 3. for any two packages p,q:
#    p in use_list(q) <==> q in used_by_list(q)
# 4. p is a Package.
#    accessible(p) = ISymbols(p) U ESymbols(p) U
#                    U { ESymbols(q) | q in use_list(p) }
# 5. For each Package p
#    shadowing_symbols(p) is a subset of ISymbols(p) U ESymbols(p)
#    and therefore also      a subset of accessible(p).
# 6. s is a string, p is a package.
#    If more than one element of accessible(p) has print name = s, then
#    exactly one of these symbols is in shadowing_symbols(p).
# 7. s is a string, p is a package.
#    At most one symbol with the print name = s
#    is in ISymbols(p) U ESymbols(p).
# 8. If s is a symbol with the Home Package p /= NIL,
#    then s is in ISymbols(p) U ESymbols(p).

# UP: Erzeugt eine neue Package, ohne auf Namenskonflikte zu testen.
# make_package(name,nicknames,case_sensitive_p)
# > name: Name (ein immutable Simple-String)
# > nicknames: Nicknames (eine Liste von immutablen Simple-Strings)
# > case_sensitive_p: Flag, ob case-sensitive
# < ergebnis: neue Package
# can trigger GC
  local object make_package (object name, object nicknames, bool case_sensitive_p);
  local object make_package(name,nicknames,case_sensitive_p)
    var object name;
    var object nicknames;
    var bool case_sensitive_p;
    {
      set_break_sem_2();
      pushSTACK(nicknames); pushSTACK(name); # Nicknames und Namen retten
      # Tabelle für externe Symbole erzeugen:
      { var object symtab = make_symtab(11); pushSTACK(symtab); }
      # Tabelle für interne Symbole erzeugen:
      { var object symtab = make_symtab(63); pushSTACK(symtab); }
      # neue Package erzeugen:
      var object pack = allocate_package();
      # und füllen:
      if (case_sensitive_p) { mark_pack_casesensitive(pack); }
      ThePackage(pack)->pack_internal_symbols = popSTACK();
      ThePackage(pack)->pack_external_symbols = popSTACK();
      ThePackage(pack)->pack_shadowing_symbols = NIL;
      ThePackage(pack)->pack_use_list = NIL;
      ThePackage(pack)->pack_used_by_list = NIL;
      ThePackage(pack)->pack_name = popSTACK();
      ThePackage(pack)->pack_nicknames = popSTACK();
      # und in ALL_PACKAGES einhängen:
      pushSTACK(pack);
      var object new_cons = allocate_cons();
      pack = popSTACK();
      Car(new_cons) = pack; Cdr(new_cons) = O(all_packages);
      O(all_packages) = new_cons;
      # fertig:
      clr_break_sem_2();
      return pack;
    }

# UP: Sucht ein Symbol gegebenen Printnamens in der Shadowing-Liste einer
# Package.
# shadowing_lookup(string,pack,&sym)
# > string: String
# > pack: Package
# < ergebnis: true, falls gefunden.
# < sym: das Symbol aus der Shadowing-Liste, das den gegebenen Printnamen hat
#        (falls gefunden)
  local bool shadowing_lookup (object string, object pack, object* sym_);
  local bool shadowing_lookup(string,pack,sym_)
    var object string;
    var object pack;
    var object* sym_;
    {
      var object list = ThePackage(pack)->pack_shadowing_symbols;
      # Shadowing-Liste durchlaufen:
      while (consp(list)) {
        if (string_gleich(string,Symbol_name(Car(list))))
          goto found;
        list = Cdr(list);
      }
      return false; # nicht gefunden
     found: # gefunden
      if (sym_) { *sym_ = Car(list); }
      return true;
    }

# UP: Sucht ein gegebenes Symbol in der Shadowing-Liste einer Package.
# shadowing_find(sym,pack)
# > sym: Symbol
# > pack: Package
# < ergebnis: true falls gefunden.
  local bool shadowing_find (object sym, object pack);
  local bool shadowing_find(sym,pack)
    var object sym;
    var object pack;
    {
      var object list = ThePackage(pack)->pack_shadowing_symbols;
      # Shadowing-Liste durchlaufen:
      while (consp(list)) {
        if (eq(sym,Car(list)))
          goto found;
        list = Cdr(list);
      }
      return false; # nicht gefunden
     found: # gefunden
      return true;
    }

# UP: Fügt ein Symbol zur Shadowing-Liste einer Package, die noch kein
# Symbol desselben Namens enthält, hinzu.
# shadowing_insert(&sym,&pack)
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < sym: Symbol, EQ zum alten
# < pack: Package, EQ zur alten
# can trigger GC
  local void shadowing_insert (const object* sym_, const object* pack_);
  local void shadowing_insert(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      # neues Cons mit Symbol als CAR vor die Shadowing-Symbols einhängen:
      var object new_cons = allocate_cons();
      var object pack = *pack_;
      Car(new_cons) = *sym_;
      Cdr(new_cons) = ThePackage(pack)->pack_shadowing_symbols;
      ThePackage(pack)->pack_shadowing_symbols = new_cons;
    }

# UP: Entfernt ein Symbol gegebenen Namens aus der Shadowing-Liste
# einer Package.
# shadowing_delete(string,pack)
# > string: String
# > pack: Package
  local void shadowing_delete (object string, object pack);
  local void shadowing_delete(string,pack)
    var object string;
    var object pack;
    {
      var object* listptr = &ThePackage(pack)->pack_shadowing_symbols;
      var object list = *listptr;
      # list = *listptr durchläuft die Shadowing-Liste
      while (consp(list)) {
        if (string_gleich(string,Symbol_name(Car(list))))
          goto found;
        listptr = &Cdr(list); list = *listptr;
      }
      # kein Symbol dieses Namens gefunden, fertig.
      return;
     found:
      # Gleichheit: entfernen. Danach ist man fertig, da es in der
      # Shadowing-Liste nur ein Symbol desselben Printnamens geben kann.
      *listptr = Cdr(list); # list durch Cdr(list) ersetzen
      return;
    }

# UP: testet, ob ein Symbol in einer Package accessible ist und dabei nicht
# von einem anderen Symbol desselben Namens verdeckt wird.
# accessiblep(sym,pack)
# > sym: Symbol
# > pack: Package
# < ergebnis: true falls sym in pack accessible und nicht verdeckt ist,
#             false sonst
  global bool accessiblep (object sym, object pack);
  global bool accessiblep(sym,pack)
    var object sym;
    var object pack;
    {
      # Methode:
      # Suche erst ein Symbol gleichen Namens in der Shadowing-Liste;
      # falls nicht gefunden, suche das Symbol unter den präsenten und dann
      # unter den vererbten Symbolen.
      # Andere mögliche Methode (hier nicht realisiert):
      # Ist die Home-Package von sym gleich pack, so ist sym in pack präsent,
      # fertig. Sonst suche ein präsentes Symbol gleichen Namens.
      # sym gefunden -> fertig.
      # Ein anderes gefunden -> sym ist nicht auf der Shadowing-Liste und
      # daher nicht sichtbar.
      # Keins gefunden -> Suche sym unter den vererbten Symbolen.
      var object shadowingsym;
      # Suche erst in der Shadowing-Liste von pack:
      if (shadowing_lookup(Symbol_name(sym),pack,&shadowingsym)) {
        # shadowingsym = in der Shadowing-Liste gefundenes Symbol
        return (eq(shadowingsym,sym)); # mit sym vergleichen
      } else {
        # Kein Symbol gleichen Namens in der Shadowing-Liste
        # Suche unter den internen Symbolen:
        if (symtab_find(sym,ThePackage(pack)->pack_internal_symbols))
          return true;
        # Suche unter den externen Symbolen:
        if (symtab_find(sym,ThePackage(pack)->pack_external_symbols))
          return true;
        # Suche unter den externen Symbolen der Packages aus der Use-List:
        if (inherited_find(sym,pack))
          return true;
        return false;
      }
    }

# UP: testet, ob ein Symbol in einer Package als externes Symbol accessible
# ist.
# externalp(sym,pack)
# > sym: Symbol
# > pack: Package
# < ergebnis:
#     true falls sym in pack als externes Symbol accessible ist,
#     (in diesem Falle ist sym nicht verdeckt, denn ein eventuell sym
#      vedeckendes Symbol müsste in shadowing-symbols(pack) aufgeführt sein,
#      nach den Konsistenzregeln 5 und 7 also mit sym identisch sein),
#     false sonst
  global bool externalp (object sym, object pack);
  global bool externalp(sym,pack)
    var object sym;
    var object pack;
    {
      return symtab_find(sym,ThePackage(pack)->pack_external_symbols);
    }

# UP: sucht ein externes Symbol gegebenen Printnamens in einer Package.
# find_external_symbol(string,pack,&sym)
# > string: String
# > pack: Package
# < ergebnis: true, falls ein externes Symbol dieses Printnamens in pack gefunden.
# < sym: dieses Symbol, falls gefunden.
  global bool find_external_symbol (object string, object pack, object* sym_);
  global bool find_external_symbol(string,pack,sym_)
    var object string;
    var object pack;
    var object* sym_;
    {
      return symtab_lookup(string,ThePackage(pack)->pack_external_symbols,&(*sym_));
    }

# UP: Nachfragefunktion an den Benutzer.
# query_user(ml)
# > ml: nichtleere Liste von Möglichkeiten. Jede Möglichkeit ist dabei eine
#       Liste aus einem Kurz-String (den der Benutzer eintippen soll), einem
#       Langstring (der der Erläuterung dient) und weiteren Informationen.
# < ergebnis: Die vom Benutzer angewählte Möglichkeit.
# can trigger GC
  local object query_user (object ml);
  local object query_user(ml)
    var object ml;
    {
      pushSTACK(ml);
      var object stream = var_stream(S(query_io),strmflags_rd_ch_B|strmflags_wr_ch_B); # Stream *QUERY-IO*
      var object* stream_;
      pushSTACK(stream);
      stream_ = &STACK_0;
      terpri(stream_); # Neue Zeile
      write_sstring(stream_,OLS(query_string1)); # "Wählen Sie bitte aus:"
      # Möglichkeiten ausgeben:
      {
        var object mlistr = STACK_1; # restliche Möglichkeiten
        while (consp(mlistr)) {
          pushSTACK(mlistr);
          terpri(stream_);
          write_sstring(stream_,O(query_string2)); # "          "
          {
            var object moeglichkeit = Car(STACK_0); # nächste Möglichkeit
            pushSTACK(Car(Cdr(moeglichkeit))); # Langstring retten
            write_string(stream_,Car(moeglichkeit)); # Kurzstring ausgeben
            write_sstring(stream_,O(query_string3)); # "  --  "
            write_string(stream_,popSTACK()); # Langstring ausgeben
          }
          mlistr = popSTACK();
          mlistr = Cdr(mlistr);
        }
      }
      terpri(stream_);
      terpri(stream_);
      # Benutzer-Antwort einlesen:
      loop {
        write_sstring(stream_,O(query_string5)); # ">> "
        pushSTACK(*stream_); funcall(L(read_line),1); # (READ-LINE stream) aufrufen
        pushSTACK(value1); # Antwort retten
        # Stackaufbau: Möglichkeiten, Stream, Antwort
          # Antwort mit den Kurzstrings vergleichen:
          pushSTACK(STACK_2); # Möglichkeiten durchgehen
          while (mconsp(STACK_0)) {
            pushSTACK(Car(Car(STACK_0))); # nächsten Kurzstring
            pushSTACK(STACK_2); # mit Antwort vergleichen:
            funcall(L(string_gleich),2); # (STRING= Kurzstring Antwort)
            if (!nullp(value1))
              goto antwort_ok;
            STACK_0 = Cdr(STACK_0); # Möglichkeitenliste verkürzen
          }
          skipSTACK(1);
          # Antwort mit den Kurzstrings vergleichen, diesmal lascher:
          pushSTACK(STACK_2); # Möglichkeiten durchgehen
          while (mconsp(STACK_0)) {
            pushSTACK(Car(Car(STACK_0))); # nächsten Kurzstring
            pushSTACK(STACK_2); # mit Antwort vergleichen:
            funcall(L(string_equal),2); # (STRING-EQUAL Kurzstring Antwort)
            if (!nullp(value1))
              goto antwort_ok;
            STACK_0 = Cdr(STACK_0); # Möglichkeitenliste verkürzen
          }
          skipSTACK(1);
        skipSTACK(1); # Antwort vergessen
        # bis jetzt immer noch keine korrekte Antwort
        pushSTACK(*stream_);
        pushSTACK(OLS(query_string4)); # "Wählen Sie bitte eines von ~:{~A~:^, ~} aus."
        pushSTACK(STACK_(1+2)); # Möglichkeiten
        funcall(S(format),3); # (FORMAT stream ... Möglichkeitenliste)
        terpri(stream_);
      }
     antwort_ok:
      var object mlistr = popSTACK(); # letzte Möglichkeitenliste
      skipSTACK(3); # Antwort, Stream und Möglichkeitenliste vergessen
      return Car(mlistr); # angewählte Möglichkeit
    }

# UP: sucht eine Package mit gegebenem Namen oder Nickname
# find_package(string)
# > string: String
# < ergebnis: Package mit diesem Namen oder NIL
  global object find_package (object string);
  global object find_package(string)
    var object string;
    {
      var object packlistr = O(all_packages); # Package-Liste durchgehen
      var object pack;
      while (consp(packlistr)) {
        pack = Car(packlistr); # zu testende Package
        # Teste Namen:
        if (string_gleich(string,ThePackage(pack)->pack_name))
          goto found;
        # Teste Nicknamen:
        {
          var object nicknamelistr = ThePackage(pack)->pack_nicknames; # Nickname-Liste durchgehen
          while (consp(nicknamelistr)) {
            if (string_gleich(string,Car(nicknamelistr)))
              goto found;
            nicknamelistr = Cdr(nicknamelistr);
          }
        }
        packlistr = Cdr(packlistr); # nächste Package
      }
      # nicht gefunden
      return NIL;
     found: # gefunden
      return pack;
    }

# UP: Sucht ein Symbol gegebenen Printnamens in einer Package.
# find_symbol(string,pack,&sym)
# > string: String
# > pack: Package
# < sym: Symbol, falls gefunden; sonst NIL
# < ergebnis: 0, wenn nicht gefunden
#             1, wenn als externes Symbol vorhanden
#             2, wenn vererbt über use-list
#             3, wenn als internes Symbol vorhanden
#         + (-4, wenn in der Shadowing-Liste vorhanden)
  local sintBWL find_symbol (object string, object pack, object* sym_);
  local sintBWL find_symbol(string,pack,sym_)
    var object string;
    var object pack;
    var object* sym_;
    {
      # Suche erst in der Shadowing-Liste von pack:
      if (shadowing_lookup(string,pack,&(*sym_))) {
        # *sym_ = in der Shadowing-Liste gefundenes Symbol
        # Suche es unter den internen Symbolen:
        if (symtab_find(*sym_,ThePackage(pack)->pack_internal_symbols))
          return 3-4; # unter den internen Symbolen gefunden
        # Suche es unter den externen Symbolen:
        if (symtab_find(*sym_,ThePackage(pack)->pack_external_symbols))
          return 1-4; # unter den externen Symbolen gefunden
        # Widerspruch zur Konsistenzregel 5.
        pushSTACK(*sym_); pushSTACK(pack);
        fehler(serious_condition,
               GETTEXT("~ inconsistent: symbol ~ is a shadowing symbol but not present")
              );
      } else {
        # Symbol noch nicht gefunden
        # Suche unter den internen Symbolen:
        if (symtab_lookup(string,ThePackage(pack)->pack_internal_symbols,&(*sym_)))
          return 3; # unter den internen Symbolen gefunden
        # Suche unter den externen Symbolen:
        if (symtab_lookup(string,ThePackage(pack)->pack_external_symbols,&(*sym_)))
          return 1; # unter den externen Symbolen gefunden
        # Suche unter den externen Packages aus der Use-List:
        if (inherited_lookup(string,pack,sym_))
          return 2; # unter den vererbten Symbolen gefunden
        # nicht gefunden
        *sym_ = NIL; return 0;
      }
    }
    # Eigentlich bräuchte man in der Shadowing-Liste erst zu suchen, nachdem
    # man die präsenten Symbole abgesucht hat, denn das Symbol in der
    # Shadowing-Liste ist ja präsent (Konsistenzregel 5).

# raise a continuable error when func(obj) was called on a locked package pack
# continue means "Ignore the lock and proceed"
# can trigger GC
local void cerror_package_locked (object func, object pack, object obj) {
  pushSTACK(NIL);              # 7 continue-format-string
  pushSTACK(S(package_error)); # 6 error type
  pushSTACK(S(Kpackage));      # 5 :PACKAGE
  pushSTACK(pack);             # 4 PACKAGE-ERROR slot PACKAGE
  pushSTACK(NIL);              # 3 error-format-string
  pushSTACK(func);             # 2
  pushSTACK(obj);              # 1
  pushSTACK(pack);             # 0
  STACK_7 = OGETTEXT("Ignore the lock and proceed"); # continue-format-string
  STACK_3 = OGETTEXT("~A(~S): ~S is locked"); # error-format-string
  funcall(L(cerror_of_type),8);
}
# check the package lock
#define check_pack_lock(func,pack,obj)                          \
  if (pack_locked_p(pack)) cerror_package_locked(func,pack,obj)
#define safe_check_pack_lock(func,pack,obj)                              \
  do { pushSTACK(pack); pushSTACK(obj); /* save */                       \
       check_pack_lock(S(use_package),STACK_1 /*pack*/,STACK_0 /*obj*/); \
       obj = popSTACK(); pack = popSTACK(); /* restore */                \
  } while(0)

# UP: Fügt ein Symbol in eine Package ein, in der noch kein Symbol desselben
# Namens existiert. Achtet nicht auf Konflikte.
# make_present(sym,pack);
# > sym: Symbol
# > pack: Package
# nur bei gesetzter BREAK_SEM_2 aufzurufen
# can trigger GC
  local void make_present (object sym, object pack);
  local void make_present(sym,pack)
    var object sym;
    var object pack;
    {
      if (!eq(pack,O(keyword_package))) {
        # Symbol in die internen Symbole einfügen:
        symtab_insert(sym,ThePackage(pack)->pack_internal_symbols);
      } else {
        # Symbol modifizieren und in die externen Symbole einfügen:
        Symbol_value(sym) = sym; # sym erhält sich selbst als Wert
        # als konstant markieren:
        TheSymbol(sym)->header_flags |= bit(constant_bit_hf);
        symtab_insert(sym,ThePackage(pack)->pack_external_symbols);
      }
    }

# UP: Interniert ein Symbol gegebenen Printnamens in einer Package.
# intern(string,pack,&sym)
# > string: String
# > pack: Package
# < sym: Symbol
# < ergebnis: 0, wenn nicht gefunden, sondern neu erzeugt
#             1, wenn als externes Symbol vorhanden
#             2, wenn vererbt über use-list
#             3, wenn als internes Symbol vorhanden
# can trigger GC
  global uintBWL intern (object string, object pack, object* sym_);
  global uintBWL intern(string,pack,sym_)
    var object string;
    var object pack;
    var object* sym_;
    {
      {
        var sintBWL ergebnis = find_symbol(string,pack,&(*sym_)); # suchen
        if (!(ergebnis==0))
          return ergebnis & 3; # gefunden -> fertig
      }
      pushSTACK(pack); # Package retten
      pushSTACK(coerce_imm_ss(string)); # string --> immutable simple-string
      check_pack_lock(S(intern),STACK_1 /*pack*/,STACK_0 /*string*/);
      var object sym = make_symbol(popSTACK()); # (make-symbol string)
      pack = popSTACK();
      # dieses neue Symbol in die Package eintragen:
      set_break_sem_2(); # Vor Unterbrechungen schützen
      Symbol_package(sym) = pack; # Home-Package eintragen
      pushSTACK(sym); # Symbol retten
      make_present(sym,pack); # und in diese internieren
      *sym_ = popSTACK();
      clr_break_sem_2(); # Unterbrechungen wieder zulassen
      return 0;
    }

# UP: Interniert ein Symbol gegebenen Printnamens in der Keyword-Package.
# intern_keyword(string)
# > string: String
# < ergebnis: Symbol, ein Keyword
# can trigger GC
  global object intern_keyword (object string);
  global object intern_keyword(string)
    var object string;
    {
      var object sym;
      intern(string,O(keyword_package),&sym);
      return sym;
    }

# UP: Importiert ein Symbol in eine Package und macht es zum Shadowing-Symbol.
# Eventuell wird dazu ein anderes in dieser Package präsentes Symbol
# desselben Namens uninterniert.
# shadowing_import(&sym,&pack);
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < sym: Symbol, EQ zum alten
# < pack: Package, EQ zur alten
# can trigger GC
  local void shadowing_import (const object* sym_, const object* pack_);
  local void shadowing_import(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      check_pack_lock(S(shadowing_import),*pack_,*sym_);
      set_break_sem_2(); # Vor Unterbrechungen schützen
      {
        var object sym = *sym_;
        var object pack = *pack_;
        # Suche ein internes oder ein externes Symbol gleichen Namens:
        var object othersym;
        var bool i_found;
        var object string = Symbol_name(sym);
        pushSTACK(string); # String retten
        if ( (i_found = symtab_lookup(string,ThePackage(pack)->pack_internal_symbols,&othersym))
             || (symtab_lookup(string,ThePackage(pack)->pack_external_symbols,&othersym))
           ) {
          # ein Symbol othersym desselben Namens war schon präsent in der Package
          if (!eq(othersym,sym)) { # war es das zu importierende Symbol selbst?
            # Nein -> muss othersym aus den internen bzw. aus den externen
            # Symbolen herausnehmen:
            symtab_delete(othersym,
                          i_found ? ThePackage(pack)->pack_internal_symbols
                                  : ThePackage(pack)->pack_external_symbols
                         );
            # Wurde dieses Symbol aus seiner Home-Package herausgenommen,
            # so muss seine Home-Package auf NIL gesetzt werden:
            if (eq(Symbol_package(othersym),pack))
              Symbol_package(othersym) = NIL;
            # Symbol sym muss in die Package pack neu aufgenommen werden.
            make_present(sym,pack);
          }
        } else {
          # Symbol sym muss in die Package pack neu aufgenommen werden.
          make_present(sym,pack);
        }
      }
      # Symbol muss in die Shadowing-Liste der Package aufgenommen werden.
      shadowing_delete(popSTACK(),*pack_); # String aus der Shadowing-Liste herausnehmen
      shadowing_insert(&(*sym_),&(*pack_)); # Symbol dafür in die Shadowing-Liste aufnehmen
      clr_break_sem_2(); # Unterbrechungen wieder zulassen
    }

# UP: Überdeckt in einer Package alle aus anderen Packages accessiblen
# Symbole gegebenen Namens durch ein in dieser Package präsentes Symbol
# desselben Namens.
# shadow(&sym,&pack)
#ifdef X3J13_161
# > sym: Symbol oder String (im STACK)
#else
# > sym: Symbol (im STACK)
#endif
# > pack: Package (im STACK)
# < pack: Package, EQ zur alten
# can trigger GC
  local void shadow (const object* sym_, const object* pack_);
  local void shadow(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      check_pack_lock(S(shadow),*pack_,*sym_);
      set_break_sem_2(); # Vor Unterbrechungen schützen
      # Suche ein internes oder ein externes Symbol gleichen Namens:
      var object string = # Nur der Name des Symbols interessiert.
        #ifdef X3J13_161
        (symbolp(*sym_) ? Symbol_name(*sym_) : coerce_imm_ss(*sym_));
        #else
        Symbol_name(*sym_);
        #endif
      var object pack = *pack_;
      pushSTACK(NIL); # Platz für othersym machen
      pushSTACK(string); # String retten
      if (!(symtab_lookup(string,ThePackage(pack)->pack_internal_symbols,&STACK_1)
            || symtab_lookup(string,ThePackage(pack)->pack_external_symbols,&STACK_1)
         ) ) {
        # nicht gefunden -> neues Symbol desselben Namens erzeugen:
        var object othersym = make_symbol(string); # neues Symbol
        STACK_1 = othersym;
        make_present(othersym,*pack_); # in die Package eintragen
        Symbol_package(STACK_1) = *pack_; # Home-Package des neuen Symbols sei pack
      }
      # Stackaufbau: othersym, string
      # In der Package ist nun das Symbol othersym desselben Namens präsent.
      shadowing_delete(popSTACK(),*pack_); # String aus der Shadowing-Liste herausnehmen
      shadowing_insert(&STACK_0,&(*pack_)); # othersym dafür in die Shadowing-Liste aufnehmen
      skipSTACK(1); # othersym vergessen
      clr_break_sem_2(); # Unterbrechungen wieder zulassen
    }

# UP: Entfernt ein Symbol aus der Menge der präsenten Symbole einer Package
# und sorgt für Konfliktauflösung für den Fall, dass es in der Shadowing-List
# dieser Package war und deswegen ein Namenskonflikt entsteht.
# unintern(&sym,&pack)
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < sym: Symbol, EQ zum alten
# < pack: Package, EQ zur alten
# < ergebnis: T wenn gefunden und gelöscht, NIL falls nichts getan.
# can trigger GC
  local object unintern (const object* sym_, const object* pack_);
  local object unintern(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      check_pack_lock(S(unintern),*pack_,*sym_);
      var object sym = *sym_;
      var object pack = *pack_;
      var object symtab;
      # sym unter den internen und den externen Symbolen suchen:
      if (symtab_find(sym,symtab=ThePackage(pack)->pack_internal_symbols)
          || symtab_find(sym,symtab=ThePackage(pack)->pack_external_symbols)
         ) {
        # Symbol sym in der Tabelle symtab gefunden
        if (shadowing_find(sym,pack)) { # in der Shadowing-Liste suchen
          # möglicher Konflikt -> Auswahlliste aufbauen:
          pushSTACK(symtab); # Symboltabelle retten
          pushSTACK(NIL); # Möglichkeitenliste anfangen
          pushSTACK(ThePackage(pack)->pack_use_list); # Use-List durchgehen
          # Stackaufbau: Symboltabelle, ML, Use-List-Rest
          while (mconsp(STACK_0)) {
            var object othersym;
            pack = Car(STACK_0); # Package aus der Use-List
            STACK_0 = Cdr(STACK_0);
            # vererbtes Symbol gleichen Namens suchen:
            if (symtab_lookup(Symbol_name(*sym_),ThePackage(pack)->pack_external_symbols,&othersym)) {
              # othersym ist ein Symbol gleichen Namens, aus pack vererbt
              var object temp;
              pushSTACK(temp=ThePackage(pack)->pack_name); # Name von pack
              pushSTACK(othersym); # Symbol
                pushSTACK(NIL);
                pushSTACK(NIL); # "Symbol ~A aus #<PACKAGE ~A> wird als Shadowing deklariert."
                pushSTACK(Symbol_name(othersym)); # Symbolname
                pushSTACK(temp); # Packagename
                STACK_2 = OLS(unint_string1);
                funcall(S(format),4); # (FORMAT NIL "..." Symbolname Packagename)
                temp = value1;
              pushSTACK(temp); # Gesamtstring
              temp = allocate_cons(); Car(temp) = STACK_1;
              STACK_1 = temp; # (list othersym)
              temp = allocate_cons(); Car(temp) = popSTACK(); Cdr(temp) = popSTACK();
              pushSTACK(temp); # (list Gesamtstring othersym)
              temp = allocate_cons(); Cdr(temp) = popSTACK(); Car(temp) = popSTACK();
              # temp = (list Packagename Gesamtstring othersym)
              # STACK stimmt wieder
              # auf die Möglichkeitenliste pushen:
              pushSTACK(temp);
              temp = allocate_cons();
              Car(temp) = popSTACK(); Cdr(temp) = STACK_1;
              STACK_1 = temp;
            }
          }
          skipSTACK(1);
          # Möglichkeitenliste fertig aufgebaut.
          # Stackaufbau: Symboltabelle, ML
          # Falls (length ML) >= 2, liegt ein Konflikt vor:
          if (mconsp(STACK_0) && mconsp(Cdr(STACK_0))) {
            # Continuable Error auslösen:
            pushSTACK(OLS(unint_string2)); # "Sie dürfen auswählen..."
            pushSTACK(S(package_error)); # PACKAGE-ERROR
            pushSTACK(S(Kpackage)); # :PACKAGE
            pushSTACK(*pack_); # Package
            pushSTACK(OLS(unint_string3)); # "Durch Uninternieren von ~S aus ~S ..."
            pushSTACK(*sym_); # Symbol
            pushSTACK(*pack_); # Package
            funcall(L(cerror_of_type),7); # (SYS::CERROR-OF-TYPE "..." 'PACKAGE-ERROR :PACKAGE Package "..." Symbol Package)
            STACK_0 = query_user(STACK_0); # Auswahl erfragen
          } else {
            STACK_0 = NIL;
          }
          # STACK_0 ist die Auswahl (NIL falls kein Konflikt entsteht)
          # Stackaufbau: Symboltabelle, Auswahl
          set_break_sem_3();
          {
            var object sym = *sym_;
            var object pack = *pack_;
            # Symbol aus der Symboltabelle entfernen:
            symtab_delete(sym,STACK_1);
            # Falls es aus seiner Home-Package entfernt wurde,
            # setze die Home-Package auf NIL:
            if (eq(Symbol_package(sym),pack))
              Symbol_package(sym) = NIL;
            # Symbol aus Shadowing-Liste streichen:
            shadowing_delete(Symbol_name(sym),pack);
          }
          {
            var object auswahl = popSTACK(); # Auswahl
            if (!nullp(auswahl)) {
              # im Konfliktfalle: angewähltes Symbol importieren:
              pushSTACK(Car(Cdr(Cdr(auswahl))));
              shadowing_import(&STACK_0,&(*pack_));
              skipSTACK(1);
            }
          }
          skipSTACK(1); # Symboltabelle vergessen
          clr_break_sem_3();
          return T; # Das war's
        } else {
          # kein Konflikt
          set_break_sem_2();
          symtab_delete(sym,symtab); # Symbol löschen
          if (eq(Symbol_package(sym),pack))
            Symbol_package(sym) = NIL; # evtl. Home-Package auf NIL setzen
          clr_break_sem_2();
          return T;
        }
      } else {
        # nicht gefunden
        return NIL;
      }
    }

# UP: Importiert ein Symbol in eine Package und sorgt für Konfliktauflösung
# für den Fall, dass ein Namenskonflikt entweder mit einem aus einer anderen
# Package vererbten Symbol oder mit einem bereits in dieser Package präsenten
# Symbol desselben Namens entsteht.
# import(&sym,&pack);
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < pack: Package, EQ zur alten
# can trigger GC
  global void import (const object* sym_, const object* pack_);
  global void import(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      var object sym = *sym_;
      var object pack = *pack_;
      var object string = Symbol_name(sym);
      var object othersym;
      var object othersymtab;
      # Symbol gleichen Namens unter den internen und den externen Symbolen suchen:
      if (symtab_lookup(string,othersymtab=ThePackage(pack)->pack_internal_symbols,&othersym)
          || symtab_lookup(string,othersymtab=ThePackage(pack)->pack_external_symbols,&othersym)
         ) {
        # othersym = Symbol desselben Namens, gefunden in othersymtab
        if (eq(othersym,sym))
          # dasselbe Symbol -> nichts tun
          return;
        # nicht dasselbe Symbol war präsent -> muss othersym rauswerfen und
        # dafür das gegebene Symbol sym reinsetzen.
        # Zuvor feststellen, ob zusätzlich noch vererbte Symbole da sind,
        # und dann Continuable Error melden.
        pushSTACK(string);
        pushSTACK(othersym);
        pushSTACK(othersymtab);
        # erst Inherited-Flag berechnen:
        var bool inheritedp = inherited_lookup(string,pack,NULL);
        # Stackaufbau: Symbol-Name, othersym, othersymtab.
        # Continuable Error melden:
          pushSTACK(OLS(import_string1)); # "Sie dürfen über das weitere Vorgehen entscheiden."
          pushSTACK(S(package_error)); # PACKAGE-ERROR
          pushSTACK(S(Kpackage)); # :PACKAGE
          pushSTACK(*pack_); # Package
          pushSTACK(!inheritedp # bei inheritedp=false die kurze Meldung
                    ? OLS(import_string2) # "Durch Importieren von ~S in ~S entsteht ein Namenskonflikt mit ~S."
                    : OLS(import_string3) # "Durch Importieren von ~S in ~S ... Namenskonflikt mit ~S und weiteren Symbolen."
                   );
          pushSTACK(*sym_); # Symbol
          pushSTACK(*pack_); # Package
          pushSTACK(STACK_8); # othersym
          funcall(L(cerror_of_type),8); # (SYS::CERROR-OF-TYPE String1 'PACKAGE-ERROR :PACKAGE pack String2/3 sym pack othersym)
        # Antwort vom Benutzer erfragen:
        {
          var object ml = # Möglichkeitenliste (("I" ... T) ("N" ... NIL))
            (!inheritedp ? OL(import_list1) : OL(import_list2));
          var object antwort = query_user(ml);
          if (nullp(Car(Cdr(Cdr(antwort))))) { # NIL-Möglichkeit angewählt?
            skipSTACK(3); return; # ja -> nicht importieren, fertig
          }
        }
        # Importieren:
        set_break_sem_2();
        pack = *pack_;
        # othersym aus pack entfernen:
        {
          var object othersym = STACK_1;
          symtab_delete(othersym,STACK_0); # othersym aus othersymtab entfernen
          if (eq(Symbol_package(othersym),pack))
            Symbol_package(othersym) = NIL; # evtl. Home-Package := NIL
        }
        # sym in pack einfügen:
        make_present(*sym_,pack);
        # Symbole gleichen Namens aus der Shadowing-List von pack entfernen:
        shadowing_delete(STACK_2,*pack_);
        # Falls inherited-Flag, sym in pack zum Shadowing-Symbol machen:
        if (inheritedp)
          shadowing_insert(&(*sym_),&(*pack_));
        clr_break_sem_2();
        skipSTACK(3); return;
      } else {
        # Kein Symbol desselben Namens war präsent.
        # Suche ein Symbol desselben Namens, das vererbt ist (es gibt
        # nach den Konsistenzregeln 6 und 5 höchstens ein solches):
        var object otherusedsym;
        if (!inherited_lookup(string,pack,&otherusedsym)
            || eq(otherusedsym,sym)) {
          # sym einfach in pack einfügen:
          set_break_sem_2();
          make_present(sym,pack);
          clr_break_sem_2();
        } else {
          # nein -> Continuable Error melden und Benutzer fragen:
          pushSTACK(NIL); # "Sie dürfen über das weitere Vorgehen entscheiden."
          pushSTACK(S(package_error)); # PACKAGE-ERROR
          pushSTACK(S(Kpackage)); # :PACKAGE
          pushSTACK(pack); # Package
          pushSTACK(NIL); # "Durch Importieren von ~S in ~S entsteht ein Namenskonflikt mit ~S."
          pushSTACK(sym); # Symbol
          pushSTACK(pack); # Package
          pushSTACK(otherusedsym); # otherusedsym
          STACK_7 = OLS(import_string1);
          STACK_3 = OLS(import_string2);
          funcall(L(cerror_of_type),8); # (SYS::CERROR-OF-TYPE String1 'PACKAGE-ERROR :PACKAGE pack String2 sym pack otherusedsym)
          {
            var object antwort = query_user(OL(import_list3));
            if (nullp(Car(Cdr(Cdr(antwort))))) # NIL-Möglichkeit angewählt?
              return; # ja -> nicht importieren, fertig
          }
          # Importieren:
          set_break_sem_2();
          # sym in pack einfügen:
          make_present(*sym_,*pack_);
          # sym in pack zum Shadowing-Symbol machen:
          shadowing_insert(&(*sym_),&(*pack_));
          clr_break_sem_2();
        }
      }
    }

# UP: Setzt ein Symbol vom externen auf den internen Status in einer Package
# zurück.
# unexport(&sym,&pack);
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < pack: Package, EQ zur alten
# can trigger GC
  local void unexport (const object* sym_, const object* pack_);
  local void unexport(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      check_pack_lock(S(unexport),*pack_,*sym_);
      var object sym = *sym_;
      var object pack = *pack_;
      var object symtab;
      if (symtab_find(sym,symtab=ThePackage(pack)->pack_external_symbols)) {
        # sym ist in pack extern
        if (eq(pack,O(keyword_package))) { # auf Keyword-Package testen
          pushSTACK(pack); # Wert für Slot PACKAGE von PACKAGE-ERROR
          pushSTACK(pack);
          fehler(package_error,
                 GETTEXT("UNEXPORT in ~ is illegal")
                );
        }
        set_break_sem_2();
        symtab_delete(sym,symtab); # sym aus den externen Symbolen entfernen
        symtab_insert(sym,ThePackage(pack)->pack_internal_symbols); # dafür in die internen Symbole einfügen
        clr_break_sem_2();
      } else {
        # Suchen, ob das Symbol überhaupt accessible ist.
        # Suche unter den internen Symbolen:
        if (symtab_find(sym,ThePackage(pack)->pack_internal_symbols))
          return;
        # Suche unter den externen Symbolen der Packages aus der Use-List:
        if (inherited_find(sym,pack))
          return;
        # nicht gefunden unter den accessiblen Symbolen
        pushSTACK(pack); # Wert für Slot PACKAGE von PACKAGE-ERROR
        pushSTACK(pack); pushSTACK(sym);
        fehler(package_error,
               GETTEXT("UNEXPORT works only on accessible symbols, not on ~ in ~")
              );
      }
    }

# UP: Setzt ein präsentes Symbol auf externen Status.
# make_external(sym,pack);
# > sym: Symbol
# > pack: Package, in der das Symbol präsent ist
# can trigger GC
  local void make_external (object sym, object pack);
  local void make_external(sym,pack)
    var object sym;
    var object pack;
    {
      if (symtab_find(sym,ThePackage(pack)->pack_external_symbols))
        return; # Symbol bereits extern -> nichts zu tun
      set_break_sem_2();
      symtab_delete(sym,ThePackage(pack)->pack_internal_symbols); # sym aus den internen Symbolen entfernen
      symtab_insert(sym,ThePackage(pack)->pack_external_symbols); # dafür in die externen Symbole einfügen
      clr_break_sem_2();
    }

# UP: Exportiert ein Symbol aus einer Package
# export(&sym,&pack);
# > sym: Symbol (im STACK)
# > pack: Package (im STACK)
# < sym: Symbol, EQ zum alten
# < pack: Package, EQ zur alten
# can trigger GC
  global void export (const object* sym_, const object* pack_);
  global void export(sym_,pack_)
    var const object* sym_;
    var const object* pack_;
    {
      check_pack_lock(S(export),*pack_,*sym_);
      var object sym = *sym_;
      var object pack = *pack_;
      # sym unter den externen Symbolen von pack suchen:
      if (symtab_find(sym,ThePackage(pack)->pack_external_symbols))
        return; # gefunden -> fertig
      var bool import_it = false;
      # import_it = Flag, ob Symbol erst noch importiert werden muss.
      # sym unter den internen Symbolen von pack suchen:
      if (!(symtab_find(sym,ThePackage(pack)->pack_internal_symbols))) {
        # Symbol sym ist nicht präsent in Package pack
        import_it = true;
        # Suche, ob es wenigstens accessible ist:
        if (inherited_find(sym,pack))
          goto found;
        # Symbol sym ist nicht einmal accessible in der Package pack
        # Continuable Error melden:
          pushSTACK(NIL); # "Sie dürfen über das weitere Vorgehen entscheiden."
          pushSTACK(S(package_error)); # PACKAGE-ERROR
          pushSTACK(S(Kpackage)); # :PACKAGE
          pushSTACK(pack); # Package
          pushSTACK(NIL); # "Symbol ~S müsste erst in ~S importiert werden, bevor es exportiert werden kann."
          pushSTACK(sym); # Symbol
          pushSTACK(pack); # Package
          STACK_6 = OLS(export_string1);
          STACK_2 = OLS(export_string2);
          funcall(L(cerror_of_type),7); # (SYS::CERROR-OF-TYPE "Sie dürfen aussuchen, ..." 'PACKAGE-ERROR :PACKAGE Package "..." Symbol Package)
        # beim Benutzer nachfragen:
        {
          var object antwort = query_user(OL(export_list1));
          if (nullp(Car(Cdr(Cdr(antwort))))) # NIL-Möglichkeit angewählt?
            return; # ja -> nicht exportieren, fertig
        }
       found: ;
      }
      # Nun auf Namenskonflikte testen:
      pushSTACK(NIL); # Conflict-Resolver:=NIL
      # Stackaufbau: Conflict-Resolver (eine Liste von Paaren (sym . pack),
      #              auf die shadowing_import angewandt werden muss).
      pushSTACK(ThePackage(*pack_)->pack_used_by_list); # Used-By-List wird abgesucht
      while (mconsp(STACK_0)) {
        var object usingpack = Car(STACK_0); # USEnde Package
        STACK_0 = Cdr(STACK_0);
        var object othersym;
        if (find_symbol(Symbol_name(*sym_),usingpack,&othersym) > 0)
          # othersym ist ein Symbol desselben Namens in usingpack
          if (!eq(othersym,*sym_)) {
            # es ist nicht sym selbst -> es liegt ein Konflikt vor
            pushSTACK(othersym); pushSTACK(usingpack);
            # Stackaufbau: Conflict-Resolver, Used-by-list-Rest,
            #              anderes Symbol, USEnde Package.
            # Continuable Error melden:
              pushSTACK(NIL); # "Sie dürfen aussuchen, welches Symbol Vorrang hat."
              pushSTACK(S(package_error)); # PACKAGE-ERROR
              pushSTACK(S(Kpackage)); # :PACKAGE
              pushSTACK(*pack_); # Package
              pushSTACK(NIL); # "Durch Exportieren von ~S aus ~S ... Namenskonflikt mit ~S in ~S."
              pushSTACK(*sym_); # Symbol
              pushSTACK(*pack_); # Package
              pushSTACK(othersym); # anderes Symbol
              pushSTACK(usingpack); # USEnde Package
              STACK_8 = OLS(export_string3);
              STACK_4 = OLS(export_string4);
              funcall(L(cerror_of_type),9); # (CERROR "..." 'PACKAGE-ERROR :PACKAGE pack "..." sym pack othersym usingpack)
            # Einleitung ausgeben:
            {
              var object stream = var_stream(S(query_io),strmflags_rd_ch_B|strmflags_wr_ch_B); # Stream *QUERY-IO*
              pushSTACK(stream);
              terpri(&STACK_0); # Neue Zeile
              pushSTACK(OLS(export_string5)); # "Welches Symbol soll in ~S Vorrang haben?"
              pushSTACK(STACK_2); # usingpack
              funcall(S(format),3); # (FORMAT stream "..." usingpack)
            }
            # Möglichkeitenliste konstruieren:
            {
              var object temp;
               pushSTACK(O(export_string6)); # "1"
                pushSTACK(OLS(export_string8)); # "Das zu exportierende Symbol "
                 pushSTACK(*sym_); # Symbol
                 funcall(L(prin1_to_string),1); # (prin1-to-string Symbol)
                pushSTACK(value1);
                temp = string_concat(2); # (string-concat "Das zu exportierende Symbol " (prin1-to-string Symbol))
               pushSTACK(temp);
               pushSTACK(T);
               temp = listof(3); # (list "1" (string-concat ...) 'T)
              pushSTACK(temp);
               pushSTACK(O(export_string7)); # "2"
                pushSTACK(OLS(export_string9)); # "Das alte Symbol "
                 pushSTACK(STACK_4); # anderes Symbol
                 funcall(L(prin1_to_string),1); # (prin1-to-string anderesSymbol)
                pushSTACK(value1);
                temp = string_concat(2); # (string-concat "Das alte Symbol " (prin1-to-string anderesSymbol))
               pushSTACK(temp);
               pushSTACK(NIL);
               temp = listof(3); # (list "2" (string-concat ...) 'NIL)
              pushSTACK(temp);
              temp = listof(2); # (list (list "1" ... 'T) (list "2" ... 'NIL))
            # Beim Benutzer nachfragen:
              {
                var object antwort = query_user(temp);
                var object solvingsym =
                    (!nullp(Car(Cdr(Cdr(antwort)))) # NIL-Möglichkeit angewählt?
                     ? *sym_ # nein -> sym
                     : STACK_1 # ja -> othersym
                    );
                pushSTACK(solvingsym); # ausgewähltes Symbol
              }
            # Conflict-Resolver um (solvingsym . usingpack) erweitern:
              temp = allocate_cons();
              Car(temp) = popSTACK(); # solvingsym
              Cdr(temp) = popSTACK(); # usingpack
              # temp = (cons solvingsym usingpack)
              # vor Conflict-Resolver davorconsen:
              STACK_0 = temp;
              temp = allocate_cons();
              Car(temp) = popSTACK(); # (solvingsym . usingpack)
              Cdr(temp) = STACK_1;
              STACK_1 = temp;
            }
            # Stackaufbau: Conflict-Resolver, Used-by-list-Rest.
          }
      }
      skipSTACK(1);
      # Stackaufbau: Conflict-Resolver.
      # Nun evtl. Symbol sym importieren:
      if (import_it) {
        # sym in pack importieren:
        import(&(*sym_),&(*pack_));
        # Dieses Importieren kann durch einen CERROR abgebrochen werden.
        # Ein Abbruch an dieser Stelle ist ungefährlich, denn bis jetzt
        # ist das Symbol nur intern in der Package (außer falls es sich
        # um das KEYWORD-Package handelt, das nicht geUSEd werden kann).
      }
      set_break_sem_3(); # gegen Unterbrechungen schützen
      # Nun die Konflikte auflösen:
      while (mconsp(STACK_0)) {
        var object cons_sym_pack = Car(STACK_0);
        STACK_0 = Cdr(STACK_0);
        pushSTACK(Car(cons_sym_pack)); # solvingsym
        pushSTACK(Cdr(cons_sym_pack)); # usingpack
        shadowing_import(&STACK_1,&STACK_0); # importieren und shadowen
        skipSTACK(2);
      }
      skipSTACK(1);
      make_external(*sym_,*pack_); # sym in pack extern machen
      clr_break_sem_3(); # Unterbrechungen wieder freigeben
    }

# UP: Wendet eine Funktion auf alle Symbole einer Symboltabelle an.
# (Diese Funktion darf im Extremfall das Symbol mittels symtab_delete
# aus der Tabelle herausnehmen.)
# map_symtab(fun,symtab);
# > fun: Funktion mit einem Argument
# > symtab: Symboltabelle
# can trigger GC
  local void map_symtab (object fun, object symtab);
  local void map_symtab(fun,symtab)
    var object fun;
    var object symtab;
    {
      pushSTACK(fun); # Funktion
      pushSTACK(Symtab_table(symtab)); # Tabellenvektor
      var uintL size = posfixnum_to_L(Symtab_size(symtab)); # Anzahl der Einträge
      var object* offset = 0; # offset = sizeof(object)*index
      var uintC count;
      dotimespC(count,size, {
        var object entry = # Eintrag mit Nummer index in table
            *(object*)(pointerplus(&TheSvector(STACK_0)->data[0],(aint)offset));
        if (atomp(entry)) {
          if (!nullp(entry)) {
            # entry ist ein Symbol /= NIL
            pushSTACK(entry); funcall(STACK_2,1); # Funktion anwenden
          }
        } else {
          # nichtleere Symbolliste abarbeiten
          pushSTACK(entry);
          do {
            var object listr = STACK_0;
            STACK_0 = Cdr(listr);
            pushSTACK(Car(listr)); funcall(STACK_3,1); # Funktion auf Symbol anwenden
          } until (matomp(STACK_0));
          skipSTACK(1);
        }
        offset++;
      });
      skipSTACK(2);
    }

# UP: Wendet eine C-Funktion auf alle Symbole einer Symboltabelle an.
# (Diese Funktion darf im Extremfall das Symbol mittels symtab_delete
# aus der Tabelle herausnehmen.)
# map_symtab_c(fun,data,symtab);
# > fun: Funktion mit zwei Argumenten, darf GC auslösen
# > data: erstes Argument für die Funktion
# > symtab: Symboltabelle
# can trigger GC
  typedef void one_sym_function (void* data, object sym);
  local void map_symtab_c (one_sym_function* fun, void* data, object symtab);
  local void map_symtab_c(fun,data,symtab)
    var one_sym_function* fun;
    var void* data;
    var object symtab;
    {
      pushSTACK(Symtab_table(symtab)); # Tabellenvektor
      var uintL size = posfixnum_to_L(Symtab_size(symtab)); # Anzahl der Einträge
      var object* offset = 0; # offset = sizeof(object)*index
      var uintC count;
      dotimespC(count,size, {
        var object entry = # Eintrag mit Nummer index in table
            *(object*)(pointerplus(&TheSvector(STACK_0)->data[0],(aint)offset));
        if (atomp(entry)) {
          if (!nullp(entry)) {
            # entry ist ein Symbol /= NIL
            (*fun)(data,entry); # Funktion anwenden
          }
        } else {
          # nichtleere Symbolliste abarbeiten
          pushSTACK(entry);
          do {
            var object listr = STACK_0;
            STACK_0 = Cdr(listr);
            (*fun)(data,Car(listr)); # Funktion auf Symbol anwenden
          } until (matomp(STACK_0));
          skipSTACK(1);
        }
        offset++;
      });
      skipSTACK(1);
    }

# UP: Bewirkt, dass alle externen Symbole einer gegebenen Liste von Packages
# implizit accessible in einer gegebenen Package werden.
# use_package(packlist,pack);
# > packlist: Liste von Packages, die zu USEn sind
# > pack: Package
# Die Liste packlist wird dabei zerstört!
# can trigger GC
  local void use_package (object packlist, object pack);
  local one_sym_function use_package_aux;
  local void use_package(packlist,pack)
    var object packlist;
    var object pack;
    {
      safe_check_pack_lock(S(use_package),pack,packlist);
      # packlist := (delete-duplicates packlist :test #'eq) :
      {
        var object packlist1 = packlist;
        while (consp(packlist1)) {
          var object to_delete = Car(packlist1);
          # Entferne to_delete destruktiv aus (cdr packlist1) :
          var object packlist2 = packlist1; # läuft ab packlist1
          var object packlist3; # stets = (cdr packlist2)
          while (consp(packlist3=Cdr(packlist2))) {
            if (eq(Car(packlist3),to_delete)) {
              # streiche (car packlist3) destruktiv aus der Liste:
              Cdr(packlist2) = Cdr(packlist3);
            } else {
              # weiterrücken:
              packlist2 = packlist3;
            }
          }
          packlist1 = Cdr(packlist1);
        }
      }
      # Entferne aus packlist alle die Packages, die gleich pack sind
      # oder bereits in der Use-List von pack vorkommen:
      {
        var object* packlistr_ = &packlist;
        var object packlistr = *packlistr_;
        # packlistr läuft durch packlist, packlistr = *packlistr_
        while (consp(packlistr)) {
          # Teste, ob (car packlistr) gestrichen werden muss:
          var object pack_to_test = Car(packlistr);
          if (eq(pack_to_test,pack))
            goto delete_pack_to_test;
          {
            var object usedpacklistr = ThePackage(pack)->pack_use_list;
            while (consp(usedpacklistr)) {
              if (eq(pack_to_test,Car(usedpacklistr)))
                goto delete_pack_to_test;
              usedpacklistr = Cdr(usedpacklistr);
            }
          }
          if (true) {
            # nichts streichen, weiterrücken:
            packlistr_ = &Cdr(packlistr); packlistr = *packlistr_;
          } else {
            # streiche (car packlistr) :
           delete_pack_to_test:
            packlistr = *packlistr_ = Cdr(packlistr);
          }
        }
      }
      # Konfliktliste aufbauen.
      # Dabei ist ein Konflikt eine mindestens zweielementige Liste
      # von Symbolen gleichen Printnamens, zusammen mit der Package,
      # aus der dieses Symbol genommen wird:
      # ((pack1 . sym1) ...) bedeutet, dass bei Ausführung des USE-PACKAGE
      # die Symbole sym1,... (aus pack1 etc.) sich um die Sichtbarkeit in
      # Package pack streiten würden.
      # Die Konfliktliste ist die Liste aller auftretenden Konflikte.
      {
        pushSTACK(pack); # Package pack retten
        pushSTACK(packlist); # Liste zu USEnder Packages retten
        pushSTACK(NIL); # (bisher leere) Konfliktliste
        # Stackaufbau: pack, packlist, conflicts.
        # Packageliste durchgehen:
        {
          pushSTACK(packlist);
          while (mconsp(STACK_0)) {
            var object pack_to_use = Car(STACK_0);
            STACK_0 = Cdr(STACK_0);
            # use_package_aux auf alle externen Symbole von pack_to_use anwenden:
            map_symtab_c(&use_package_aux,&STACK_1,ThePackage(pack_to_use)->pack_external_symbols);
          }
          skipSTACK(1);
        }
        # Konfliktliste umbauen: Jeder Konflikt ((pack1 . sym1) ...) wird
        # umgeformt zu (("1" packname1 . sym1) ...).
        {
          pushSTACK(STACK_0); # Konfliktliste durchgehen
          while (mconsp(STACK_0)) {
            var object conflict = Car(STACK_0);
            STACK_0 = Cdr(STACK_0);
            pushSTACK(conflict); # Konflikt durchgehen
            {
              var object counter = Fixnum_0; # Zähler := 0
              while (mconsp(STACK_0)) {
                counter = fixnum_inc(counter,1); # Zähler um 1 erhöhen
                pushSTACK(counter); funcall(L(prin1_to_string),1); # (prin1-to-string Zähler)
                pushSTACK(value1); # Zählerstring retten
                var object new_cons = allocate_cons(); # neues Cons
                Car(new_cons) = popSTACK(); # Zählerstring als CAR
                var object old_cons = Car(STACK_0); # Cons der Form (pack . sym)
                Car(old_cons) = ThePackage(Car(old_cons))->pack_name; # pack durch seinen Namen ersetzen
                Cdr(new_cons) = old_cons; Car(STACK_0) = new_cons; # Zählerstring-Cons einfügen
                STACK_0 = Cdr(STACK_0);
              }
            }
            skipSTACK(1);
          }
          skipSTACK(1);
        }
        # Konflikt-Liste fertig.
        pushSTACK(NIL); # Conflict-Resolver := NIL
        # Stackaufbau: pack, packlist, conflicts, conflict-resolver.
        # Konflikte durch Benutzerfragen behandeln:
        if (!nullp(STACK_1)) { # nur bei conflicts/=NIL nötig
          # Continuable Error melden:
            pushSTACK(OLS(usepack_string1)); # "Sie dürfen bei jedem Konflikt ..."
            pushSTACK(S(package_error)); # PACKAGE-ERROR
            pushSTACK(S(Kpackage)); # :PACKAGE
            pushSTACK(STACK_6); # pack
            pushSTACK(OLS(usepack_string2)); # "~S Namenskonflikte bei USE-PACKAGE von ~S in die Package ~S."
            pushSTACK(fixnum(llength(STACK_6))); # (length conflicts)
            pushSTACK(STACK_8); # packlist
            pushSTACK(STACK_(10)); # pack
            funcall(L(cerror_of_type),8); # (SYS::CERROR-OF-TYPE "..." 'PACKAGE-ERROR :PACKAGE pack "..." (length conflicts) usedpacks pack)
          {
            pushSTACK(STACK_1); # conflicts durchgehen
            while (mconsp(STACK_0)) {
              pushSTACK(Car(STACK_0)); # conflict
              {
                var object stream = var_stream(S(query_io),strmflags_rd_ch_B|strmflags_wr_ch_B); # Stream *QUERY-IO*
                pushSTACK(stream);
                terpri(&STACK_0); # Neue Zeile
                pushSTACK(OLS(usepack_string3)); # "Welches Symbol mit dem Namen ~S soll in ~S Vorrang haben?"
                # (cdr (cdr (car conflict))) = (cdr (cdr '("1" packname1 . sym1))) = sym1
                pushSTACK(Symbol_name(Cdr(Cdr(Car(STACK_(0+2)))))); # Name davon ausgeben
                pushSTACK(STACK_(5+3)); # pack ausgeben
                funcall(S(format),4); # (FORMAT stream "..." sym1 pack)
              }
              # Beim Benutzer nachfragen,
              # mit conflict als Möglichkeitenliste:
              {
                var object antwort = query_user(popSTACK());
                # Davon das Symbol nehmen und in den conflict-resolver stecken:
                pushSTACK(Cdr(Cdr(antwort))); # sym
              }
              {
                var object new_cons = allocate_cons();
                Car(new_cons) = popSTACK(); # sym
                Cdr(new_cons) = STACK_1; # conflict-resolver
                STACK_1 = new_cons; # conflict-resolver := (cons sym conflict-resolver)
              }
              STACK_0 = Cdr(STACK_0); # restliche Konfliktliste verkürzen
            }
            skipSTACK(1);
          }
        }
        # Stackaufbau: pack, packlist, conflicts, conflict-resolver.
        # Konflikte auflösen:
        {
          set_break_sem_3();
          # conflict-resolver durchgehen:
          while (mconsp(STACK_0)) {
            pushSTACK(Car(STACK_0)); # Symbol aus conflict-resolver
            shadowing_import(&STACK_0,&STACK_4); # in pack zum Shadowing-Symbol machen
            skipSTACK(1);
            STACK_0 = Cdr(STACK_0);
          }
          skipSTACK(2); # conflicts und conflict-resolver vergessen
          # Stackaufbau: pack, packlist.
          # packlist durchgehen:
          while (mconsp(STACK_0)) {
            pushSTACK(Car(STACK_0)); # pack_to_use
            # pack_to_use auf die Use-List von pack setzen:
            # (push pack_to_use (package-use-list pack))
            {
              var object new_cons = allocate_cons();
              var object pack = STACK_2;
              Car(new_cons) = STACK_0; # pack_to_use
              Cdr(new_cons) = ThePackage(pack)->pack_use_list;
              ThePackage(pack)->pack_use_list = new_cons;
            }
            # pack auf die Used-By-List von pack_to_use setzen:
            # (push pack (package-used-by-list pack_to_use))
            {
              var object new_cons = allocate_cons();
              var object pack_to_use = popSTACK();
              Car(new_cons) = STACK_1; # pack
              Cdr(new_cons) = ThePackage(pack_to_use)->pack_used_by_list;
              ThePackage(pack_to_use)->pack_used_by_list = new_cons;
            }
            STACK_0 = Cdr(STACK_0);
          }
          skipSTACK(2); # pack und packlist vergessen
          clr_break_sem_3();
        }
      }
    }

# Hilfsfunktion für use_package:
# Teste das Argument (ein externes Symbol aus einer der Packages aus
# packlist), ob es einen Konflikt erzeugt. Wenn ja, erweitere conflicts.
# can trigger GC
local void use_package_aux (void* data, object sym);
local void use_package_aux(data,sym)
  var void* data;
  var object sym;
  {
    var object* localptr = (object*)data;
    # Pointer auf lokale Variablen von use_package:
    #   *(localptr STACKop 2) = pack,
    #   *(localptr STACKop 1) = packlist,
    #   *(localptr STACKop 0) = conflicts.
    var object string = Symbol_name(sym); # Printname des übergebenen Symbols
    # Gibt es einen Konflikt zwischen den Symbolen mit Printname = string ?
    # Bisherige Konfliktliste (((pack1 . sym1) ...) ...) durchgehen:
    {
      var object conflictsr = *(localptr STACKop 0);
      while (consp(conflictsr)) {
        # Konflikt schon behandelt?
        # (car conflictsr) = nächster Konflikt,
        # (car (car conflictsr)) = dessen erstes Cons,
        # (cdr (car (car conflictsr))) = darin das Symbol,
        # ist dessen Printname = string ?
        if (string_gleich(Symbol_name(Cdr(Car(Car(conflictsr)))),string))
          goto ok;
        conflictsr = Cdr(conflictsr);
      }
    }
    pushSTACK(string); # string retten
    # neuen Konflikt aufbauen:
    pushSTACK(NIL); # neuer Konflikt (noch leer)
    # Testen, ob ein gleichnamiges Symbol bereits in pack accessible ist:
    {
      var object othersym;
      var sintBWL code = find_symbol(string,*(localptr STACKop 2),&othersym);
      if (code < 0) {
        # Gleichnamiges Symbol in der Shadowing-Liste verhindert Konflikt.
        skipSTACK(2); goto ok;
      }
      if (code > 0) {
        # accessible, aber nicht shadowing -> Konflikt um (pack . othersym) erweitern:
        pushSTACK(othersym);
        {
          var object temp = allocate_cons();
          Cdr(temp) = popSTACK(); # othersym
          Car(temp) = *(localptr STACKop 2); # pack
          pushSTACK(temp); # (pack . othersym)
        }
        {
          var object new_cons = allocate_cons();
          Car(new_cons) = popSTACK(); Cdr(new_cons) = STACK_0;
          STACK_0 = new_cons;
        }
      }
    }
    # Testen, in welchen Packages aus packlist ein gleichnamiges Symbol
    # extern ist:
    {
      var object packlistr = *(localptr STACKop 1); # packlist durchgehen
      while (consp(packlistr)) {
        var object pack_to_use = Car(packlistr);
        packlistr = Cdr(packlistr);
        var object othersym;
        if (symtab_lookup(STACK_1,ThePackage(pack_to_use)->pack_external_symbols,&othersym)) {
          # othersym hat den Printnamen = string und ist extern in pack_to_use.
          # (pack_to_use . othersym) auf conflict pushen:
          pushSTACK(packlistr); # packlistr retten
          pushSTACK(pack_to_use);
          pushSTACK(othersym);
          {
            var object new_cons = allocate_cons();
            Cdr(new_cons) = popSTACK(); Car(new_cons) = popSTACK();
            pushSTACK(new_cons); # (cons pack_to_use othersym)
          }
          {
            var object new_cons = allocate_cons();
            Car(new_cons) = popSTACK();
            packlistr = popSTACK();
            Cdr(new_cons) = STACK_0;
            STACK_0 = new_cons; # conflict := (cons (cons pack_to_use othersym) conflict)
          }
        }
      }
    }
    {
      var object conflict = popSTACK(); # der fertige Konflikt
      # conflict := (delete-duplicates conflict :key #'cdr :test #'eq):
      {
        var object conflict1 = conflict;
        while (consp(conflict1)) {
          var object to_delete = Cdr(Car(conflict1));
          # Entferne alle Elemente mit CDR=to_delete
          # destruktiv aus (cdr conflict1) :
          var object conflict2 = conflict1; # läuft ab conflict1
          var object conflict3; # stets = (cdr conflict2)
          while (consp(conflict3=Cdr(conflict2))) {
            if (eq(Cdr(Car(conflict3)),to_delete)) {
              # streiche (car conflict3) destruktiv aus der Liste:
              Cdr(conflict2) = Cdr(conflict3);
            } else {
              # weiterrücken:
              conflict2 = conflict3;
            }
          }
          conflict1 = Cdr(conflict1);
        }
      }
      # Falls conflict eine Länge >=2 hat, wird es zu conflicts geconst:
      if (consp(conflict) && mconsp(Cdr(conflict))) {
        pushSTACK(conflict);
        var object new_cons = allocate_cons();
        Car(new_cons) = popSTACK(); # conflict
        Cdr(new_cons) = *(localptr STACKop 0); # conflicts
        *(localptr STACKop 0) = new_cons; # conflicts := (cons conflict conflicts)
      }
    }
    skipSTACK(1); # string vergessen
    ok: ;
  }

# UP: Bewirkt, dass eine gegebene Package nicht mehr von einer (anderen)
# gegebenen Package geUSEt wird.
# unuse_1package(pack,qpack);
# > pack: Package
# > qpack: Package
# Entfernt qpack von der Use-List von pack
# und pack von der Used-By-List von qpack.
  local void unuse_1package (object pack, object qpack);
  local void unuse_1package(pack,qpack)
    var object pack;
    var object qpack;
    {
      safe_check_pack_lock(S(use_package),pack,qpack);
      set_break_sem_2();
      # qpack aus der Use-List von pack entfernen:
      ThePackage(pack)->pack_use_list =
        deleteq(ThePackage(pack)->pack_use_list,qpack);
      # pack aus der Used-By-List von qpack entfernen:
      ThePackage(qpack)->pack_used_by_list =
        deleteq(ThePackage(qpack)->pack_used_by_list,pack);
      clr_break_sem_2();
    }

# UP: Bewirkt, dass eine Liste gegebener Packages nicht mehr von einer
# gegebenen Package geUSEt wird.
# unuse_package(packlist,pack);
# > packlist: Liste von Packages
# > pack: Package
# Entfernt alle Packages aus packlist von der Use-List von pack
# und pack von den Used-By-Listen aller Packages aus packlist.
  local void unuse_package (object packlist, object pack);
  local void unuse_package(packlist,pack)
    var object packlist;
    var object pack;
    {
      set_break_sem_3();
      # packlist durchgehen:
      while (consp(packlist)) {
        unuse_1package(pack,Car(packlist));
        packlist = Cdr(packlist);
      }
      clr_break_sem_3();
    }

# UP: liefert die aktuelle Package
# get_current_package()
# < ergebnis: aktuelle Package
  global object get_current_package (void);
  global object get_current_package()
    {
      var object pack = Symbol_value(S(packagestern)); # Wert von *PACKAGE*
      if (packagep(pack) && !pack_deletedp(pack)) {
        return pack;
      } else {
        var object newpack =
          Symbol_value(S(packagestern)) = O(default_package); # *PACKAGE* zurücksetzen
        pushSTACK(pack); # TYPE-ERROR slot DATUM
        pushSTACK(S(package)); # TYPE-ERROR slot EXPECTED-TYPE
        pushSTACK(newpack); pushSTACK(pack);
        fehler(type_error,
               GETTEXT("The value of *PACKAGE* was not a package. Old value ~. New value ~.")
              );
      }
    }

# UP: Überprüft ein Package-Argument.
# Testet, ob es eine Package oder ein Packagename ist, und liefert es als
# Package zurück. Sonst Fehlermeldung.
# test_package_arg(obj)
# > obj: Argument
# > subr_self: Aufrufer (ein SUBR)
# < ergebnis: in eine Package umgewandeltes Argument
  local object test_package_arg (object obj);
  local object test_package_arg(obj)
    var object obj;
    {
      if (packagep(obj)) { # Package -> meist OK
        if (!pack_deletedp(obj))
          return obj;
        pushSTACK(obj); # Wert für Slot PACKAGE von PACKAGE-ERROR
        pushSTACK(obj);
        fehler(package_error,
               GETTEXT("Package ~ has been deleted.")
              );
      }
      if (stringp(obj)) {
       string: # String -> Package mit Namen obj suchen:
        var object pack = find_package(obj);
        if (!nullp(pack))
          return pack;
        pushSTACK(obj); # Wert für Slot PACKAGE von PACKAGE-ERROR
        pushSTACK(obj);
        fehler(package_error,
               GETTEXT("There is no package with name ~")
              );
      }
      if (symbolp(obj)) { # Symbol ->
        obj = Symbol_name(obj); goto string; # Printnamen verwenden
      }
      pushSTACK(obj); # TYPE-ERROR slot DATUM
      pushSTACK(O(type_packname)); # TYPE-ERROR slot EXPECTED-TYPE
      pushSTACK(obj); pushSTACK(TheSubr(subr_self)->name);
      fehler(type_error,
             GETTEXT("~: argument should be a package or a package name, not ~")
            );
    }

LISPFUNN(make_symbol,1) # (MAKE-SYMBOL printname), CLTL S. 168
  {
    var object arg = popSTACK();
    if (!stringp(arg)) {
      pushSTACK(arg); # TYPE-ERROR slot DATUM
      pushSTACK(S(string)); # TYPE-ERROR slot EXPECTED-TYPE
      pushSTACK(arg); pushSTACK(TheSubr(subr_self)->name);
      fehler(type_error,
             GETTEXT("~: argument should be a string, not ~")
            );
    }
    # Simple-String draus machen und Symbol bauen:
    value1 = make_symbol(coerce_imm_ss(arg)); mv_count=1;
  }

# UP: Überprüft ein String/Symbol-Argument
# > obj: Argument
# > subr_self: Aufrufer (ein SUBR)
# < ergebnis: Argument als String
  local object test_stringsym_arg (object obj);
  local object test_stringsym_arg(obj)
    var object obj;
    {
      if (stringp(obj)) # String: unverändert zurück
        return obj;
      if (symbolp(obj)) # Symbol: Printnamen verwenden
        return TheSymbol(obj)->pname;
      pushSTACK(obj); # TYPE-ERROR slot DATUM
      pushSTACK(O(type_stringsym)); # TYPE-ERROR slot EXPECTED-TYPE
      pushSTACK(obj); pushSTACK(TheSubr(subr_self)->name);
      fehler(type_error,
             GETTEXT("~: argument ~ should be a string or a symbol")
            );
    }

LISPFUNN(find_package,1) # (FIND-PACKAGE name), CLTL S. 183
  {
    var object name = test_stringsym_arg(popSTACK()); # Argument als String
    value1 = find_package(name); # Package suchen
    mv_count=1;
  }

LISPFUNN(pfind_package,1) # (SYSTEM::%FIND-PACKAGE name)
  {
    value1 = test_package_arg(popSTACK()); # Argument als Package
    mv_count=1;
  }

LISPFUNN(package_name,1) # (PACKAGE-NAME package), CLTL S. 184
  {
    var object pack = popSTACK();
    if (packagep(pack) && pack_deletedp(pack)) {
      value1 = NIL;
    } else {
      pack = test_package_arg(pack); # Argument als Package
      value1 = ThePackage(pack)->pack_name; # der Name
    }
    mv_count=1;
  }

LISPFUNN(package_nicknames,1) # (PACKAGE-NICKNAMES package), CLTL S. 184
  {
    var object pack = popSTACK();
    if (packagep(pack) && pack_deletedp(pack)) {
      value1 = NIL;
    } else {
      pack = test_package_arg(pack); # Argument als Package
      value1 = copy_list(ThePackage(pack)->pack_nicknames); # Nicknameliste sicherheitshalber kopieren
    }
    mv_count=1;
  }

# UP: Überprüft name und nicknames - Argumente von RENAME-PACKAGE und MAKE-PACKAGE.
# Testet, ob STACK_3 ein Name ist, und macht daraus einen immutablen Simple-String.
# Testet, ob STACK_2 ein Name oder eine Liste von Namen ist, und macht
# daraus eine neue Liste von immutablen Simple-Strings.
# > subr-self: Aufrufer (ein SUBR)
# can trigger GC
  local void test_names_args (void);
  local void test_names_args()
    {
      # name auf String prüfen und zu einem Simple-String machen:
      STACK_3 = coerce_imm_ss(test_stringsym_arg(STACK_3));
      # Nickname-Argument in eine Liste umwandeln:
      {
        var object nicknames = STACK_2;
        if (eq(nicknames,unbound)) {
          STACK_2 = NIL; # keine Nicknames angegeben -> Default NIL
        } else {
          if (!listp(nicknames)) {
            # nicknames keine Liste -> eine einelementige Liste daraus machen:
            nicknames = allocate_cons();
            Car(nicknames) = STACK_2;
            STACK_2 = nicknames;
          }
        }
      }
      # Nickname(s) auf String prüfen, zu Simple-Strings machen
      # und daraus eine neue Nicknameliste machen:
      {
        pushSTACK(NIL); # neue Nicknameliste := NIL
        while (mconsp(STACK_3)) {
          {
            var object nickname = Car(STACK_3); # nächster Nickname
            STACK_3 = Cdr(STACK_3);
            nickname = coerce_imm_ss(test_stringsym_arg(nickname)); # als Simple-String
            # vor die neue Nicknameliste consen:
            pushSTACK(nickname);
          }
          var object new_cons = allocate_cons();
          Car(new_cons) = popSTACK();
          Cdr(new_cons) = STACK_0;
          STACK_0 = new_cons;
        }
        var object nicknames = popSTACK();
        STACK_2 = nicknames; # neue Nicknameliste ersetzt die alte
      }
    }

LISPFUN(rename_package,2,1,norest,nokey,0,NIL)
# (RENAME-PACKAGE pack name [nicknames]), CLTL S. 184
  {
    # Testen, ob pack eine Package ist:
    STACK_2 = test_package_arg(STACK_2);
    check_pack_lock(S(rename_package),STACK_2,STACK_1);
    # name und nicknames überprüfen:
    pushSTACK(NIL); pushSTACK(NIL); # Dummies auf den Stack
    test_names_args();
    skipSTACK(2);
    var object pack = STACK_2;
    # Teste, ob ein Packagenamenkonflikt entsteht:
    {
      var object name = STACK_1;
      var object nicknamelistr = STACK_0;
      # name durchläuft den Namen und alle Nicknames
      loop {
        var object found = find_package(name); # Suche Package mit diesem Namen
        if (!(nullp(found) || eq(found,pack))) {
          # gefunden, aber eine andere als die gegebene Package:
          pushSTACK(pack); # Wert für Slot PACKAGE von PACKAGE-ERROR
          pushSTACK(name); pushSTACK(TheSubr(subr_self)->name);
          fehler(package_error,
                 GETTEXT("~: there is already a package named ~")
                );
        }
        # Keine oder nur die gegebene Package hat den Namen name ->
        # kein Konflikt mit diesem (Nick)name, weiter:
        if (atomp(nicknamelistr))
          break;
        name = Car(nicknamelistr); # nächster Nickname
        nicknamelistr = Cdr(nicknamelistr); # restliche Nicknameliste verkürzen
      }
    }
    # Es gibt keine Konflikte.
    set_break_sem_2();
    ThePackage(pack)->pack_name = STACK_1;
    ThePackage(pack)->pack_nicknames = STACK_0;
    clr_break_sem_2();
    skipSTACK(3);
    value1 = pack; mv_count=1; # pack als Wert
  }

LISPFUNN(package_use_list,1) # (PACKAGE-USE-LIST package), CLTL S. 184
  {
    var object pack = test_package_arg(popSTACK()); # Argument als Package
    value1 = copy_list(ThePackage(pack)->pack_use_list); # Use-List sicherheitshalber kopieren
    mv_count=1;
  }

LISPFUNN(package_used_by_list,1) # (PACKAGE-USED-BY-LIST package), CLTL S. 184
  {
    var object pack = test_package_arg(popSTACK()); # Argument als Package
    value1 = copy_list(ThePackage(pack)->pack_used_by_list); # Used-By-List sicherheitshalber kopieren
    mv_count=1;
  }

LISPFUNN(package_shadowing_symbols,1) # (PACKAGE-SHADOWING-SYMBOLS package), CLTL S. 184
  {
    var object pack = test_package_arg(popSTACK()); # Argument als Package
    value1 = copy_list(ThePackage(pack)->pack_shadowing_symbols); # Shadowing-Liste sicherheitshalber kopieren
    mv_count=1;
  }

# (EXT:PACKAGE-LOCK package)
LISPFUNN(package_lock,1) {
  var object pack = test_package_arg(popSTACK());
  value1 = (pack_locked_p(pack) ? T : NIL);
  mv_count = 1;
}

# (SYSTEM::%SET-PACKAGE-LOCK package lock)
LISPFUNN(set_package_lock,2) {
  var object lock_p = popSTACK();
  var object pack = popSTACK();
  if (mconsp(pack)) {
    while (mconsp(pack)) {
      var object pa = test_package_arg(Car(pack)); pack = Cdr(pack);
      if (eq(lock_p,NIL)) mark_pack_unlocked(pa);
      else                mark_pack_locked(pa);
    }
  } else {
    if (eq(lock_p,NIL)) mark_pack_unlocked(pack);
    else                mark_pack_locked(pack);
  }
  value1 = (eq(lock_p,NIL) ? NIL : T); mv_count = 1;
}

# (SYSTEM::CHECK-PACKAGE-LOCK function package symbol)
LISPFUNN(check_package_lock,3) {
  if (mconsp(STACK_1)) { # package is a actually a clist of packages
    var bool locked = true;
    var object list = STACK_1;
    while (locked && mconsp(list)) {
      locked = pack_locked_p(Car(list));
      list = Cdr(list);
    }
    if (locked) # all packages are locked --> error
      cerror_package_locked(STACK_2,STACK_1,STACK_0);
  } else # just one package - check it
    check_pack_lock(STACK_2,STACK_1,STACK_0);
  skipSTACK(3);
  mv_count = 0;
}

LISPFUNN(list_all_packages,0)
# (LIST-ALL-PACKAGES) liefert eine Liste aller Packages, CLTL S. 184
  {
    value1 = reverse(O(all_packages)); # (Kopie der Liste, sicherheitshalber)
    mv_count=1;
  }

# UP: Überprüft das letzte Argument &optional (pack *package*) einer
# LISP-Funktion.
# test_optional_package_arg()
# > STACK_0: letztes Argument
# > subr_self: Aufrufer (ein SUBR)
# < STACK_0: in eine Package umgewandeltes Argument
  local void test_optional_package_arg (void);
  local void test_optional_package_arg()
    {
      var object pack = STACK_0;
      if (eq(pack,unbound)) {
        STACK_0 = get_current_package(); # Default ist Wert von *PACKAGE*
      } else {
        STACK_0 = test_package_arg(pack);
      }
    }

# UP: Überprüfung der Argumente von INTERN und FIND-SYMBOL.
# test_intern_args()
# > subr_self: Aufrufer (ein SUBR)
  local void test_intern_args (void);
  local void test_intern_args()
    {
      # String überprüfen:
      if (!stringp(STACK_1))
        fehler_string(STACK_1);
      # Package überprüfen:
      test_optional_package_arg();
    }

# UP: Wandelt ein INTERN/FIND-SYMBOL - Ergebnis in ein Keyword um.
# intern_result(code)
# > code : Flag wie bei intern und find_symbol
# < ergebnis : entsprechendes Keyword
  local object intern_result (uintBWL code);
  local object intern_result(code)
    var uintBWL code;
    {
      switch (code) {
        case 0: return NIL;           # 0 -> NIL
        case 1: return S(Kexternal);  # 1 -> :EXTERNAL
        case 2: return S(Kinherited); # 2 -> :INHERITED
        case 3: return S(Kinternal);  # 3 -> :INTERNAL
        default: NOTREACHED;
      }
    }

LISPFUN(intern,1,1,norest,nokey,0,NIL)
# (INTERN string [package]), CLTL S. 184
  {
    test_intern_args(); # Argumente überprüfen
    var object pack = popSTACK();
    var object string = popSTACK();
    #if !defined(VALUE1_EXTRA)
    var uintBWL code = intern(string,pack,&value1); # Symbol nach value1
    #else
    var object value;
    var uintBWL code = intern(string,pack,&value); # Symbol nach value
    value1 = value;
    #endif
    value2 = intern_result(code); mv_count=2; # 2 Werte
  }

LISPFUN(find_symbol,1,1,norest,nokey,0,NIL)
# (FIND-SYMBOL string [package]), CLTL S. 185
  {
    test_intern_args(); # Argumente überprüfen
    var object pack = popSTACK();
    var object string = popSTACK();
    #if !defined(VALUE1_EXTRA)
    var uintBWL code = find_symbol(string,pack,&value1) & 3; # Symbol nach value1
    #else
    var object value;
    var uintBWL code = find_symbol(string,pack,&value) & 3; # Symbol nach value
    value1 = value;
    #endif
    value2 = intern_result(code); mv_count=2; # 2 Werte
  }

LISPFUN(unintern,1,1,norest,nokey,0,NIL)
# (UNINTERN symbol [package]), CLTL S. 185
  {
    # Symbol überprüfen:
    if (!symbolp(STACK_1)) {
      pushSTACK(STACK_1); # TYPE-ERROR slot DATUM
      pushSTACK(S(symbol)); # TYPE-ERROR slot EXPECTED-TYPE
      pushSTACK(STACK_(1+2)); pushSTACK(TheSubr(subr_self)->name);
      fehler(type_error,
             GETTEXT("~: argument ~ is not a symbol")
            );
    }
    # Package überprüfen:
    test_optional_package_arg();
    # uninternieren:
    value1 = unintern(&STACK_1,&STACK_0); mv_count=1;
    skipSTACK(2);
  }

# Ausführer einer Funktion wie EXPORT, UNEXPORT, IMPORT, SHADOWING-IMPORT
# oder SHADOW. Überprüft, ob das erste Argument eine Symbolliste ist, ob
# das zweite Argument (Default: *PACKAGE*) eine Package ist, und wendet das
# Unterprogramm auf jedes der Symbole an. Rücksprung mit 1 Wert T.
# apply_symbols(&fun);
# Spezifikation des Unterprogrammes fun:
#   fun(&sym,&pack);
#   > sym: Symbol (im STACK)
#   > pack: Package (im STACK)
#   < pack: Package, EQ zur alten
#   can trigger GC
# < STACK: aufgeräumt
# can trigger GC
  typedef void sym_pack_function (const object* sym_, const object* pack_);
  local Values apply_symbols (sym_pack_function* fun);
  local Values apply_symbols(fun)
    var sym_pack_function* fun;
    {
      # Überprüfe, ob das erste Argument eine Symbolliste oder ein Symbol ist:
      {
        var object symarg = STACK_1;
        # auf Symbol testen:
        if (symbolp(symarg))
          goto ok;
        #ifdef X3J13_161
        if ((fun == &shadow) && stringp(symarg))
          goto ok;
        #endif
        # auf Symbolliste testen:
        while (consp(symarg)) { # symarg durchläuft STACK_1
          if (!(symbolp(Car(symarg))
                #ifdef X3J13_161
                || ((fun == &shadow) && stringp(Car(symarg)))
                #endif
             ) )
            goto not_ok;
          symarg = Cdr(symarg);
        }
        if (!nullp(symarg))
          goto not_ok; # Liste korrekt beendet?
        goto ok; # korrekte Symbolliste
       not_ok:
        pushSTACK(STACK_1); pushSTACK(TheSubr(subr_self)->name);
        fehler(error,
               GETTEXT("~: argument should be a symbol or a list of symbols, not ~")
              );
       ok: ;
      }
      # Package überprüfen:
      test_optional_package_arg();
      # Stackaufbau: symarg, pack.
      # fun auf alle Symbole anwenden:
      if (matomp(STACK_1)) {
        # einzelnes Symbol
        # Stackaufbau: sym, pack.
        (*fun)(&STACK_1,&STACK_0);
        skipSTACK(2);
      } else {
        # nichtleere Symbolliste
        pushSTACK(NIL);
        do {
          var object symlistr = STACK_2;
          STACK_2 = Cdr(symlistr);
          STACK_0 = Car(symlistr); # Symbol
          # Stackaufbau: symlistr, pack, sym.
          (*fun)(&STACK_0,&STACK_1);
        } until (matomp(STACK_2));
        skipSTACK(3);
      }
      # beenden:
      value1 = T; mv_count=1;
    }

LISPFUN(export,1,1,norest,nokey,0,NIL)
# (EXPORT symbols [package]), CLTL S. 186
  {
    return_Values apply_symbols(&export);
  }

LISPFUN(unexport,1,1,norest,nokey,0,NIL)
# (UNEXPORT symbols [package]), CLTL S. 186
  {
    return_Values apply_symbols(&unexport);
  }

LISPFUN(import,1,1,norest,nokey,0,NIL)
# (IMPORT symbols [package]), CLTL S. 186
  {
    return_Values apply_symbols(&import);
  }

LISPFUN(shadowing_import,1,1,norest,nokey,0,NIL)
# (SHADOWING-IMPORT symbols [package]), CLTL S. 186
  {
    return_Values apply_symbols(&shadowing_import);
  }

LISPFUN(shadow,1,1,norest,nokey,0,NIL)
# (SHADOW symbols [package]), CLTL S. 186
  {
    return_Values apply_symbols(&shadow);
  }

# UP: Vorbereitung der Argumente bei USE-PACKAGE und UNUSE-PACKAGE.
# Das 1. Argument STACK_1 wird zu einer (neu erzeugten) Liste von Packages
# gemacht, das 2. Argument STACK_0 wird überprüft.
# > subr_self: Aufrufer (ein SUBR)
# can trigger GC
  local void prepare_use_package (void);
  local void prepare_use_package()
    {
      # 2. Argument (Package) überprüfen:
      test_optional_package_arg();
      # 1. Argument (Package oder Packageliste) überprüfen:
      {
        var object packs_to_use = STACK_1;
        if (!listp(packs_to_use)) {
          # packs_to_use keine Liste -> einelementige Liste draus machen:
          pushSTACK(test_package_arg(packs_to_use)); # einzelne Package
          var object new_cons = allocate_cons();
          Car(new_cons) = popSTACK();
          STACK_1 = new_cons;
        } else {
          # packs_to_use eine Liste -> neue Packageliste aufbauen:
          pushSTACK(NIL); # mit NIL anfangen
          while (mconsp(STACK_2)) {
            var object packlistr = STACK_2;
            STACK_2 = Cdr(packlistr);
            pushSTACK(test_package_arg(Car(packlistr))); # nächste Package
            var object new_cons = allocate_cons();
            Car(new_cons) = popSTACK();
            Cdr(new_cons) = STACK_0;
            STACK_0 = new_cons;
          }
          var object packlist = popSTACK(); # neue Packageliste
          STACK_1 = packlist;
        }
      }
    }

LISPFUN(use_package,1,1,norest,nokey,0,NIL)
# (USE-PACKAGE packs-to-use [package]), CLTL S. 187
  {
    prepare_use_package();
    var object pack = popSTACK();
    var object packlist = popSTACK();
    use_package(packlist,pack);
    value1 = T; mv_count=1;
  }

LISPFUN(unuse_package,1,1,norest,nokey,0,NIL)
# (UNUSE-PACKAGE packs-to-use [package]), CLTL S. 187
  {
    prepare_use_package();
    var object pack = popSTACK();
    var object packlist = popSTACK();
    unuse_package(packlist,pack);
    value1 = T; mv_count=1;
  }

# UP: Korrigiert einen Package(nick)name.
# > name: Gewünschter Packagename (Simple-String)
# > STACK_1: "Sie dürfen einen neuen (Nick)Name eingeben."
# > STACK_0: "Bitte neuen Package(nick)name eingeben:"
# < ergebnis: Noch nicht vorkommender Packagename
# can trigger GC
  local object correct_packname (object name);
  local object correct_packname(name)
    var object name;
    {
      while (!nullp(find_package(name))) {
        # Package mit diesem Namen existiert schon
          pushSTACK(STACK_1); # "Sie dürfen ... eingeben."
          pushSTACK(S(package_error)); # PACKAGE-ERROR
          pushSTACK(S(Kpackage)); # :PACKAGE
          pushSTACK(name); # Package-Name
          pushSTACK(NIL); # "Eine Package mit dem Namen ~S gibt es schon."
          pushSTACK(name);
          STACK_1 = OLS(makepack_string3);
          funcall(L(cerror_of_type),6); # (SYS::CERROR-OF-TYPE "Sie dürfen ..." 'PACKAGE-ERROR :PACKAGE name "Package ~S existiert" name)
        {
          var object stream = var_stream(S(query_io),strmflags_rd_ch_B|strmflags_wr_ch_B); # Stream *QUERY-IO*
          pushSTACK(stream);
          terpri(&STACK_0); # neue Zeile
          write_sstring(&STACK_0,STACK_1); # "Bitte ... eingeben:"
          funcall(L(read_line),1); # (READ-LINE stream)
          name = value1;
        }
      }
      return coerce_imm_ss(name);
    }

# UP für MAKE-PACKAGE und %IN-PACKAGE:
# Bildet eine neue Package und liefert sie als Wert.
# > STACK_3: name-Argument
# > STACK_2: nicknames-Argument
# > STACK_1: uselist-Argument
# > STACK_0: case-sensitive-Argument
# > subr_self: Aufrufer (ein SUBR)
# erhöht STACK um 4
# can trigger GC
  local void in_make_package (void);
  local void in_make_package()
    {
      # name in Simple-String und nicknames in neue Simple-String-Liste umwandeln:
      test_names_args();
      # name überprüfen und evtl. korrigieren:
      {
        pushSTACK(OLS(makepack_string1)); # "Sie dürfen einen neuen Namen eingeben."
        pushSTACK(OLS(makepack_string4)); # "Bitte neuen Packagenamen eingeben:"
        STACK_(3+2) = correct_packname(STACK_(3+2));
        skipSTACK(2);
      }
      # nicknames überprüfen und evtl. korrigieren:
      {
        pushSTACK(STACK_2); # nicknames durchgehen
        while (mconsp(STACK_0)) {
          var object nickname;
          pushSTACK(OLS(makepack_string2)); # "Sie dürfen einen neuen Nickname eingeben."
          pushSTACK(OLS(makepack_string5)); # "Bitte neuen Packagenickname eingeben:"
          nickname = Car(STACK_2); # nickname herausgreifen
          nickname = correct_packname(nickname); # korrigieren
          skipSTACK(2);
          Car(STACK_0) = nickname; # und wieder einsetzen
          STACK_0 = Cdr(STACK_0);
        }
        skipSTACK(1);
      }
      # Package erzeugen:
      {
        var object pack = make_package(STACK_3,STACK_2,
                                       (eq(STACK_0,unbound) || nullp(STACK_0) ? false : true)
                                     );
        STACK_3 = pack; # und retten
        # Stackaufbau: pack, nicknames, uselist-Argument, case-sensitive-Argument.
        # Defaultwert für Use-Argument verwenden:
        if (eq(STACK_1,unbound))
          STACK_1 = O(use_default);
        # (USE-PACKAGE UseList neuePackage) ausführen:
          pushSTACK(STACK_1); # UseList
          pushSTACK(pack); # neue Package
          funcall(L(use_package),2);
      }
      skipSTACK(3);
      value1 = popSTACK(); mv_count=1; # Package als Wert
    }

LISPFUN(make_package,1,0,norest,key,3, (kw(nicknames),kw(use),kw(case_sensitive)) )
# (MAKE-PACKAGE name [:NICKNAMES nicknames] [:USE uselist]
#                    [:CASE-SENSITIVE sensitivep]),
# CLTL S. 183
  {
    in_make_package();
  }

LISPFUN(pin_package,1,0,norest,key,3, (kw(nicknames),kw(use),kw(case_sensitive)) )
# (SYSTEM::%IN-PACKAGE name [:NICKNAMES nicknames] [:USE uselist]
#                           [:CASE-SENSITIVE sensitivep])
# ist wie (IN-PACKAGE name [:NICKNAMES nicknames] [:USE uselist]), CLTL S. 183,
# nur dass *PACKAGE* nicht modifiziert wird.
  {
    # name überprüfen und in String umwandeln:
    var object name = test_stringsym_arg(STACK_3);
    STACK_3 = name;
    # Package mit diesem Namen suchen:
    var object pack = find_package(name);
    if (nullp(pack)) {
      # Package nicht gefunden, muss eine neue erzeugen
      in_make_package();
    } else {
      # Package gefunden
      STACK_3 = pack; # pack retten
      # Stackaufbau: pack, nicknames, uselist, case-sensitive.
      # Die Case-Sensitivity überprüfen:
      if (!eq(STACK_0,unbound)) {
        if (!(pack_casesensitivep(pack) == !nullp(STACK_0))) {
          pushSTACK(pack); # Wert für Slot PACKAGE von PACKAGE-ERROR
          pushSTACK(pack);
          fehler(package_error,
                 GETTEXT("Cannot change the case sensitiveness of ~.")
                );
        }
      }
      # Die Nicknames anpassen:
      if (!eq(STACK_2,unbound)) {
        # Nicknames installieren mit RENAME-PACKAGE:
        pushSTACK(pack); # pack
        pushSTACK(ThePackage(pack)->pack_name); # (package-name pack)
        pushSTACK(STACK_(2+2)); # nicknames
        funcall(L(rename_package),3); # (RENAME-PACKAGE pack (package-name pack) nicknames)
      }
      # Die Use-List anpassen:
      if (!eq(STACK_1,unbound)) {
        # Use-List erweitern mit USE-PACKAGE
        # und verkürzen mit UNUSE-PACKAGE:
        STACK_0 = STACK_3; # pack als 2. Argument für USE-PACKAGE
        prepare_use_package(); # Argumente STACK_1, STACK_0 überprüfen
        # Stackaufbau: pack, nicknames, neue Use-List, pack.
        # USE-PACKAGE ausführen (mit kopierter Use-List):
        {
          var object temp = reverse(STACK_1);
          use_package(temp,STACK_3);
        }
        # Alle Packages, die jetzt noch in der Use-List von pack
        # aufgeführt sind, aber nicht in der in STACK_1 befindlichen
        # uselist vorkommen, werden mit unuse_1package entfernt:
        pack = STACK_3;
        {
          var object used_packs = ThePackage(pack)->pack_use_list; # Use-List von pack durchgehen
          while (consp(used_packs)) {
            var object qpack = Car(used_packs);
            # in uselist suchen:
            var object listr = STACK_1;
            while (consp(listr)) {
              if (eq(qpack,Car(listr)))
                goto unuse_ok; # in uselist gefunden -> OK
              listr = Cdr(listr);
            }
            # nicht in uselist gefunden
            unuse_1package(pack,qpack);
           unuse_ok: ;
            used_packs = Cdr(used_packs);
          }
        }
      }
      # Die Use-List ist korrekt angepasst.
      skipSTACK(3); # uselist, nicknames usw. vergessen
      value1 = popSTACK(); mv_count=1;
    }
  }

local one_sym_function delete_package_aux;
LISPFUNN(delete_package,1)
# (DELETE-PACKAGE package), CLTL2 S. 265-266
  {
    var object pack = popSTACK();
    if (packagep(pack)) {
      if (pack_deletedp(pack)) {
        value1 = NIL; mv_count=1; return; # schon gelöscht -> 1 Wert NIL
      }
    } elif (stringp(pack)) {
     string: # String -> Package mit diesem Namen suchen:
      var object found = find_package(pack);
      if (nullp(found)) {
        # Continuable Error auslösen:
        pushSTACK(NIL); # "Ignorieren."
        pushSTACK(S(package_error)); # PACKAGE-ERROR
        pushSTACK(S(Kpackage)); # :PACKAGE
        pushSTACK(pack); # Package-Name
        pushSTACK(NIL); # "~S: Eine Package mit Namen ~S gibt es nicht."
        pushSTACK(S(delete_package));
        pushSTACK(pack);
        STACK_6 = OLS(delpack_string1);
        STACK_2 = OLS(delpack_string2);
        funcall(L(cerror_of_type),7); # (SYS::CERROR-OF-TYPE "..." 'PACKAGE-ERROR :PACKAGE pack "..." 'DELETE-PACKAGE pack)
        value1 = NIL; mv_count=1; # 1 Wert NIL
        return;
      }
      pack = found;
    } elif (symbolp(pack)) { # Symbol ->
      pack = Symbol_name(pack); goto string; # Printnamen verwenden
    } else {
      pack = test_package_arg(pack); # Fehler melden
    }
    pushSTACK(pack);
    if (!nullp(ThePackage(pack)->pack_used_by_list)) {
      # Continuable Error auslösen:
      pushSTACK(NIL); # "~*~S wird trotzdem gelöscht."
      pushSTACK(S(package_error)); # PACKAGE-ERROR
      pushSTACK(S(Kpackage)); # :PACKAGE
      pushSTACK(pack); # Package
      pushSTACK(NIL); # "~S: ~S wird von ~{~S~^, ~} benutzt."
      pushSTACK(S(delete_package));
      pushSTACK(pack);
      pushSTACK(ThePackage(pack)->pack_used_by_list);
      STACK_7 = OLS(delpack_string3);
      STACK_3 = OLS(delpack_string4);
      funcall(L(cerror_of_type),8); # (SYS::CERROR-OF-TYPE "..." 'PACKAGE-ERROR :PACKAGE pack "..." 'DELETE-PACKAGE pack used-by-list)
    }
    pack = STACK_0;
    # (DOLIST (p used-py-list) (UNUSE-PACKAGE pack p)) ausführen:
    set_break_sem_3();
    while (mconsp(ThePackage(pack)->pack_used_by_list)) {
      unuse_1package(Car(ThePackage(pack)->pack_used_by_list),pack);
    }
    clr_break_sem_3();
    # (UNUSE-PACKAGE (package-use-list pack) pack) ausführen:
    unuse_package(ThePackage(pack)->pack_use_list,pack);
    # delete_package_aux auf die in pack präsenten Symbole anwenden:
    map_symtab_c(&delete_package_aux,&STACK_0,ThePackage(STACK_0)->pack_external_symbols);
    map_symtab_c(&delete_package_aux,&STACK_0,ThePackage(STACK_0)->pack_internal_symbols);
    pack = popSTACK();
    # pack aus der Liste aller Packages herausnehmen und als gelöscht markieren:
    set_break_sem_2();
    O(all_packages) = deleteq(O(all_packages),pack);
    mark_pack_deleted(pack);
    clr_break_sem_2();
    value1 = T; mv_count=1; # 1 Wert T
  }

# Hilfsfunktion für DELETE-PACKAGE:
# Entferne das Argument (ein präsentes Symbol) aus pack.
# can trigger GC
local void delete_package_aux (void* data, object sym);
local void delete_package_aux(data,sym)
  var void* data;
  var object sym;
  {
    var object* localptr = (object*)data; # Pointer auf pack
    pushSTACK(sym); unintern(&STACK_0,&(*localptr)); skipSTACK(1);
  }

LISPFUNN(find_all_symbols,1)
# (FIND-ALL-SYMBOLS name), CLTL S. 187
  {
    STACK_0 = test_stringsym_arg(STACK_0); # name als String
    pushSTACK(NIL); # (bisher leere) Symbolliste
    pushSTACK(O(all_packages)); # Liste aller Packages durchgehen
    while (mconsp(STACK_0)) {
      var object pack = Car(STACK_0); # nächste Package
      # in deren internen und externen Symbolen suchen:
      var object sym;
      if (symtab_lookup(STACK_2,ThePackage(pack)->pack_internal_symbols,&sym)
          || symtab_lookup(STACK_2,ThePackage(pack)->pack_external_symbols,&sym)
         ) {
        # gefunden: Symbol sym ist in Package pack präsent,
        # mit (pushnew sym STACK_1 :test #'eq) auf die Symbolliste consen:
        # Suche, ob das gefundene Symbol sym in STACK_1 vorkommt:
        {
          var object symlistr = STACK_1;
          while (consp(symlistr)) {
            if (eq(sym,Car(symlistr)))
              goto already_found; # gefunden -> nichts weiter zu tun
            symlistr = Cdr(symlistr);
          }
        }
        # nicht gefunden, muss consen:
        pushSTACK(sym);
        {
          var object new_cons = allocate_cons();
          Car(new_cons) = popSTACK();
          Cdr(new_cons) = STACK_1;
          STACK_1 = new_cons;
        }
       already_found: ;
      }
      STACK_0 = Cdr(STACK_0);
    }
    skipSTACK(1);
    value1 = popSTACK(); mv_count=1; # Symbolliste als Wert
    skipSTACK(1);
  }

local one_sym_function map_symbols_aux;
LISPFUNN(map_symbols,2)
# (SYSTEM::MAP-SYMBOLS fun pack)
# wendet die Funktion fun auf alle in pack accessiblen Symbole an. Wert NIL.
  {
    # 2. Argument überprüfen:
    STACK_0 = test_package_arg(STACK_0);
    # fun auf alle internen Symbole loslassen:
    map_symtab(STACK_1,ThePackage(STACK_0)->pack_internal_symbols);
    # fun auf alle externen Symbole loslassen:
    map_symtab(STACK_1,ThePackage(STACK_0)->pack_external_symbols);
    # fun auf alle vererbten Symbole loslassen:
    pushSTACK(ThePackage(STACK_0)->pack_use_list); # Use-List durchgehen
    while (mconsp(STACK_0)) {
      var object usedpack = Car(STACK_0); # nächste Package aus der Use-List
      STACK_0 = Cdr(STACK_0);
      map_symtab_c(&map_symbols_aux,&STACK_1,ThePackage(usedpack)->pack_external_symbols);
    }
    skipSTACK(3);
    value1 = NIL; mv_count=1; # NIL als Wert
  }

# Hilfsfunktion für map_symbols:
# Teste, ob das Argument nicht in der gegebenen Package verdeckt ist, und
# wende dann die gegebene Funktion an.
# can trigger GC
local void map_symbols_aux (void* data, object sym);
local void map_symbols_aux(data,sym)
  var void* data;
  var object sym;
  {
    var object* localptr = (object*)data;
    # Pointer auf lokale Variablen von map_symbols:
    #   *(localptr STACKop 1) = fun,
    #   *(localptr STACKop 0) = pack.
    # Verdeckt ist das Symbol STACK_0 genau dann, wenn sich ein davon
    # verschiedenes Symbol desselben Namens in der Shadowing-Liste von pack
    # befindet.
    var object shadowingsym;
    if (!(shadowing_lookup(Symbol_name(sym),*(localptr STACKop 0),&shadowingsym)
          && !eq(shadowingsym,sym)
       ) ) {
      pushSTACK(sym); funcall(*(localptr STACKop 1),1);
    } else {
      # Symbol ist in pack verdeckt -> Funktion nicht aufrufen
    }
  }

LISPFUNN(map_external_symbols,2)
# (SYSTEM::MAP-EXTERNAL-SYMBOLS fun pack)
# wendet die Funktion fun auf alle in pack externen Symbole an. Wert NIL.
  {
    # 2. Argument überprüfen:
    var object pack = test_package_arg(popSTACK());
    # fun auf alle externen Symbole loslassen:
    map_symtab(popSTACK(),ThePackage(pack)->pack_external_symbols);
    value1 = NIL; mv_count=1; # NIL als Wert
  }

LISPFUNN(map_all_symbols,1)
# (SYSTEM::MAP-ALL-SYMBOLS fun)
# wendet die Funktion fun auf alle in irgendeiner Package präsenten Symbole an.
  {
     pushSTACK(O(all_packages)); # Package-Liste durchgehen
    while (mconsp(STACK_0)) {
      var object pack = Car(STACK_0); # nächste Package
      STACK_0 = Cdr(STACK_0);
      pushSTACK(pack); # retten
      # fun auf alle internen Symbole loslassen:
      map_symtab(STACK_2,ThePackage(pack)->pack_internal_symbols);
      pack = popSTACK();
      # fun auf alle externen Symbole loslassen:
      map_symtab(STACK_1,ThePackage(pack)->pack_external_symbols);
    }
    skipSTACK(2);
    value1 = NIL; mv_count=1; # NIL als Wert
  }

# Subroutine for EXT:RE-EXPORT.
# Exports a single symbol from TO-PACK.
local void export_symbol_from (void *data, object sym) {
  var object* pack_ = (object*)data; # points into the STACK
  pushSTACK(sym);
  export(&STACK_0,pack_);
  skipSTACK(1);
}

LISPFUNN(re_export,2)
# (EXT:RE-EXPORT "FROM-PACK" "TO-PACK")
# export all external symbols in FROM-PACK from TO-PACK
{
  STACK_1 = test_package_arg(STACK_1); # FROM-PACK
  STACK_0 = test_package_arg(STACK_0); # TO-PACK
  # TO-PACK must be already using FROM-PACK
  var object pack_u_l = ThePackage(STACK_0)->pack_use_list;
  while (consp(pack_u_l)) {
    if (eq(STACK_1,Car(pack_u_l)))
      goto pack_ok;
    pack_u_l = Cdr(pack_u_l);
  }
  pushSTACK(STACK_0); # TO-PACK: PACKAGE slot of PACKAGE-ERROR
  pushSTACK(STACK_2); # FROM-PACK
  pushSTACK(STACK_1); # TO-PACK
  fehler(package_error,GETTEXT("~ is not using ~"));
 pack_ok:
  map_symtab_c(&export_symbol_from,&STACK_0,
               ThePackage(STACK_1)->pack_external_symbols);
  value1 = NIL;
  mv_count = 1;
  skipSTACK(2);
}

# Hilfsfunktionen für WITH-PACKAGE-ITERATOR, CLtL2 S. 275, und LOOP:
# (SYSTEM::PACKAGE-ITERATOR package flags) liefert einen internen Zustand
# für das Iterieren durch die Package.
# (SYSTEM::PACKAGE-ITERATE internal-state) iteriert durch eine Package um
# eins weiter, verändert dabei internal-state und liefert: 3 Werte
# T, symbol, accessibility des nächsten Symbols bzw. 1 Wert NIL am Schluss.

LISPFUNN(package_iterator,2)
  {
    STACK_1 = test_package_arg(STACK_1); # package-Argument überprüfen
    # Ein interner Zustand besteht aus einem Vektor
    # #(entry index symtab inh-packages package flags)
    # wobei flags eine Teilliste von (:INTERNAL :EXTERNAL :INHERITED) ist,
    #       package die ursprüngliche Package ist,
    #       inh-packages eine Teilliste von (package-use-list package) ist,
    #       symtab eine Symboltabelle oder NIL ist,
    #       index ein Index in symtab ist,
    #       entry der Rest eines Eintrags in symtab ist.
    var object state = allocate_vector(6);
    # TheSvector(state)->data[2] = NIL; # unnötig
    TheSvector(state)->data[3] = ThePackage(STACK_1)->pack_use_list;
    TheSvector(state)->data[4] = STACK_1;
    TheSvector(state)->data[5] = STACK_0;
    value1 = state; mv_count=1; skipSTACK(2); # state als Wert
  }

LISPFUNN(package_iterate,1)
  {
    var object state = popSTACK(); # interner Zustand
    if (simple_vector_p(state) && (Svector_length(state) == 6)) { # hoffentlich ein 6er-Vektor
      # state = #(entry index symtab inh-packages package flags)
      var object symtab = TheSvector(state)->data[2];
      if (simple_vector_p(symtab)) {
        if (false) {
         search1:
          TheSvector(state)->data[2] = symtab;
          TheSvector(state)->data[1] = Symtab_size(symtab);
          TheSvector(state)->data[0] = NIL;
        }
       search2:
        {
          var object entry = TheSvector(state)->data[0];
         search3:
          # Innerhalb von entry weitersuchen:
          if (consp(entry)) {
            TheSvector(state)->data[0] = Cdr(entry);
            value2 = Car(entry); goto found;
          } elif (!nullp(entry)) {
            TheSvector(state)->data[0] = NIL;
            value2 = entry; goto found;
          }
          if (false) {
           found:
            # Found a symbol value.
            # Verify that is it accessible in pack and, if :INHERITED
            # is requested,
            # 1. not hidden by a different symbol (which must be on the
            #    shadowing-list of pack),
            # 2. itself not already present in pack (because in this case
            #    the accessibility would be :INTERNAL or :EXTERNAL).
            {
              var object shadowingsym;
              if (!(eq(Car(TheSvector(state)->data[5]),S(Kinherited))
                    && (shadowing_lookup(Symbol_name(value2),TheSvector(state)->data[4],&shadowingsym)
                        || symtab_find(value2,ThePackage(TheSvector(state)->data[4])->pack_internal_symbols)
                        || symtab_find(value2,ThePackage(TheSvector(state)->data[4])->pack_external_symbols)
                 ) )   ) {
                # Symbol value2 is really accessible.
                value1 = T; value3 = Car(TheSvector(state)->data[5]);
                mv_count=3; return;
              }
              goto search2;
            }
          }
          # entry = NIL geworden -> zum nächsten Index
          {
            var uintL index = posfixnum_to_L(TheSvector(state)->data[1]);
            if (index > 0) {
              TheSvector(state)->data[1] = fixnum_inc(TheSvector(state)->data[1],-1);
              index--;
              entry = (index < posfixnum_to_L(Symtab_size(symtab)) # index sicherheitshalber überprüfen
                       ? TheSvector(Symtab_table(symtab))->data[index]
                       : NIL
                      );
              goto search3;
            }
          }
        }
        # index = 0 geworden -> zur nächsten Tabelle
        if (eq(Car(TheSvector(state)->data[5]),S(Kinherited))) {
         search4:
          if (mconsp(TheSvector(state)->data[3])) {
            # zum nächsten Element der Liste inh-packages
            symtab = ThePackage(Car(TheSvector(state)->data[3]))->pack_external_symbols;
            TheSvector(state)->data[3] = Cdr(TheSvector(state)->data[3]);
            goto search1;
          }
        }
       search5:
        # zum nächsten Element von flags
        TheSvector(state)->data[5] = Cdr(TheSvector(state)->data[5]);
      }
      var object flags = TheSvector(state)->data[5];
      if (consp(flags)) {
        var object flag = Car(flags);
        if (eq(flag,S(Kinternal))) { # :INTERNAL
          symtab = ThePackage(TheSvector(state)->data[4])->pack_internal_symbols;
          goto search1;
        } elif (eq(flag,S(Kexternal))) { # :EXTERNAL
          symtab = ThePackage(TheSvector(state)->data[4])->pack_external_symbols;
          goto search1;
        }
        elif (eq(flag,S(Kinherited))) { # :INHERITED
          goto search4;
        }
        goto search5; # unzulässiges Flag übergehen
      }
    }
    value1 = NIL; mv_count=1; return; # 1 Wert NIL
  }

# UP: initialize the package list
# init_packages();
  global void init_packages (void);
  global void init_packages()
    {
      pushSTACK(coerce_imm_ss(ascii_to_string("COMMON-LISP")));
      pushSTACK(coerce_imm_ss(ascii_to_string("LISP")));
      pushSTACK(coerce_imm_ss(ascii_to_string("CL")));
      pushSTACK(coerce_imm_ss(ascii_to_string("COMMON-LISP-USER")));
      pushSTACK(coerce_imm_ss(ascii_to_string("CL-USER")));
      pushSTACK(coerce_imm_ss(ascii_to_string("USER")));
      pushSTACK(coerce_imm_ss(ascii_to_string("SYSTEM")));
      pushSTACK(coerce_imm_ss(ascii_to_string("COMPILER")));
      pushSTACK(coerce_imm_ss(ascii_to_string("SYS")));
      pushSTACK(coerce_imm_ss(ascii_to_string("KEYWORD")));
      pushSTACK(coerce_imm_ss(ascii_to_string("")));
      pushSTACK(coerce_imm_ss(ascii_to_string("CHARSET")));
      O(all_packages) = NIL; # ALL_PACKAGES := NIL
      # #<PACKAGE CHARSET>:
      O(charset_package) = make_package(popSTACK(),NIL,false); # "CHARSET",()
      # #<PACKAGE KEYWORD>:
      { var object nicks = listof(1); # ("")
        O(keyword_package) = make_package(popSTACK(),nicks,false); # "KEYWORD"
      }
      # #<PACKAGE SYSTEM>:
      { var object nicks = listof(2); # ("COMPILER" "SYS")
        make_package(popSTACK(),nicks,false); # "SYSTEM"
      }
      # #<package COMMON-LISP-USER>
      { var object nicks = listof(2); # ("CL-USER","USER")
        make_package(popSTACK(),nicks,false); # "COMMON-LISP-USER"
      }
      # #<PACKAGE LISP>:
      { var object nicks = listof(2); # ("LISP" "CL")
        O(default_package) = make_package(popSTACK(),nicks,false); # "COMMON-LISP"
      }
      # Created all basic packages.
      # Now append all further packages to the end of O(all_packages).
      nreverse(O(all_packages));
      #define LISPPACK  LISPPACK_B
      #include "constpack.c"
      #undef LISPPACK
      nreverse(O(all_packages));
    }

