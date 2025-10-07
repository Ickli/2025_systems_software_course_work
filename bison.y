%{
// TODO: add the rest of operators and the function call operator
// TODO: add support for "int a = (1, 3);", for a comma operator.
//      Right now the issue is that it's ambiguous with arg list
// TODO: add struct declaration, add struct definition
// TODO: add definition of struct variables
// TODO: add union declaration, add union definition
// TODO: add definition of union variables
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define YYDEBUG 1 // This is new

int yylex();
int yyerror(const char *s);
extern FILE *yyout;
extern FILE *yyin;

static int indent;
#define writeyyout(fmt, ...) \
do { \
    char* args[] = { __VA_ARGS__ }; \
    writeyyout_fn(fmt, sizeof(args)/sizeof(args[0]), ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args)/sizeof(args[0]); ++i) { \
        free(args[i]); \
    } \
} while(0)
void writeyyout_fn(const char fmt[], int count, ...);

#define writestr(str, fmt, ...) \
do { \
    char* args[] = { __VA_ARGS__ }; \
    sprintf(str, fmt, ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args)/sizeof(args[0]); ++i) { \
        free(args[i]); \
    } \
} while(0)
void writeyyout_fn(const char fmt[], int count, ...);
char* emptystr();
%}

%glr-parser

%union {
    char *text;
    int num;
    double floatnum;
    struct {
        int type;
        union {
            int num;
        };
    } intern_expr_value;
};

%header "Parser.h"
%output "Parser.c"

%token COMMENTLINE MULTICOMMENTLINE DIRECTIVELINE IDLETTER OPERARROW OPERASSIGN OPERPLUS OPERMINUS OPERSTAR OPERDIV OPERUPARROW OPERDOT SEMICOLON COMMA KWIF KWDO KWELSE KWSIZEOF KWSWITCH KWCASE KWSTRUCT KWTYPEDEF KWRETURN KWSTATIC KWEXTERN KWUNSIGNED KWWHILE KWFOR PAROPEN PARCLOSE BRACKOPEN BRACKCLOSE CURLYOPEN CURLYCLOSE KWUNION
%token INT RETURN
%token <text> STRING_LITERAL KWINT KWCHAR KWLONG KWSHORT KWFLOAT KWDOUBLE KWCONST KWVOLATILE
%token <text> ID
%token <num> NUM_LITERAL
%token <floatnum> FLOAT_LITERAL
%type <text> expr
%type <text> function_call_expr
%type <text> arg_list
%type <text> declare_arg_list
%type <text> opt_declare_arg_list
%type <text> declare_function_stmt
%type <text> declare_stmt_uninit
%type <text> declare_stmt_init
%type <text> declare_struct
%type <text> return_stmt
%type <text> declare_stmt
%type <text> bin_expr
%type <text> par_expr
%type <text> OPERARROW
%type <text> OPERASSIGN
%type <text> OPERPLUS
%type <text> OPERMINUS
%type <text> OPERSTAR
%type <text> OPERDIV
%type <text> OPERUPARROW
%type <text> OPERDOT
%type <text> OPERMOD
%type <text> COMMA

%left OPERDOT OPERARROW
// %right 
%left OPERSTAR OPERDIV OPERMOD
%left OPERPLUS OPERMINUS
%left OPERUPARROW
%right OPERASSIGN

%%
program:
    %empty
    | program includes 
    | program define_function_stmt
    | program declare_stmt semicolon
    ;

includes:
    DIRECTIVELINE
    ;
return_stmt:
    KWRETURN expr {
        $$ = malloc(1024);
        writestr($$, "return %s", $2);
    }
    ;
define_function_stmt:
    define_function_stmt_part1 printable_stmt_list CURLYCLOSE {
        --indent;
    }
    ;
define_function_stmt_part1:
    declare_function_stmt CURLYOPEN {
        writeyyout("%s", $1);
        ++indent;
    }
    ;
printable_stmt_list:
    printable_stmt
    | printable_stmt_list printable_stmt
    ;
printable_stmt:
    declare_function_stmt semicolon { writeyyout("%s\n", $1); }
    | return_stmt semicolon { writeyyout("%s\n", $1); }
    | declare_stmt semicolon { writeyyout("%s\n", $1); }
    | function_call_expr semicolon { writeyyout("%s\n", $1); }
    | expr semicolon { writeyyout("%s\n", $1); }
    ;
declare_function_stmt:
    cv_type ID PAROPEN opt_declare_arg_list PARCLOSE {
        $$ = malloc(1024);
        writestr($$, "def %s(%s):", $2, $4);
    }
    ;
