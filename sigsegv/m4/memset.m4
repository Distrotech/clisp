dnl Copyright (C) 1993-2002 Free Software Foundation, Inc.
dnl This file is free software, distributed under the terms of the GNU
dnl General Public License.  As a special exception to the GNU General
dnl Public License, this file may be distributed as part of a program
dnl that contains a configuration script generated by Autoconf, under
dnl the same distribution terms as the rest of that program.

dnl From Bruno Haible, Marcus Daniels.

AC_PREREQ(2.13)

AC_DEFUN([CL_MEMSET],
[CL_PROTO([memset], [
for y in 'int' 'size_t'; do
for x in 'char*' 'void*'; do
if test -z "$have_memset"; then
AC_TRY_COMPILE([
#include <stdlib.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <string.h>
#undef memset
]AC_LANG_EXTERN[
#if defined(__STDC__) || defined(__cplusplus)
$x memset ($x s, int c, $y n);
#else
$x memset();
#endif
], [],
cl_cv_proto_memset_ret="$x"
cl_cv_proto_memset_arg1="$x"
cl_cv_proto_memset_arg3="$y"
have_memset=1)
fi
done
done
], [extern $cl_cv_proto_memset_ret memset ($cl_cv_proto_memset_arg1, int, $cl_cv_proto_memset_arg3);])
AC_DEFINE_UNQUOTED(RETMEMSETTYPE,$cl_cv_proto_memset_ret)
])
