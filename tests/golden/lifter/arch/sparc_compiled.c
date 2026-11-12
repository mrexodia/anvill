// Source of the sparc32_compiled and sparc64_compiled golden cases: small
// functions compiled with clang -O2 for SPARC (V8) and SPARC V9, chosen to
// exercise instruction semantics (shifts, logic, multiply and divide,
// sign- and zero-extending loads, narrow stores, floating-point conversion,
// arithmetic and comparison, conditional selection and a switch). They call
// nothing and use no globals or constant pools, so the object file has no
// relocations and its .text can be used as is.
//
//   tests/golden/tools/assemble.py --no-link --triple sparc-linux-gnu \
//       tests/golden/lifter/arch/sparc_compiled.c

int shifts_logic(int a, int b) { return ((a << 3) ^ (b >> 2)) | (a & ~b); }

unsigned shift_right(unsigned a, unsigned n) { return a >> (n & 31); }

int mul_div(int a, int b) { return a * b + a / b + a % b; }

unsigned udiv(unsigned a, unsigned b) { return a / b; }

int load_extend(signed char *p, short *q, unsigned char *r) {
  return p[1] + q[2] + r[3];
}

void store_narrow(char *p, short *q, int v) {
  p[0] = (char) v;
  q[1] = (short) (v >> 8);
}

int float_to_int(float x) { return (int) x; }

double int_to_double(int a) { return a; }

int float_math(float a, float b) { return (int) (a * b + a); }

int float_less(float a, float b) { return a < b ? 10 : 20; }

int select_max(int a, int b) { return a > b ? a : b; }

int switch_case(int x) {
  switch (x) {
    case 0: return 11;
    case 1: return 22;
    case 5: return 33;
    case 9: return 44;
    default: return 55;
  }
}
