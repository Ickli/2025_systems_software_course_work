#include <stdlib.h>
#include <stdio.h>
#include <float.h>

int main()
{
    float f;
    double d;
    int x;
    printf("sizeof(f)=%d\tsizeof(d)=%d\n\n", sizeof(f), sizeof(d));
    d = f = FLT_MAX;
    printf("FLT_MAX : f=%g d=%g\n", f, d);
    d = f = FLT_MIN;
    printf("FLT_MIN : f=%g d=%g\n", f, d);
    d = f = FLT_EPSILON; /* Это разница между 1 и наименьшим числом с плавающей запятой типа float, которое больше 1. Нужно для сравнения между числами с плавающей запятой*/
    printf("FLT_EPSILON : f=%g d=%g\n", f, d);
    x = FLT_DIG;	/*указывает количество цифр точности с плавающей запятой.*/
    printf("FLT_DIG : %d\n", x);
    f = 12345678;
    printf("12345678 : f=%f\n", f);
    f = 87654321;	/*пояснения, почему первое значение записано точно, а второе с погрешностью*/
    printf("87654321 : f=%f\n", f);
    d = DBL_MAX;
    printf("DBL_MAX : d=%g\n", d);
    d = DBL_MIN;
    printf("DBL_MIN : d=%g\n", d);
    d = DBL_EPSILON;	/* что это, зачем нужно*/
    printf("DBL_EPSILON : d=%g\n", d);
    x = DBL_DIG;	/* что это, зачем нужно*/
    printf("DBL_DIG : %d\n", x);
    d = 1e15 + 1;
    printf("1e15+1 : d=%f\n", d);
    d = 1e16 + 1;	/*пояснения, почему первое значение записано точно, а второе с погрешностью*/
    printf("1e16+1 : d=%f\n", d);
    d = 1e20 * 1e20 + 1000 - 1e22 * 1e18; /*пояснение, почему результат оказался не соответствующим ожидаемому*/
    printf("1000 : d=%f\n", d);
    d = 1e20 * 1e20 - 1e22 * 1e18 + 1000; /*пояснение, почему результат вычислен математически правильно*/
    printf("1000 : d=%f\n", d);
    f = d = 0.3; /*пояснение, почему значения переменных не равны 0,3 и даже не совпадают между собой*/
    printf("0.3 : f=%.8f  d=%.17f\n", f, d);
    f = 0;
    while (f < 10)
        f += 0.2f;
    printf("10 : f=%f\n", f);
    d = 0;
    while (d < 10)
        d += 0.2;
    printf("10 : d=%f\n", d);
    printf ("2.2 = 2.2 : %d\n", 1.1 + 1.1 == 6.6 / 3);
    d = 1.1 + 1.1 - 6.6 / 3;
    printf ("2.2 - 2.2 = %g\n", d);
    return 0;
}

