# posix math functions in <math.h>
# Sam Steingold <sds@gnu.org> 1999+
# configure --export-syscalls to access these in the package posix

#ifdef EXPORT_SYSCALLS

#define decimal_string solaris_decimal_string
#include <math.h>
#undef decimal_string

local double to_double (object x);
local double to_double(x)
  var object x;
{ check_real(x);
  return DF_to_double(R_rationalp(x) ? RA_to_DF(x) : F_to_DF(x)); }

local int to_int (object x);
local int to_int(x)
  var object x;
{ check_integer(x); return I_to_L(x); }

#define D_S           to_double(popSTACK())
#define I_S           to_int(popSTACK())
#define N_D(num,val)  double_to_DF(num,val=,FALSE,FALSE,FALSE,FALSE,FALSE)
#define VAL_D(func)   double res=func(D_S); N_D(res,value1)
#define VAL_ID(func)  double xx=D_S; int nn=I_S; double res=func(nn,xx); N_D(res,value1)

LISPFUNN(erf,1)
{ VAL_D(erf); mv_count=1; }

LISPFUNN(erfc,1)
{ VAL_D(erfc); mv_count=1; }

LISPFUNN(j0,1)
{ VAL_D(j0); mv_count=1; }

LISPFUNN(j1,1)
{ VAL_D(j1); mv_count=1; }

LISPFUNN(jn,2)
{ VAL_ID(jn); mv_count=1; }

LISPFUNN(y0,1)
{ VAL_D(y0); mv_count=1; }

LISPFUNN(y1,1)
{ VAL_D(y1); mv_count=1; }

LISPFUNN(yn,2)
{ VAL_ID(yn); mv_count=1; }

LISPFUNN(gamma,1)
{ VAL_D(gamma); mv_count=1; }

LISPFUNN(lgamma,1)
{
#ifdef _REENTRANT
  int sign;
  double res = lgamma_r(D_S,&sign);
  value2 = sfixnum(sign);
#else
  double res = lgamma(D_S);
  value2 = sfixnum(signgam);
#endif
  N_D(res,value1); mv_count=2;
}

#undef D_S
#undef I_S
#undef N_D
#undef VAL_D
#undef VAL_ID

#endif # EXPORT_SYSCALLS
