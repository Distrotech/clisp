# Choice of user interface language, and internationalization.

# ------------------------------ Specification ---------------------------------

#ifndef LANGUAGE_STATIC

  # The current user interface language.
    extern uintL language;

  # Initializes the current interface language, according to the given
  # arguments, getting the defaults from environment variables.
    local void init_language (const char* argv_language, const char* argv_localedir);

  # Returns the translation of msgid according to the current interface
  # language.
    global const char * clgettext (const char * msgid);

  # Returns the translation of obj according to the current interface
  # language. obj must be a string. A string is returned.
    global object localized_string (object obj);

  # Returns the translated value of obj. obj is translated, then
  # READ-FROM-STRING is applied to the result.
    global object localized_object (object obj);

#endif

# ------------------------------ Implementation --------------------------------

#ifdef GNU_GETTEXT

  # Modify the environment variables. putenv() is POSIX, but some BSD systems
  # only have setenv(). Therefore (and because it's simpler to use) we
  # implement this interface, but without the third argument.
  # mysetenv(name,value) sets the value of the environment variable `name' to
  # `value' and returns 0. Returns -1 if not enough memory.
  local int mysetenv (const char * name, const char * value);
  local int mysetenv(name,value)
    var const char * name;
    var const char * value;
    {
      var uintL namelen = asciz_length(name);
      var uintL valuelen = asciz_length(value);
      #if defined(HAVE_PUTENV)
        var char* buffer = malloc(namelen+1+valuelen+1);
        var char* bufptr;
        if (!buffer)
          return -1; # no need to set errno = ENOMEM
        bufptr = buffer;
        dotimesL(namelen,namelen, {
          *bufptr++ = *name++;
        });
        *bufptr++ = '=';
        dotimesL(valuelen,valuelen, {
          *bufptr++ = *value++;
        });
        *bufptr = '\0';
        return putenv(buffer);
      #elif defined(HAVE_SETENV)
        return setenv(name,value,1);
      #else
        # Uh oh, neither putenv() nor setenv(), have to frob the environment
        # ourselves. Routine taken from glibc and fixed in several aspects.
        extern char** environ;
        var char** epp;
        var char* ep;
        var uintL envvar_count = 0;
        for (epp = environ; (ep = *epp) != NULL; epp++) {
          var const char * np = name;
          # Compare *epp and name:
          while (*np != '\0' && *np == *ep) { np++; ep++; }
          if (*np == '\0' && *ep == '=')
            break;
          envvar_count++;
        }
        ep = *epp;
        if (ep == NULL) {
          # name not found in environ, add it.
          # Remember the environ, so that we can free it if we need
          # to reallocate it again next time.
          var static char** last_environ = NULL;
          var char** new_environ = (char**) malloc((envvar_count+2)*sizeof(char*));
          if (!new_environ)
            return -1; # no need to set errno = ENOMEM
          {
            var uintL count;
            epp = environ;
            for (count = 0; count < envvar_count; count++)
              new_environ[count] = epp[count];
          }
          ep = (char*) malloc(namelen+1+valuelen+1);
          if (!ep) {
            free(new_environ); return -1; # no need to set errno = ENOMEM
          }
          {
            var char* cp = ep;
            dotimesL(namelen,namelen, {
              *cp++ = *name++;
            });
            *cp++ = '=';
            dotimesL(valuelen,valuelen, {
              *cp++ = *value++;
            });
            *cp = '\0';
          }
          new_environ[envvar_count] = ep;
          new_environ[envvar_count+1] = NULL;
          environ = new_environ;
          if (last_environ != NULL)
            free(last_environ);
          last_environ = new_environ;
        } else {
          # name found, replace its value.
          # We could be tempted to overwrite name's value directly if
          # the new value is not longer than the old value. But that's
          # not a good idea - maybe someone still has a pointer to
          # this area around.
          ep = (char*) malloc(namelen+1+valuelen+1);
          if (!ep)
            return -1; # no need to set errno = ENOMEM
          {
            var char* cp = ep;
            dotimesL(namelen,namelen, {
              *cp++ = *name++;
            });
            *cp++ = '=';
            dotimesL(valuelen,valuelen, {
              *cp++ = *value++;
            });
            *cp = '\0';
          }
          *epp = ep;
        }
        return 0;
      #endif
    }

#endif