opt_declare_arg_list:
    %empty { $$ = emptystr(); }
    | declare_arg_list { $$ = $1; }
declare_arg_list:
    cv_type ID {
        $$ = $2;
    }
    | declare_arg_list COMMA cv_type ID {
        $$ = malloc(1024);
        writestr($$, "%s, %s", $1, $4);
    }
    ;
declare_stmt:
    declare_stmt_init
    | declare_stmt_uninit
    ;
declare_stmt_uninit:
    cv_type ID { 
        $$ = malloc(1024);
        writestr($$, "%s", $2);
    }
    ;
declare_stmt_init:
    cv_type ID OPERASSIGN expr { 
        $$ = malloc(1024);
        writestr($$, "%s = %s", $2, $4);
    }
cv_type:
    cv_type_part cvless_type
    ;
cvless_type:
    KWINT      
    | KWCHAR   
    | KWLONG   
    | KWSHORT  
    | KWFLOAT  
    | KWDOUBLE 
    | ID
   ;
cv_type_part:
    const_type_part volatile_type_part
    ;
const_type_part:
    %empty | KWCONST
    ;
volatile_type_part:
    %empty | KWVOLATILE
    ;
expr:
    ID
    | bin_expr
    | par_expr
    | STRING_LITERAL
    | NUM_LITERAL {
        $$ = malloc(1024);
        sprintf($$, "%d", $1);
    }
    | FLOAT_LITERAL {
        $$ = malloc(1024);
        sprintf($$, "%lf", $1);
    }
    ;
bin_expr:
    expr OPERARROW expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    | expr OPERASSIGN expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    | expr OPERPLUS expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    | expr OPERMINUS expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    | expr OPERDIV expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    | expr OPERUPARROW expr {
        $$ = malloc(1024);
        writestr($$, "%s%s%s", $1, $2, $3);
    }
    | expr OPERDOT expr {
        $$ = malloc(1024);
        writestr($$, "%s%s%s", $1, $2, $3);
    }
    | expr OPERSTAR expr {
        $$ = malloc(1024);
        writestr($$, "%s %s %s", $1, $2, $3);
    }
    ;
par_expr:
    PAROPEN expr PARCLOSE {
        $$ = malloc(1024);
        writestr($$, "(%s)", $2);
    }
    ;
function_call_expr:
    expr PAROPEN arg_list PARCLOSE {
        $$ = malloc(1024);
        writestr($$, "%s(%s)", $1, $3);
    }
    ;
arg_list:
    expr {
        $$ = $1;
    }
    | arg_list COMMA expr {
        $$ = malloc(1024);
        writestr($$, "%s, %s", $1, $3);
    }
    ;
define_struct_stmt:
    define_struct_stmt_part1 define_member_list CURLYCLOSE {
        --indent;
    }
    ;
define_struct_stmt_part1:
    KWSTRUCT ID CURLYOPEN {
        writeyyout("class %s:\n", $2);
        ++indent;
        writeyyout("def __init__(self");
    }
    ;
define_member_list:
    define_member {
        writeyyout("%s", $1);
    }
    | define_member_list COMMA define_member {
        writeyyout("%s", $3);
    }
    ;
define_member:
    cv_type ID { $$ = $2; }
    ;
declare_struct_stmt:
    KWSTRUCT ID { $$ = $2; }
    ;
semicolon: SEMICOLON
    ;
%%

int main(int argc, char* argv[]) {
    if(argc <= 2) { 
        fprintf(stderr, "Usage: provide file names for input and output\n");
        return 1;
    }
    yyout = fopen(argv[2], "w+");

    yydebug = 1;

    FILE * pt = fopen(argv[1], "r+" );
    if(!pt)
    {
        fprintf(stderr, "Error: can't open '%s\n'", argv[1]);
        return 1;
    }
    yyin = pt;
    do
    {
        yyparse();
    }while (!feof(yyin));

}

int yyerror(const char* s){
    fprintf(stderr, "ERROR: %s\n", s);
    return 0;
}

#define INDENT_STR "    "
void writeyyout_fn(const char fmt[], int count, ...) {
    static char fmt_indented[1024];
    fmt_indented[0] = '\0';
    for(int i = 0; i < indent; ++i) {
        strcat(fmt_indented, INDENT_STR);
    }
    strcat(fmt_indented, fmt);

    va_list args;
    va_start(args, count);
    vfprintf(yyout, fmt_indented, args);
    va_end(args);
}

char* emptystr() {
    return (char*)calloc(1, 1);
}
