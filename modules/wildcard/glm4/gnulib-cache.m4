# Copyright (C) 2002-2009 Free Software Foundation, Inc.
#
# This file is free software, distributed under the terms of the GNU
# General Public License.  As a special exception to the GNU General
# Public License, this file may be distributed as part of a program
# that contains a configuration script generated by Autoconf, under
# the same distribution terms as the rest of that program.
#
# Generated by gnulib-tool.
#
# This file represents the specification of how gnulib-tool is used.
# It acts as a cache: It is written and read by gnulib-tool.
# In projects using CVS, this file is meant to be stored in CVS,
# like the configure.ac and various Makefile.am files.


# Specification in the form of a command-line invocation:
#   gnulib-tool --import --dir=. --lib=libgnu --source-base=modules/wildcard/gllib --m4-base=modules/wildcard/glm4 --doc-base=doc --tests-base=tests --aux-dir=src/build-aux --avoid=alloca --avoid=alloca-opt --avoid=extensions --avoid=getpagesize --avoid=gettext --avoid=gettimeofday --avoid=gnu-make --avoid=havelib --avoid=include_next --avoid=libsigsegv --avoid=link-follow --avoid=localcharset --avoid=mbrtowc --avoid=mbsinit --avoid=mbsrtowcs --avoid=memchr --avoid=memcmp --avoid=memmove --avoid=nocrash --avoid=stdbool --avoid=stdint --avoid=streq --avoid=string --avoid=sys_time --avoid=uniname/uniname --avoid=unistd --avoid=unitypes --avoid=uniwidth/width --avoid=verify --avoid=wchar --avoid=wctype --no-libtool --macro-prefix=wc_gl --no-vc-files fnmatch-gnu

# Specification in the form of a few gnulib-tool.m4 macro invocations:
gl_LOCAL_DIR([])
gl_MODULES([
  fnmatch-gnu
])
gl_AVOID([alloca alloca-opt extensions getpagesize gettext gettimeofday gnu-make havelib include_next libsigsegv link-follow localcharset mbrtowc mbsinit mbsrtowcs memchr memcmp memmove nocrash stdbool stdint streq string sys_time uniname/uniname unistd unitypes uniwidth/width verify wchar wctype])
gl_SOURCE_BASE([modules/wildcard/gllib])
gl_M4_BASE([modules/wildcard/glm4])
gl_PO_BASE([])
gl_DOC_BASE([doc])
gl_TESTS_BASE([tests])
gl_LIB([libgnu])
gl_MAKEFILE_NAME([])
gl_MACRO_PREFIX([wc_gl])
gl_PO_DOMAIN([])
gl_VC_FILES([false])
