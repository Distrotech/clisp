# DO NOT EDIT! GENERATED AUTOMATICALLY!
# Copyright (C) 2002-2010 Free Software Foundation, Inc.
#
# This file is free software, distributed under the terms of the GNU
# General Public License.  As a special exception to the GNU General
# Public License, this file may be distributed as part of a program
# that contains a configuration script generated by Autoconf, under
# the same distribution terms as the rest of that program.
#
# Generated by gnulib-tool.
#
# This file represents the compiled summary of the specification in
# gnulib-cache.m4. It lists the computed macro invocations that need
# to be invoked from configure.ac.
# In projects using CVS, this file can be treated like other built files.


# This macro should be invoked from ./configure.ac, in the section
# "Checks for programs", right after AC_PROG_CC, and certainly before
# any checks for libraries, header files, types and library functions.
AC_DEFUN([sc_gl_EARLY],
[
  m4_pattern_forbid([^gl_[A-Z]])dnl the gnulib macro namespace
  m4_pattern_allow([^gl_ES$])dnl a valid locale name
  m4_pattern_allow([^gl_LIBOBJS$])dnl a variable
  m4_pattern_allow([^gl_LTLIBOBJS$])dnl a variable
  AC_REQUIRE([AC_PROG_RANLIB])
  # Code from module alignof:
  # Code from module arg-nonnull:
  # Code from module c++defs:
  # Code from module close-hook:
  # Code from module errno:
  # Code from module gethostname:
  # Code from module mbrlen:
  # Code from module mktime:
  # Code from module multiarch:
  # Code from module sockets:
  # Code from module socklen:
  # Code from module stddef:
  # Code from module strcase:
  # Code from module strftime:
  # Code from module strings:
  # Code from module strptime:
  # Code from module strverscmp:
  # Code from module sys_socket:
  # Code from module sys_utsname:
  # Code from module time:
  # Code from module time_r:
  # Code from module uname:
  # Code from module unistd:
  # Code from module warn-on-use:
])