#ifndef LANGUAGE_STATIC

  # Sprache, in der mit dem Benutzer kommuniziert wird:
    global uintL language;

  # Initialisiert die Sprache, gegeben die Sprachbezeichnung.
    local bool init_language_from (const char* langname);
    #ifdef GNU_GETTEXT
      #define language_deutsch   1
      #define language_francais  2
      #define language_spanish   3
      #define language_dutch     4
    #endif
    local bool init_language_from(langname)
      var const char* langname;
      {
        if (asciz_equal(langname,"ENGLISH") || asciz_equal(langname,"english")) {
          language = language_english; return true;
        }
        #ifdef GNU_GETTEXT
        if (asciz_equal(langname,"DEUTSCH") || asciz_equal(langname,"deutsch")
            || asciz_equal(langname,"GERMAN") || asciz_equal(langname,"german")
           ) {
          language = language_deutsch; return true;
        }
        if (asciz_equal(langname,"FRANCAIS") || asciz_equal(langname,"francais")
            #ifndef ASCII_CHS
            || asciz_equal(langname,"FRAN\307AIS") || asciz_equal(langname,"FRAN\303\207AIS") # FRAN�AIS
            || asciz_equal(langname,"fran\347ais") || asciz_equal(langname,"fran\303\247ais") # français
            #endif
            || asciz_equal(langname,"FRENCH") || asciz_equal(langname,"french")
           ) {
          language = language_francais; return true;
        }
        if (asciz_equal(langname,"ESPANOL") || asciz_equal(langname,"espanol")
            #ifndef ASCII_CHS
            || asciz_equal(langname,"ESPA\321OL") || asciz_equal(langname,"ESPA\303\221OL") # ESPA�OL
            || asciz_equal(langname,"espa\361ol") || asciz_equal(langname,"espa\303\261ol") # español
            #endif
            || asciz_equal(langname,"SPANISH") || asciz_equal(langname,"spanish")
           ) {
          language = language_spanish; return true;
        }
        if (asciz_equal(langname,"NEDERLANDS") || asciz_equal(langname,"nederlands")
            || asciz_equal(langname,"DUTCH") || asciz_equal(langname,"dutch")
           ) {
          language = language_dutch; return true;
        }
        #endif
        return false;
      }

  # Initialisiert die Sprache.
    local void init_language (const char* argv_language, const char* argv_localedir);
    local void init_language(argv_language,argv_localedir)
      var const char* argv_language;
      var const char* argv_localedir;
      { # Sprache wird so festgelegt, mit Prioritäten in dieser Reihenfolge:
        #   1. Fest eingebaut, LANGUAGE_STATIC
        #   2. -L Kommandozeilen-Argument
        #   3. Environment-Variable CLISP_LANGUAGE
        #   4. Environment-Variable LANG
        #   5. Default: Englisch
        if (argv_language) {
          if (init_language_from(argv_language))
            goto chosen1;
        }
        #ifdef HAVE_ENVIRONMENT
        {
          var const char* langname = getenv("CLISP_LANGUAGE");
          if (langname) {
            if (init_language_from(langname))
              goto chosen1;
          }
          #ifdef AMIGAOS
          langname = getenv("Language"); # since OS 3.0
          if (langname) {
            if (init_language_from(langname))
              goto chosen1;
          }
          #endif
        }
        #endif
        #ifdef GNU_GETTEXT
        # The analysis of getenv("LANG") below will be done - in more detail -
        # by bindtextdomain() and textdomain(). No need to do it ourselves.
        # Do we need to call setlocale(LC_MESSAGES,"") or not??
        goto chosen2;
        #else
        #ifdef HAVE_ENVIRONMENT
        #define ascii_alphanumericp(c)  \
          ((c>='A' && c<='Z') || (c>='a' && c<='z') || (c>='0' && c<='9'))
        {
          var const char* lang = getenv("LANG");
          if (lang) {
            # LANG hat i.a. die Syntax Sprache[_Land][.Zeichensatz]
            if (lang[0]=='e' && lang[1]=='n' && !ascii_alphanumericp(lang[2])) { # "en"
              language = language_english; goto chosen2;
            }
          }
        }
        #endif
        # Default: Englisch
        language = language_english; goto chosen2;
        #endif
       chosen1:
        # At this point we have chosen the language based upon the
        # command-line option or the clisp-specific environment variables.
        #ifdef GNU_GETTEXT
          # GNU gettext chooses the message catalog based upon:
          # 1. environment variable LANGUAGE [only if dcgettext.c, not with
          #    cat-compat.c],
          # 2. environment variable LC_ALL,
          # 3. environment variable LC_MESSAGES,
          # 4. environment variable LANG.
          # We clobber LC_MESSAGES and unset the earlier two variables.
          {
            var const char * locale =
              language == language_english ? "en" :
              language == language_deutsch ? "de" :
              language == language_francais ? "fr" :
              language == language_spanish ? "es" :
              language == language_dutch ? "nl" :
              "";
            if (getenv("LANGUAGE"))
              mysetenv("LANGUAGE","");
            if (getenv("LC_ALL"))
              mysetenv("LC_ALL","");
            mysetenv("LC_MESSAGES",locale);
            #ifdef LC_MESSAGES # !(UNIX_NEXTSTEP || ...)
            # Given the above, the following line is probably not needed.
            # (Depends on the behaviour of setlocale(LC_MESSAGES,NULL) on
            # your system.) Anyway it doesn't hurt.
            setlocale(LC_MESSAGES,locale);
            #endif
          }
        #endif
       chosen2:
        # At this point we have chosen the language based upon an
        # environment variable GNU gettext knows about.
        #ifdef GNU_GETTEXT
        {
          # We apparently don't need to check whether argv_localedir is
          # not NULL and a valid directory. But since we may call chdir()
          # before the gettext library opens the catalog file, we have to
          # convert argv_localedir to be an absolute pathname, if possible.
          #ifdef UNIX
            if (!(argv_localedir == NULL))
              if (argv_localedir[0] != '\0' && argv_localedir[0] != '/') {
                var char currdir[MAXPATHLEN];
                if (!(getwd(currdir) == NULL)) {
                  var uintL currdirlen = asciz_length(currdir);
                  if (currdirlen > 0 && currdir[0] == '/') {
                    var uintL len = currdirlen + 1 + asciz_length(argv_localedir) + 1;
                    var char* abs_localedir = (char*)malloc(len*sizeof(char));
                    if (!(abs_localedir == NULL)) {
                      # Append currdir, maybe '/', and argv_localedir into abs_localedir:
                      var char* ptr = abs_localedir;
                      {
                        var const char * srcptr = currdir;
                        var uintL count;
                        dotimespL(count,currdirlen, { *ptr++ = *srcptr++; });
                      }
                      if (ptr[-1] != '/')
                        *ptr++ = '/';
                      {
                        var const char * srcptr = argv_localedir;
                        while ((*ptr++ = *srcptr++) != '\0') continue;
                      }
                      argv_localedir = abs_localedir;
                    }
                  }
                }
              }
          #endif
          bindtextdomain("clisp",argv_localedir);
          bindtextdomain("clisplow",argv_localedir);
          #ifdef UNICODE
          bind_textdomain_codeset("clisp","UTF-8");
          #endif
          #ifdef IBMPC_CHS
          bind_textdomain_codeset("clisplow","CP437");
          #endif
        }
        #endif
        return;
      }

 #ifdef GNU_GETTEXT

  global const char * clgettext (const char * msgid);
  global const char * clgettext(msgid)
    var const char * msgid;
    {
      var const char * translated_msg;
      if (msgid[0] == '\0') {
        # If you ask gettext to translate the empty string, it returns
        # the catalog's header (containing meta information)!
        translated_msg = msgid;
      } else {
        begin_system_call();
        translated_msg = dgettext("clisp",msgid);
        end_system_call();
      }
      return translated_msg;
    }

  # Low-level messages, which are output through asciz_out, are
  # stored in a separate catalog and returned in locale encoding.
  global const char * clgettextl (const char * msgid);
  global const char * clgettextl(msgid)
    var const char * msgid;
    {
      var const char * translated_msg;
      if (msgid[0] == '\0') {
        # If you ask gettext to translate the empty string, it returns
        # the catalog's header (containing meta information)!
        translated_msg = msgid;
      } else {
        begin_system_call();
        translated_msg = dgettext("clisplow",msgid);
        end_system_call();
      }
      return translated_msg;
    }

  # FIXME: Don't hardwire ISO-8859-1. The catalog's character set is
  # given by the "Content-Type:" line in the meta information.

  global object localized_string (object obj);
  global object localized_string(obj)
    var object obj;
    {
      ASSERT(stringp(obj));
      with_string_0(obj,Symbol_value(S(ascii)),asciz, {
        obj = asciz_to_string(clgettext(asciz),Symbol_value(S(utf_8)));
      });
      return obj;
    }

  global object localized_object (object obj);
  global object localized_object(obj)
    var object obj;
    {
      ASSERT(stringp(obj));
      with_string_0(obj,Symbol_value(S(ascii)),asciz, {
        obj = asciz_to_string(clgettext(asciz),Symbol_value(S(utf_8)));
      });
      dynamic_bind(S(packagestern),O(default_package)); # *PACKAGE* binden
      pushSTACK(obj); funcall(L(read_from_string),1); # READ-FROM-STRING ausführen
      dynamic_unbind();
      return value1;
    }

 #endif

#endif
