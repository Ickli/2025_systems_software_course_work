#include <stdio.h>
#include <stdio.h>

struct Foo {
    int a;
    int b;
};

typedef struct Bar_struct {
    int a;
    int b;
} Bar;

typedef struct {
    int a;
    struct Foo b;
} AnonBar;

typedef int MY_INT;
typedef struct Foo MY_FOO;

int foo(int a) {
    printf("fooed a = %d\n", a);
    return 0;
}

int main() {
    int arr[] = { 1, 2 };
    int arr1[2] = { 1, 2 };
    int arr2[3] = { 1, 2 };
    int arr3[3] = { 1, 2 };
    int arr4[2][6] = {
    };
    int a = 69;
    char b = 12;
    int* d = &a;
    *d = 1;
    int c = a + 4 * (a + b);
    int uninit;
    MY_INT my_int;
    MY_INT my_int_init = 1;
    MY_INT my_int_arr[3] = { 1, 2, 3 };

    struct Foo foo = { 1, 2 };
    struct Foo bar = foo;
    struct Foo qux = { 1, 2 };
    
    struct Foo foo1 = { 1, 2 };
    struct Foo bar1 = foo;
    struct Foo qux1 = { 1, 2 };

    MY_FOO foo_MY = { 1, 2 };
    MY_FOO bar_MY = foo;
    MY_FOO qux_MY = { 1, 2 };
    
    MY_FOO foo1_MY = { 1, 2 };
    MY_FOO bar1_MY = foo;
    MY_FOO qux1_MY = { 1, 2 };

    Bar foo_bar = { 1, 2 };
    Bar bar_bar = foo_bar;
    Bar qux_bar = { 1, 2 };
    Bar foo1_bar = { 1, 2 };
    Bar bar1_bar = foo_bar;
    Bar qux1_bar = { 1, 2 };

    AnonBar foo_bar_anon = { 1 };
    AnonBar bar_bar_anon = foo_bar_anon;
    AnonBar qux_bar_anon = { 1 };
    AnonBar foo1_bar_anon = { 1 };
    AnonBar bar1_bar_anon = foo_bar_anon;
    AnonBar qux1_bar_anon = { 1 };

    struct Foo foos[2] = {};
    foos[0].b = 1;

    struct Foo nested_foos[2][6] = {};
    nested_foos[0][1].b = 2;
    
    struct Foo foo2 = { 1, 2 };
    struct Foo bar2 = foo;
    struct Foo qux2 = { 1, 2 };
    
    struct Foo foo3 = { 1, 2 };
    struct Foo bar3 = foo;
    struct Foo qux3 = { 1, 2 };

    // int arr5[1][6] = {};
    // int arr6[1][6] = {};
    // int arr7[1][6] = {};
    // int arr8[1][6] = {};
    // int arr9[1][6] = {};

    // a.c = 1;
    arr1[0] = 69;
    printf("%d %d %s\n", arr1[0], b, "hello!");
    printf("%d %d %s\n", arr4[0][0], foos[0].b, "hello!");
    printf("%d %d %s\n", arr4[0][0], nested_foos[0][1].b, "hello!");

    if(a + b) {
        printf("hello world!\n");
    }

    int i = 0;
    while(i < 5) {
        if(i == 3 || i == 2) {
            i = i + 1;
            continue;
        }
        printf("cycled %d\n", i);
        i = i + 1;
    }
    for(int i = 0; i < 5; i = i + 1) {
        if(i == 3) {
            continue;
        }
        printf("for cycled %d\n", i);
    }
    return 0;
}