# This macro should be invoked from ./configure.ac, in the section
# "Check for header files, types and library functions".
AC_DEFUN([sc_gl_INIT],
[
  AM_CONDITIONAL([GL_COND_LIBTOOL], [false])
  gl_cond_libtool=false
  gl_libdeps=
  gl_ltlibdeps=
  gl_m4_base='modules/syscalls/glm4'
  m4_pushdef([AC_LIBOBJ], m4_defn([sc_gl_LIBOBJ]))
  m4_pushdef([AC_REPLACE_FUNCS], m4_defn([sc_gl_REPLACE_FUNCS]))
  m4_pushdef([AC_LIBSOURCES], m4_defn([sc_gl_LIBSOURCES]))
  m4_pushdef([sc_gl_LIBSOURCES_LIST], [])
  m4_pushdef([sc_gl_LIBSOURCES_DIR], [])
  gl_COMMON
  gl_source_base='modules/syscalls/gllib'
  # Code from module alignof:
  # Code from module arg-nonnull:
  # Code from module c++defs:
  # Code from module close-hook:
  # Code from module errno:
  gl_HEADER_ERRNO_H
  # Code from module gethostname:
  gl_FUNC_GETHOSTNAME
  gl_UNISTD_MODULE_INDICATOR([gethostname])
  # Code from module mbrlen:
  gl_FUNC_MBRLEN
  gl_WCHAR_MODULE_INDICATOR([mbrlen])
  # Code from module mktime:
  gl_FUNC_MKTIME
  gl_TIME_MODULE_INDICATOR([mktime])
  # Code from module multiarch:
  gl_MULTIARCH
  # Code from module sockets:
  gl_SOCKETS
  # Code from module socklen:
  gl_TYPE_SOCKLEN_T
  # Code from module stddef:
  gl_STDDEF_H
  # Code from module strcase:
  gl_STRCASE
  # Code from module strftime:
  gl_FUNC_GNU_STRFTIME
  # Code from module strings:
  gl_HEADER_STRINGS_H
  # Code from module strptime:
  gl_FUNC_STRPTIME
  gl_TIME_MODULE_INDICATOR([strptime])
  # Code from module strverscmp:
  gl_FUNC_STRVERSCMP
  gl_STRING_MODULE_INDICATOR([strverscmp])
  # Code from module sys_socket:
  gl_HEADER_SYS_SOCKET
  AC_PROG_MKDIR_P
  # Code from module sys_utsname:
  gl_SYS_UTSNAME_H
  AC_PROG_MKDIR_P
  # Code from module time:
  gl_HEADER_TIME_H
  # Code from module time_r:
  gl_TIME_R
  gl_TIME_MODULE_INDICATOR([time_r])
  # Code from module uname:
  gl_FUNC_UNAME
  gl_SYS_UTSNAME_MODULE_INDICATOR([uname])
  # Code from module unistd:
  gl_UNISTD_H
  # Code from module warn-on-use:
  # End of code from modules
  m4_ifval(sc_gl_LIBSOURCES_LIST, [
    m4_syscmd([test ! -d ]m4_defn([sc_gl_LIBSOURCES_DIR])[ ||
      for gl_file in ]sc_gl_LIBSOURCES_LIST[ ; do
        if test ! -r ]m4_defn([sc_gl_LIBSOURCES_DIR])[/$gl_file ; then
          echo "missing file ]m4_defn([sc_gl_LIBSOURCES_DIR])[/$gl_file" >&2
          exit 1
        fi
      done])dnl
      m4_if(m4_sysval, [0], [],
        [AC_FATAL([expected source file, required through AC_LIBSOURCES, not found])])
  ])
  m4_popdef([sc_gl_LIBSOURCES_DIR])
  m4_popdef([sc_gl_LIBSOURCES_LIST])
  m4_popdef([AC_LIBSOURCES])
  m4_popdef([AC_REPLACE_FUNCS])
  m4_popdef([AC_LIBOBJ])
  AC_CONFIG_COMMANDS_PRE([
    sc_gl_libobjs=
    sc_gl_ltlibobjs=
    if test -n "$sc_gl_LIBOBJS"; then
      # Remove the extension.
      sed_drop_objext='s/\.o$//;s/\.obj$//'
      for i in `for i in $sc_gl_LIBOBJS; do echo "$i"; done | sed -e "$sed_drop_objext" | sort | uniq`; do
        sc_gl_libobjs="$sc_gl_libobjs $i.$ac_objext"
        sc_gl_ltlibobjs="$sc_gl_ltlibobjs $i.lo"
      done
    fi
    AC_SUBST([sc_gl_LIBOBJS], [$sc_gl_libobjs])
    AC_SUBST([sc_gl_LTLIBOBJS], [$sc_gl_ltlibobjs])
  ])
  gltests_libdeps=
  gltests_ltlibdeps=
  m4_pushdef([AC_LIBOBJ], m4_defn([sc_gltests_LIBOBJ]))
  m4_pushdef([AC_REPLACE_FUNCS], m4_defn([sc_gltests_REPLACE_FUNCS]))
  m4_pushdef([AC_LIBSOURCES], m4_defn([sc_gltests_LIBSOURCES]))
  m4_pushdef([sc_gltests_LIBSOURCES_LIST], [])
  m4_pushdef([sc_gltests_LIBSOURCES_DIR], [])
  gl_COMMON
  gl_source_base='tests'
changequote(,)dnl
  sc_gltests_WITNESS=IN_`echo "${PACKAGE-$PACKAGE_TARNAME}" | LC_ALL=C tr abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ | LC_ALL=C sed -e 's/[^A-Z0-9_]/_/g'`_GNULIB_TESTS
changequote([, ])dnl
  AC_SUBST([sc_gltests_WITNESS])
  gl_module_indicator_condition=$sc_gltests_WITNESS
  m4_pushdef([gl_MODULE_INDICATOR_CONDITION], [$gl_module_indicator_condition])
  m4_popdef([gl_MODULE_INDICATOR_CONDITION])
  m4_ifval(sc_gltests_LIBSOURCES_LIST, [
    m4_syscmd([test ! -d ]m4_defn([sc_gltests_LIBSOURCES_DIR])[ ||
      for gl_file in ]sc_gltests_LIBSOURCES_LIST[ ; do
        if test ! -r ]m4_defn([sc_gltests_LIBSOURCES_DIR])[/$gl_file ; then
          echo "missing file ]m4_defn([sc_gltests_LIBSOURCES_DIR])[/$gl_file" >&2
          exit 1
        fi
      done])dnl
      m4_if(m4_sysval, [0], [],
        [AC_FATAL([expected source file, required through AC_LIBSOURCES, not found])])
  ])
  m4_popdef([sc_gltests_LIBSOURCES_DIR])
  m4_popdef([sc_gltests_LIBSOURCES_LIST])
  m4_popdef([AC_LIBSOURCES])
  m4_popdef([AC_REPLACE_FUNCS])
  m4_popdef([AC_LIBOBJ])
  AC_CONFIG_COMMANDS_PRE([
    sc_gltests_libobjs=
    sc_gltests_ltlibobjs=
    if test -n "$sc_gltests_LIBOBJS"; then
      # Remove the extension.
      sed_drop_objext='s/\.o$//;s/\.obj$//'
      for i in `for i in $sc_gltests_LIBOBJS; do echo "$i"; done | sed -e "$sed_drop_objext" | sort | uniq`; do
        sc_gltests_libobjs="$sc_gltests_libobjs $i.$ac_objext"
        sc_gltests_ltlibobjs="$sc_gltests_ltlibobjs $i.lo"
      done
    fi
    AC_SUBST([sc_gltests_LIBOBJS], [$sc_gltests_libobjs])
    AC_SUBST([sc_gltests_LTLIBOBJS], [$sc_gltests_ltlibobjs])
  ])
  LIBGNU_LIBDEPS="$gl_libdeps"
  AC_SUBST([LIBGNU_LIBDEPS])
  LIBGNU_LTLIBDEPS="$gl_ltlibdeps"
  AC_SUBST([LIBGNU_LTLIBDEPS])
])

# Like AC_LIBOBJ, except that the module name goes
# into sc_gl_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([sc_gl_LIBOBJ], [
  AS_LITERAL_IF([$1], [sc_gl_LIBSOURCES([$1.c])])dnl
  sc_gl_LIBOBJS="$sc_gl_LIBOBJS $1.$ac_objext"
])

# Like AC_REPLACE_FUNCS, except that the module name goes
# into sc_gl_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([sc_gl_REPLACE_FUNCS], [
  m4_foreach_w([gl_NAME], [$1], [AC_LIBSOURCES(gl_NAME[.c])])dnl
  AC_CHECK_FUNCS([$1], , [sc_gl_LIBOBJ($ac_func)])
])

# Like AC_LIBSOURCES, except the directory where the source file is
# expected is derived from the gnulib-tool parameterization,
# and alloca is special cased (for the alloca-opt module).
# We could also entirely rely on EXTRA_lib..._SOURCES.
AC_DEFUN([sc_gl_LIBSOURCES], [
  m4_foreach([_gl_NAME], [$1], [
    m4_if(_gl_NAME, [alloca.c], [], [
      m4_define([sc_gl_LIBSOURCES_DIR], [modules/syscalls/gllib])
      m4_append([sc_gl_LIBSOURCES_LIST], _gl_NAME, [ ])
    ])
  ])
])

# Like AC_LIBOBJ, except that the module name goes
# into sc_gltests_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([sc_gltests_LIBOBJ], [
  AS_LITERAL_IF([$1], [sc_gltests_LIBSOURCES([$1.c])])dnl
  sc_gltests_LIBOBJS="$sc_gltests_LIBOBJS $1.$ac_objext"
])

# Like AC_REPLACE_FUNCS, except that the module name goes
# into sc_gltests_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([sc_gltests_REPLACE_FUNCS], [
  m4_foreach_w([gl_NAME], [$1], [AC_LIBSOURCES(gl_NAME[.c])])dnl
  AC_CHECK_FUNCS([$1], , [sc_gltests_LIBOBJ($ac_func)])
])

# Like AC_LIBSOURCES, except the directory where the source file is
# expected is derived from the gnulib-tool parameterization,
# and alloca is special cased (for the alloca-opt module).
# We could also entirely rely on EXTRA_lib..._SOURCES.
AC_DEFUN([sc_gltests_LIBSOURCES], [
  m4_foreach([_gl_NAME], [$1], [
    m4_if(_gl_NAME, [alloca.c], [], [
      m4_define([sc_gltests_LIBSOURCES_DIR], [tests])
      m4_append([sc_gltests_LIBSOURCES_LIST], _gl_NAME, [ ])
    ])
  ])
])

# This macro records the list of files which have been installed by
# gnulib-tool and may be removed by future gnulib-tool invocations.
AC_DEFUN([sc_gl_FILE_LIST], [
  build-aux/arg-nonnull.h
  build-aux/c++defs.h
  build-aux/warn-on-use.h
  lib/alignof.h
  lib/close-hook.c
  lib/close-hook.h
  lib/errno.in.h
  lib/gethostname.c
  lib/mbrlen.c
  lib/mktime-internal.h
  lib/mktime.c
  lib/sockets.c
  lib/sockets.h
  lib/stddef.in.h
  lib/strcasecmp.c
  lib/strftime.c
  lib/strftime.h
  lib/strings.in.h
  lib/strncasecmp.c
  lib/strptime.c
  lib/strverscmp.c
  lib/sys_socket.in.h
  lib/sys_utsname.in.h
  lib/time.in.h
  lib/time_r.c
  lib/uname.c
  lib/unistd.in.h
  lib/w32sock.h
  m4/00gnulib.m4
  m4/errno_h.m4
  m4/gethostname.m4
  m4/gnulib-common.m4
  m4/mbrlen.m4
  m4/mbstate_t.m4
  m4/mktime.m4
  m4/multiarch.m4
  m4/sockets.m4
  m4/socklen.m4
  m4/sockpfaf.m4
  m4/stddef_h.m4
  m4/strcase.m4
  m4/strftime.m4
  m4/strings_h.m4
  m4/strptime.m4
  m4/strverscmp.m4
  m4/sys_socket_h.m4
  m4/sys_utsname_h.m4
  m4/time_h.m4
  m4/time_r.m4
  m4/tm_gmtoff.m4
  m4/uname.m4
  m4/unistd_h.m4
  m4/warn-on-use.m4
  m4/wchar_t.m4
])
