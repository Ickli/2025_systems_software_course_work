%{
// TODO: add in python static variables into the array where functions
//      are stored
// TODO: add the rest of operators and the function call operator
// TODO: add support for "int a = (1, 3);", for a comma operator.
//      Right now the issue is that it's ambiguous with arg list
// TODO: add union declaration, add union definition
// TODO: add definition of union variables
// TODO: in-function struct definitions may collide with each other
//          because of their equal name, fix it
// TODO: scoped values with the same names

// TODO: ??? add casting to void* and char*
// TODO: ??? add type punning
// TODO: ??? add cross-referencing of modules created by 
//      the transpiler
// TODO: ??? add ffi, __CFFIFUNCTION

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>
#include <stdbool.h>
#include <assert.h>
#include "DeclInfo.h"

#define YYDEBUG 1 // This is new

int yylex();
int yyerror(const char *s);
extern FILE *yyout;
extern FILE *yyin;

static int indent;
static bool is_last_decl_sized_array;
static int decl_array_size;

// Declares structs in python so that the runtime
// recognizes respective typenames.
typedef struct {
    DeclInfo decl_info;
    char* defstr;
} DeferredDeclInfo;

static DeferredDeclInfo* deferred_defs = NULL;
static size_t deferred_defs_count = 0;
static size_t deferred_defs_cap = 0;

void deferred_def_add(DeclInfo decl_info, char* defstr);
void deferred_defs_writeyyout();
void deferred_def_add_struct(char* name, char* member_list);

char* struct_create_defstr(char* name, char* member_list);

int type_info_find(const char* name);
char* typename_normalize(char* name);
char* typename_normalize_if_ptr(char* name, int is_pointer);
char* typename_normalize_ptr(char* name);

typedef struct {
    DeclInfo orig;
    char* nick;
} TypedefedPair;

static TypedefedPair* typedefed = NULL;
static size_t typedefed_count = 0;
static size_t typedefed_cap = 0;

void typedefed_add(DeclInfo orig, char* nick);
int typedefed_find(const char* nick);

// returns name of newly defined array
char* sizedarr_add_deferred_def(DeclInfo info);
// returns the outermost arrays DeclInfo, owned by deferred_defs
DeclInfo sizedarr_construct_deferred_from_sizes(
    DeclInfo sizedarr_info);
char* sizedarr_create_defstr(const char* name, const char* elemtypename, int size);
char* sizedarr_get_unique_name(char* elemtypename, size_t size);

// TODO: deprecated with stacks. remove after latest TODOs
static size_t* sizedarr_sizes = NULL;
static size_t sizedarr_sizes_count = 0;
static size_t sizedarr_sizes_cap = 0;

size_t sizedarr_size_add(size_t size);
size_t sizedarr_size_pop();

void init_struct_with_brace_init_list(
    char* varname, char* vartype, char* args);
void init_struct_with_expr(
    char* varname, char* vartype, char* expr);
void init_plain_with_plain(
    char* varname, char* pyclassname, char* vartype, char* expr);
void init_arr_with_compound(
    char* varname, char* elemtype,
    char* unwrapped_list, int array_size);

void indir_add(IndirectionArray* arr, IndirectionLink link);
IndirectionArray indir_copy(const IndirectionArray* arr, int limit);

int declinfo_is_array(const DeclInfo* info);
int declinfo_is_pointer(const DeclInfo* info);
int declinfo_array_size(const DeclInfo* info);
void declinfo_free(DeclInfo* info);

// TODO: strange things about static is_last_...
//      make it work with deferred_arrays.
//      The problem is that it is used before we've embedded
//      .array_size into decl_info
char* get_size_str_if_is_sized();
char* get_size_str(int size);

unsigned strlen_with_escaped(const char* str);

#define writeyyout(fmt, ...) \
do { \
    char* args_macroed[] = { __VA_ARGS__ }; \
    writeyyout_fn(fmt, sizeof(args_macroed)/sizeof(args_macroed[0]), ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args_macroed)/sizeof(args_macroed[0]); ++i) { \
        free(args_macroed[i]); \
    } \
} while(0)
void writeyyout_fn(const char fmt[], int count, ...);

#define writestr(str, fmt, ...) \
do { \
    char* args_macroed[] = { __VA_ARGS__ }; \
    sprintf(str, fmt, ## __VA_ARGS__); \
    for(int i = 0; i < sizeof(args_macroed)/sizeof(args_macroed[0]); ++i) { \
        free(args_macroed[i]); \
    } \
} while(0)
char* emptystr();
%}

// %glr-parser

%code requires {
#include "DeclInfo.h"
}

%union {
    char *text;
    int num;
    double floatnum;
    DeclInfo decl_info;
    struct {
        char* text;
        int is_compound;
    } init_info;
};

%header "Parser.h"
%output "Parser.c"

%token COMMENTLINE MULTICOMMENTLINE DIRECTIVELINE IDLETTER OPERARROW OPERASSIGN OPERPLUS OPERMINUS OPERSTAR OPERDIV OPERUPARROW OPERDOT SEMICOLON COMMA KWIF KWDO KWELSE KWSIZEOF KWSWITCH KWCASE KWSTRUCT KWTYPEDEF KWRETURN KWSTATIC KWEXTERN KWUNSIGNED KWWHILE KWFOR PAROPEN PARCLOSE BRACKOPEN BRACKCLOSE CURLYOPEN CURLYCLOSE KWUNION OPERAND END KWTRUE KWFALSE KWBREAK KWCONTINUE OPERLESS OPERGREATER OPERLESSEQ OPERGREATEREQ OPEREQ OPERNEQ OPERANDLOGIC OPERORLOGIC OPERANDBIT OPERORBIT
%token INT RETURN
%token <text> STRING_LITERAL KWINT KWCHAR KWLONG KWSHORT KWFLOAT KWDOUBLE KWCONST KWVOLATILE TYPENAME
%token <text> ID
%token <num> NUM_LITERAL
%token <num> TYPEDEFED_TYPENAME
%token <floatnum> FLOAT_LITERAL
%type <text> expr
%type <text> function_call_expr
%type <text> arg_list
%type <text> declare_arg_list
%type <text> opt_declare_arg_list
%type <text> declare_function_stmt
%type <text> for_stmt_part3
%type <text> for_stmt_header
%type <decl_info> declare_stmt_uninit
%type <init_info> declare_stmt_init_part
%type <init_info> declare_stmt_init_part_opt
%type <text> forw_declare_struct_stmt
%type <text> forw_declare_anon_struct_stmt
// %type <text> declare_struct_stmt
%type <text> declare_struct_field_list
%type <text> declare_struct_field
%type <text> define_function_stmt_part1
%type <text> define_struct_rhs
%type <text> brace_init_list_opt
%type <text> brace_init_list
%type <decl_info> cvless_type
%type <decl_info> cvless_type_star_opt
%type <num> sizedarr_size_opt 
%type <num> sizedarr_size 
%type <decl_info> cv_type
%type <text> unary_expr
// %type <text> declare_struct
%type <text> return_stmt
%type <decl_info> declare_stmt
%type <decl_info> declare_member
%type <decl_info> declare_member_inter
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

// %right 
%right OPERASSIGN
%left OPERORLOGIC
%left OPERANDLOGIC
%left OPERORBIT
%left OPERUPARROW
%left OPERANDBIT
%left OPEREQ OPERNEQ
%left OPERLESS OPERLESSEQ OPERGREATER OPERGREATEREQ
%left OPERPLUS OPERMINUS OPERAND
// TODO: here OPERSTAR is mult, but to deref we need to resolve
//  ambiguity between them. I think the most convenient thing is
//  to introduce a static variable in bison.y that tells what 
//  can be expected here.
//  For example, if we don't have anything on lhs of expr, it's
//  clear that we may expect only OPERSTAR as deref operator
%left OPERSTAR OPERDIV OPERMOD
// silly :! brack open is now an operator
%left OPERDOT OPERARROW BRACKOPEN

// experimenting with prec to handle ambi-ty with ID * ID
// %left MULTPREC
// %left PTRDECLPREC

%%

program:
    %empty
    | program includes 
    | program define_function_stmt
    | program declare_stmt semicolon
    | program declare_struct_stmt semicolon
    | program typedef_stmt semicolon
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

        // writeyyout frees every argument except fmt
        char* fnname_duped = strdup($1);
        writeyyout("%s = CFUNCTION__.append_function(%s)", $1, fnname_duped);
    }
    ;
define_function_stmt_part1:
    declare_function_stmt CURLYOPEN {
        $$ = malloc(1024);
        const char* defend = strchr($1, ' ');
        if(defend == NULL) {
            fprintf(stderr, "ERROR: invalid function decl stmt\n");
            abort();
        }

        defend++;
        const char* nameend = strchr(defend, '(');
        if(nameend == NULL) {
            fprintf(stderr, "ERROR: invalid function decl stmt\n");
            abort();
        }

        const size_t size = nameend - defend;
        memcpy($$, defend, size);
        $$[size] = '\0';

        writeyyout("%s\n", $1);
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
    | declare_stmt semicolon /* { writeyyout("%s\n", $1); } */
    | function_call_expr semicolon { writeyyout("%s\n", $1); }
    | expr semicolon { writeyyout("%s\n", $1); }
    | declare_struct_stmt semicolon
    | forw_declare_struct_stmt semicolon { writeyyout("%s\n", $1); }
    | if_stmt
    | while_stmt 
    | for_stmt
    | KWBREAK semicolon { writeyyout("break"); }
    | KWCONTINUE semicolon { writeyyout("raise ValueError(\"__TRNSLT_CONTINUE_SIGNAL__\")"); }
    | COMMENTLINE
    ;
declare_function_stmt:
    cv_type ID PAROPEN opt_declare_arg_list PARCLOSE {
        $$ = malloc(1024);
        writestr($$, "def %s(%s):", $2, $4);
        declinfo_free(&$1);
    }
    ;
opt_declare_arg_list:
    %empty { $$ = emptystr(); }
    | declare_arg_list { $$ = $1; }
    ;
declare_arg_list:
    declare_member {
        $$ = $1.text;
        DeclInfo info_tofree = $1;
        info_tofree.text = NULL;
        declinfo_free(&info_tofree);
    }
    | declare_arg_list COMMA declare_member {
        char* new_arg_text = $3.text;
        DeclInfo info_tofree = $3;
        info_tofree.text = NULL;
        declinfo_free(&info_tofree);

        $$ = malloc(1024);
        writestr($$, "%s, %s", $1, new_arg_text);
    }
    ;
for_stmt:
    for_stmt_header CURLYOPEN printable_stmt printable_stmt_list CURLYCLOSE {
        indent--; // for_stmt_part2, out of try block
        writeyyout("except:\n");
            indent++; // into except block
            writeyyout("pass\n");
            indent--; // out of except block
        writeyyout("finally:");
            indent++; // into finally block
            writeyyout("%s", $1);
            indent--; // out of finally block
        indent--; // for_stmt_part2, out of while block
    }
    | for_stmt_header CURLYOPEN CURLYCLOSE {
        writeyyout("pass");
        indent--; // for_stmt_part2, out of try block
        writeyyout("except:\n");
            indent++; // into except block
            writeyyout("pass\n");
            indent--; // out of except block
        writeyyout("finally:");
            indent++; // into finally block
            writeyyout("%s\n", $1);
            indent--; // out of finally block
        indent--; // for_stmt_part2, out of while block
    }
    | for_stmt_header semicolon {
        writeyyout("pass");
        indent--; // for_stmt_part2, out of try block
        writeyyout("except:\n");
            indent++; // into except block
            writeyyout("pass\n");
            indent--; // out of except block
        writeyyout("finally:");
            indent++; // into finally block
            writeyyout("%s\n", $1);
            indent--; // out of finally block
        indent--; // for_stmt_part2, out of while block
    }
    ;
for_stmt_header:
    KWFOR PAROPEN for_stmt_part1 for_stmt_part2 for_stmt_part3 PARCLOSE {
        $$ = $5;
    }
    ;
for_stmt_part1:
    expr semicolon {
        writeyyout("%s\n", $1);
    }
    | declare_stmt semicolon {
        writeyyout("\n");
    }
    | semicolon
    ;
for_stmt_part2:
    expr semicolon {
        writeyyout("while (%s).getval():\n", $1);
            indent++; 
            writeyyout("try:\n");
                indent++; 
    }
    | semicolon {
        writeyyout("while True:\n");
            indent++;
            writeyyout("try:\n");
                indent++;
    }
    ;
for_stmt_part3:
    expr {
        $$ = $1;
    }
    | %empty {
        $$ = strdup("pass");
    }
    ;
declare_stmt:
    declare_stmt_uninit declare_stmt_init_part_opt {
        if(declinfo_is_array(&$1)) {
            printf("DEBUG: %s is array\n", $1.text);
            if($2.text != NULL) {
                if(!$2.is_compound) {
                    fprintf(stderr, 
                        "ERROR: attempt to init arr with non-arr\n");
                    abort();
                }
            }
            int is_elem_pointer = 
                $1.indirection.count >= 2 && $1.indirection.items[
                    $1.indirection.count - 2].is_pointer;
            char* typename = typename_normalize_if_ptr(
                $1.typename_text, is_elem_pointer);
            init_arr_with_compound(
                $1.text, typename, 
                $2.text, declinfo_array_size(&$1)
            );
        } else if($1.is_compound) {
            if($2.is_compound) {
                init_struct_with_brace_init_list(
                    $1.text, $1.typename_text, $2.text);
            } else {
                init_struct_with_expr(
                    $1.text, $1.typename_text, $2.text);
            }
        } else if(declinfo_is_pointer(&$1)) {
            init_plain_with_plain(
                $1.text, strdup("CPTR__"), $1.typename_text, $2.text);
        } else {
            init_plain_with_plain(
                $1.text, strdup("CVAL__"), $1.typename_text, $2.text);
        }
    }
    ;
while_stmt:
    while_stmt_start printable_stmt_list CURLYCLOSE {
        indent--; // while_stmt_start, out of try block
        writeyyout("except:\n");
            indent++; // into except block
            writeyyout("pass\n");
            indent--; // out of except block
        writeyyout("finally:\n");
            indent++; // into finally block
            writeyyout("pass\n");
            indent--; // out of finally block
        indent--; // while_stmt_start, out of while block
    }
    ;
while_stmt_start:
    KWWHILE PAROPEN expr PARCLOSE CURLYOPEN {
        writeyyout("while (%s).getval():\n", $3);
        indent++; 
        writeyyout("try:\n");
        indent++;
    }
    ;
if_stmt:
    if_stmt_start printable_stmt_list CURLYCLOSE {
        indent--;
    }
    ;
if_stmt_start: 
    KWIF PAROPEN expr PARCLOSE CURLYOPEN {
        writeyyout("if (%s).getval():", $3);
        indent++;
    }
    ;
declare_stmt_init_part_opt:
    %empty { $$.text = NULL; }
    | declare_stmt_init_part { $$ = $1; }
    ;
declare_stmt_init_part:
    OPERASSIGN expr {
        $$.is_compound = false;
        $$.text = $2;
    }
    | OPERASSIGN define_struct_rhs { 
        $$.is_compound = true;
        $$.text = $2; 
    }
    ;
declare_stmt_uninit: // TODO: cascade indir
    declare_member { 
        $$ = $1;
    }
    ;
typedef_stmt:
    KWTYPEDEF cvless_type ID {
        typedefed_add($2, $3);
    }
    | KWTYPEDEF declare_struct_stmt ID {
        DeclInfo info = deferred_defs[deferred_defs_count - 1].decl_info;
        info.indirection = indir_copy(&info.indirection, -1);
        info.typename_text = strdup(info.text);
        info.text = NULL;
        typedefed_add(info, $3);
    }
    ;
declare_struct_stmt:
    forw_declare_struct_stmt CURLYOPEN declare_struct_field_list CURLYCLOSE {
        if(type_info_find($1) >= 0) {
            fprintf(stderr, "redefinition of structure %s\n", $1);
            abort();
        }
    
        deferred_def_add_struct($1, $3);
    }
    | forw_declare_anon_struct_stmt CURLYOPEN declare_struct_field_list CURLYCLOSE {
        if(type_info_find($1) >= 0) {
            fprintf(stderr, "redefinition of structure %s\n", $1);
            abort();
        }
    
        deferred_def_add_struct($1, $3);
    }
    ;
declare_struct_field_list:
    declare_struct_field semicolon {
        $$ = $1;
    }
    | declare_struct_field_list declare_struct_field semicolon {
        $$ = malloc(1024);
        writestr($$, "%s, %s", $1, $2);
    }
    ;
declare_struct_field:
    declare_member {
        $$ = malloc(1024);
        char* typedesc = NULL;
        // for an array and a ptr it is elemtypename
        char* typename = $1.typename_text;
        char* str_arrsize = strdup("None");
        
        if(declinfo_is_array(&$1)) {
            typedesc = strdup("CSIZEDARRAY__");

            const int arrsize = declinfo_array_size(&$1);
            if(arrsize != 0) {
                str_arrsize = realloc(str_arrsize, 1024);
                sprintf(str_arrsize, "%d", arrsize);
            }
        } else if(declinfo_is_pointer(&$1)) {
            typedesc = strdup("CPTR__");
        } else if($1.is_compound) {
            typedesc = strdup("__STRUCT_STRING_NOT_USED_IN_FIELD_FACTORY__");
        } else {
            typedesc = strdup("CVAL__");
        }

        writestr($$, "FIELD_FACTORY__(\"%s\", \"%s\", \"%s\", %s)", $1.text, typename, typedesc, str_arrsize);
    }
    ;
declare_member:
    declare_member_inter {
        $$ = $1;

        DeclInfo d = $1;
        int has_array = false;
        for(int i = 0; i < $$.indirection.count; ++i) {
            if(!$$.indirection.items[i].is_pointer) {
                has_array = true;
                break;
            }
        }

        if(has_array) {
            if(declinfo_is_array(&$$)) {
                DeclInfo arr_info = 
                    sizedarr_construct_deferred_from_sizes($1);

                free($$.typename_text);
                // copying elemtypename;
                // we'll construct array's full name later.
                $$.typename_text = strdup(arr_info.typename_text);
                $$.indirection = indir_copy(&arr_info.indirection, -1);
            } else {
                // TODO: latest.
                sizedarr_construct_deferred_from_sizes($1);
            }
        }
    }
    ;
declare_member_inter:
    cv_type ID {
        $$ = $1;
        $$.text = $2;
    }
    | declare_member_inter sizedarr_size {
        $$ = $1;
        const int size = $2;

        IndirectionLink link = {0};
        link.is_pointer = false;
        link.array_size = size;
        indir_add(&$$.indirection, link);
    }
    ;
forw_declare_struct_stmt:
    KWSTRUCT ID { $$ = $2; }
    ;
forw_declare_anon_struct_stmt:
    KWSTRUCT {
        static int free_index = 0;
        $$ = malloc(1024);
        sprintf($$, "trnslt__anon_struct_%d__", free_index);
        free_index++;
    }
    ;
define_struct_rhs:
    CURLYOPEN brace_init_list_opt CURLYCLOSE {
        $$ = $2;
    }
    ;
brace_init_list_opt:
    %empty { $$ = NULL; }
    | brace_init_list { $$ = $1; }
    ;
brace_init_list:
    expr { $$ = $1; }
    | brace_init_list COMMA expr {
        $$ = malloc(1024);
        writestr($$, "%s, %s", $1, $3);
    }
    ;
sizedarr_size_opt:
    %empty { $$ = -1; }
    | sizedarr_size { $$ = $1; }
    ;
sizedarr_size:
    BRACKOPEN NUM_LITERAL BRACKCLOSE {
        $$ = $2;
    }
    | BRACKOPEN BRACKCLOSE {
        $$ = 0;
    }
    ;
cv_type:
    cvless_type { 
        $$ = $1;
    }
    | KWCONST cvless_type { 
        $$ = $2;
    }
    | KWVOLATILE cvless_type { 
        $$ = $2;
    }
    | KWCONST KWVOLATILE cvless_type { 
        $$ = $3;
    }
    | KWVOLATILE KWCONST cvless_type { 
        $$ = $3;
    }
    ;
cvless_type:
    KWINT      {
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
    }
    | KWCHAR   {
        $$ = (DeclInfo){0};
        $$.typename_text = typename_normalize($1); 
    }
    | KWLONG   {
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
    }
    | KWSHORT  {
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
    }
    | KWFLOAT  {
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
    }
    | KWDOUBLE {
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
    }
    | KWSTRUCT TYPENAME { 
        $$ = (DeclInfo){0};
        $$.typename_text = $2; 
        $$.is_compound = true;
    }
    | TYPENAME { 
        $$ = (DeclInfo){0};
        $$.typename_text = $1;
        $$.is_compound = true;
    }
    | TYPEDEFED_TYPENAME { 
        $$ = typedefed[$1].orig;
        $$.typename_text = strdup($$.typename_text);
        $$.indirection = indir_copy(&$$.indirection, -1);
    }
    | cvless_type OPERSTAR {
        $$ = $1;
        IndirectionLink link = {0};
        link.is_pointer = true;
        indir_add(&$$.indirection, link);
    }
    ;
   ;
cvless_type_star_opt:
    %empty     { $$.is_pointer = false; $$.is_compound = false; }
    | OPERSTAR { $$.is_pointer = true; $$.is_compound = false; }
expr:
    ID  
    | bin_expr
    | unary_expr
    | par_expr
    | STRING_LITERAL {
        $$ = malloc(1024);

        // -2 for quotes
        const unsigned len = strlen_with_escaped($1) - 2;

        char* name = sizedarr_get_unique_name("signed char", len);
        int is_array_defined = type_info_find(name) >= 0;
        /*
        int is_array_defined = false;
        for(int i = 0; i < deferred_defs_count; ++i) {
            DeclInfo info = deferred_defs[i].decl_info;
            if(
                declinfo_is_array(&info)
                && declinfo_array_size(&info) == len
                && strcmp(info.typename_text, "signed char") == 0
            ) {
                is_array_defined = true;
                break;
            }
        }
        */
        if(!is_array_defined) {
            DeclInfo str_info = {0};
            str_info.text = name;
            str_info.typename_text = strdup("signed char");
                IndirectionLink link = {0};
                link.array_size = len;
                indir_add(&str_info.indirection, link);
            sizedarr_add_deferred_def(str_info);
        } else {
            free(name);
        }

        char* str_len = malloc(1024);
        sprintf(str_len, "%d", len);

        writestr(
            $$, 
            "CSIZEDARRAY__(%s, \"signed char\", %s)",
            $1, 
            str_len
            // get_size_str_if_is_sized()
        );
    }
    | NUM_LITERAL {
        $$ = malloc(1024);
        sprintf($$, "CVAL__(%d, \"int\")", $1);
    }
    | FLOAT_LITERAL {
        $$ = malloc(1024);
        sprintf($$, "CVAL__(%lf, \"float\")", $1);
    }
    | KWTRUE {
        $$ = strdup("CVAL__(1, \"int\")");
    }
    | KWFALSE {
        $$ = strdup("CVAL__(0, \"int\")");
    }
    ;
unary_expr:
    OPERAND expr { 
        $$ = malloc(1024);
        writestr($$, "trnslt_ptr(%s)", $2);
    }
    | OPERSTAR expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_deref(%s)", $2);
    }
    ;
bin_expr:
    expr OPERARROW ID {
        $$ = malloc(1024);
        writestr($$, "(%s).%s", $1, $3);
    }
    | expr OPERASSIGN expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_assign(%s, %s)", $1, $3);
        free($2);
    }
    | expr OPERPLUS expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_plus(%s, %s)", $1, $3);
        free($2);
    }
    | expr OPERMINUS expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_minus(%s, %s)", $1, $3);
        free($2);
    }
    | expr OPERDIV expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_div(%s, %s)", $1, $3);
        free($2);
    }
    | expr OPERUPARROW expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_xor(%s, %s)", $1, $3);
        free($2);
    }
    | expr OPERDOT ID {
        $$ = malloc(1024);
        writestr($$, "(%s).%s", $1, $3);
        free($2);
    }
    | expr OPERSTAR expr {
        $$ = malloc(1024);
        writestr($$, "trnslt_mult(%s, %s)", $1, $3);
        free($2);
    }
    | expr BRACKOPEN expr BRACKCLOSE {
        $$ = malloc(1024);
        writestr($$, "trnslt_index(%s, %s)", $1, $3);
    }
    | expr OPERLESS expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() < (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPERGREATER expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() > (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPERLESSEQ expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() <= (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPERGREATEREQ expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() >= (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPEREQ expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() == (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPERNEQ expr {
        $$ = malloc(1024);
        writestr($$, 
            "CVAL__(int((%s).getval() != (%s).getval()), \"int\")", 
            $1, $3);
    }
    | expr OPERANDLOGIC expr {
        $$ = malloc(1024);
        writestr($$,
            "CVAL__(int((%s).getval() and (%s).getval()), \"int\")",
            $1, $3);
    }
    | expr OPERORLOGIC expr {
        $$ = malloc(1024);
        writestr($$,
            "CVAL__(int((%s).getval() or (%s).getval()), \"int\")",
            $1, $3);
    }
    | expr OPERANDBIT expr {
        $$ = malloc(1024);
        writestr($$,
            "CVAL__(int((%s).getval() & (%s).getval()), \"int\")",
            $1, $3);
    }
    | expr OPERORBIT expr {
        $$ = malloc(1024);
        writestr($$,
            "CVAL__(int((%s).getval() | (%s).getval()), \"int\")",
            $1, $3);
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
        writestr($$, "trnslt_call(%s, %s)", $1, $3);
    }
    ;
arg_list:
    expr {
        $$ = $1;
    }
    | arg_list COMMA expr {
        $$ = malloc(1024);
        writestr($$, "%s, trnslt_arg(%s)", $1, $3);
    }
    ;
semicolon: SEMICOLON
    ;
%%

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

void deferred_def_add(DeclInfo decl_info, char* defstr) {
    if(deferred_defs_count + 1 > deferred_defs_cap) {
        if(deferred_defs_cap == 0) { deferred_defs_cap = 16; }

        deferred_defs = realloc(deferred_defs, sizeof(deferred_defs[0]) * deferred_defs_cap * 2);
        if(deferred_defs == NULL) {
            fprintf(stderr, "out of memory\n");
            abort();
        }

        deferred_defs_cap *= 2;
    }
    DeferredDeclInfo* dinfo = &deferred_defs[deferred_defs_count];
    dinfo->decl_info = decl_info;
    dinfo->defstr = defstr;
    deferred_defs_count++;
}

void typedefed_add(DeclInfo orig, char* nick) {
    if(typedefed_count + 1 > typedefed_cap) {
        if(typedefed_cap == 0) { typedefed_cap = 16; }

        typedefed = realloc(typedefed, sizeof(typedefed[0]) * typedefed_cap * 2);
        if(typedefed == NULL) {
            fprintf(stderr, "out of memory\n");
            abort();
        }

        typedefed_cap *= 2;
    }
    TypedefedPair* pair = &typedefed[typedefed_count];
    pair->orig = orig;
    pair->nick = nick;
    typedefed_count++;
}

int typedefed_find(const char* nick) {
    for(int i = 0; i < typedefed_count; ++i) {
        if(strcmp(nick, typedefed[i].nick) == 0) {
            return i;
        }
    }
    return -1;
}

DeclInfo typedefed_copy_decl_info(int at) {
    if(at < 0) {
        fprintf(stderr, "ERROR: attempt to clone decl info at < 0 index\n");
        abort();
    }
    DeclInfo newinfo = typedefed[at].orig;
    newinfo.text = strdup(newinfo.text);
    newinfo.typename_text = strdup(newinfo.typename_text);
    return newinfo;
}

void deferred_def_add_struct(char* name, char* member_list) {
    DeclInfo info = {0};
    info.is_compound = true;
    info.text = name;
    
    char* defstr = struct_create_defstr(strdup(name), member_list);
    deferred_def_add(info, defstr);
}

void deferred_defs_writeyyout() {
    for(int i = 0; i < deferred_defs_count; ++i) {
        DeferredDeclInfo* def = &deferred_defs[i];
        if(def->defstr != NULL) {
            writeyyout("%s\n", def->defstr);
        }
        free(def->decl_info.text);
        free(def->decl_info.typename_text);
    }
}

int type_info_find(const char* name) {
    for(int i = 0; i < deferred_defs_count; ++i) {
        if(strcmp(name, deferred_defs[i].decl_info.text) == 0) {
            return i; 
        }
    }
    return -1;
}

char* typename_normalize_if_ptr(char* name, int is_pointer) {
    if(!is_pointer) { return name; }
    return typename_normalize_ptr(name);
}

char* typename_normalize_ptr(char* name) {
    if(strcmp(name, "void*") == 0) {
        fprintf(stderr, "ERROR: attempt to normalize 'void*'\n");
        abort();
    }
    free(name);
    return strdup("void*");
}

size_t sizedarr_size_add(size_t size) {
    if(sizedarr_sizes_count + 1 > sizedarr_sizes_cap) {
        if(sizedarr_sizes_cap == 0) { sizedarr_sizes_cap = 16; }

        sizedarr_sizes = realloc(sizedarr_sizes, sizeof(sizedarr_sizes[0]) * sizedarr_sizes_cap * 2);
        if(sizedarr_sizes == NULL) {
            fprintf(stderr, "out of memory\n");
            abort();
        }

        sizedarr_sizes_cap *= 2;
    }
    sizedarr_sizes[sizedarr_sizes_count] = size;
    sizedarr_sizes_count++;
    return sizedarr_sizes[sizedarr_sizes_count - 1];
}

size_t sizedarr_size_pop() {
    if(sizedarr_sizes_count == 0) {
        fprintf(stderr, "ERROR: sizedarr_sizes underflow\n");
        abort();
    }
    sizedarr_sizes_count--;
    return sizedarr_sizes[sizedarr_sizes_count];
}

DeclInfo sizedarr_construct_deferred_from_sizes(
    DeclInfo sizedarr_info
) {
    /*
        construct name
        if name is already defined:
            do not redefine it
        else:
            define it to deferred_defs

        if stack is empty:
            current array is the outermost.
            construct from it DeclInfo and return it
        else:
            elemtypename = cur.array's name
    */
    if(sizedarr_info.indirection.count == 0) {
        fprintf(stderr, "ERROR: attempt to account for arrays "
            "in an array-empty declaration");
        abort();
    }

    DeclInfo cur_info = {0};
    cur_info.typename_text = strdup(sizedarr_info.typename_text);
    cur_info.is_union = sizedarr_info.is_union;
    cur_info.is_compound = sizedarr_info.is_compound;

    int is_name_unused = false;

    for(int i = 0; i < sizedarr_info.indirection.count; ++i) {
        if(i != 0) {
            if(is_name_unused) {
                cur_info.typename_text = cur_info.text;
            } else {
                cur_info.typename_text = strdup(cur_info.text);
            }
        }
        is_name_unused = false;

        IndirectionLink* link = &sizedarr_info.indirection.items[i];

        if(link->is_pointer) {
            free(cur_info.text);
            cur_info.text = strdup("void*");
            is_name_unused = true;
            continue; 
        }

        int arrsize = link->array_size;
        cur_info.text = sizedarr_get_unique_name(
            cur_info.typename_text, arrsize);

        int arr_found = type_info_find(cur_info.text);
        if(arr_found >= 0) {
            cur_info = deferred_defs[arr_found].decl_info;
            continue;
        }

        cur_info.indirection = indir_copy(
            &sizedarr_info.indirection, i+1
        );

        deferred_def_add(
            cur_info, 
            sizedarr_create_defstr(
                cur_info.text, cur_info.typename_text, arrsize)
        );
    }

    if(is_name_unused) { // last name was unused -> is pointer
        free(cur_info.text);
        // to ensure that the type is not used as an array name
        cur_info.text = NULL;
    }

    return cur_info;
}

char* sizedarr_create_defstr(const char* name, const char* elemtypename, int size) {
    char* defstr = malloc(1024);

    sprintf(
        defstr,
        "gstructdefs__.account_new_array_def(\"%s\", \"%s\", %d)\n",
        name,
        elemtypename,
        size
    );
    return defstr;
}

char* get_size_str_if_is_sized() {
    if(is_last_decl_sized_array) {
        return get_size_str(decl_array_size);
    }
    char* str = malloc(sizeof("None"));
    strcpy(str, "None");
    return str;
}

char* sizedarr_get_unique_name(char* elemtypename, size_t size) {
    char* name = malloc(1024);
    sprintf(name, "trnslt__sizedarr__%s__%zu__", elemtypename, size);
    // free(elemtypename);
    return name;
}

char* sizedarr_add_deferred_def(DeclInfo info) {
    if(!declinfo_is_array(&info)) {
        fprintf(stderr, "ERROR: attempt to add deferred arr definition with non-arr declinfo\n");
        abort();
    }
    /*
    if(info.text != NULL) {
        fprintf(stderr, "ERROR: attempt to pass declinfo which has ID in it: %s\n", info.text);
        abort();
    }
    */
    if(declinfo_array_size(&info) == 0) {
        fprintf(stderr, "ERROR: attempt to add sizedarr definition without size specified");
        abort();
    }
    if(info.text == NULL) {
        info.text = sizedarr_get_unique_name(
            info.typename_text, declinfo_array_size(&info));
    }

    char* defstr = sizedarr_create_defstr(
        info.text, info.typename_text, declinfo_array_size(&info));

    deferred_def_add(info, defstr);
    return info.text;
}

char* get_size_str(int size) {
    char* str = malloc(1024);
    sprintf(str, "%d", size);
    return str;
}

char* typename_normalize(char* name) {
    if(strcmp(name, "char") == 0) {
        free(name);
        return strdup("signed char");
    }
    return name;
}

void init_struct_with_brace_init_list(
    char* varname,
    char* vartype,
    char* args
) {
    char* compound_args_with_comma = malloc(1024);
    if(args != NULL) {
        writestr(
            compound_args_with_comma, ", %s", args);
    } else {
        compound_args_with_comma[0] = '\0';
        free(args);
    }

    writeyyout(
        "%s = gstructdefs__.get_type(\"%s\")(None, True, None%s)",
        varname,
        vartype,
        compound_args_with_comma
    );
}

void init_struct_with_expr(
    char* varname, 
    char* vartype, 
    char* expr
) {
    writeyyout(
        "%s = gstructdefs__.get_type(\"%s\")(%s, True)",
        varname,
        vartype,
        expr
    );
}

void init_plain_with_plain(
    char* varname, 
    char* pyclassname,
    char* vartype,
    char* expr
) {
    char* dupname = NULL;
    if(expr != NULL) {
        dupname = strdup(varname);
    }

    writeyyout(
        "%s = %s(UNINIT__(), \"%s\")",
        varname,
        pyclassname,
        vartype
    );

    if(dupname != NULL) { 
        int saved_indent = indent;
        indent = 0;
        writeyyout("; trnslt_assign(%s, %s)", dupname, expr); 
        indent = saved_indent;
    }
}

void init_arr_with_compound(
    char* varname, 
    char* elemtype,
    char* unwrapped_list,
    int array_size
) {
    if(array_size == 0 
        && (unwrapped_list == NULL || strlen(unwrapped_list) == 0)) {
        fprintf(
            stderr, 
            "ERROR: attempt to declare uninit-ed unsized arr\n"
            "   TODO: outside of a function it must work\n"
        );
        abort();
    }

    if(unwrapped_list == NULL) { unwrapped_list = strdup(""); }

    char* str_array_size = malloc(1024);
    if(array_size == 0) { sprintf(str_array_size, "None"); }
    else { sprintf(str_array_size, "%d", array_size); }

    writeyyout(
        "%s = CSIZEDARRAY__([%s], \"%s\", %s)",
        varname,
        unwrapped_list,
        elemtype,
        str_array_size
    );
}

unsigned strlen_with_escaped(const char* str) {
    unsigned len = 0;
    int is_escaped = false;

    while(true) {
        switch(*str) {
        case '\0': { return len; } break;
        case '\\': {
            if(is_escaped) { len++; }
            is_escaped = !is_escaped;
        } break;
        default: { 
            is_escaped = false;
            len++; 
        } break;
        } // switch

        str++;
    } // while
}

#define FILE_POST_PY_PATH "post.py"

void writeyyout_post_py() {
    static char buf[1024];
    FILE* file_post_py = fopen(FILE_POST_PY_PATH, "r+");
    if(file_post_py == NULL) { 
        fprintf(stderr, "ERROR: can't open "FILE_POST_PY_PATH"\n");
        abort();
    }
    do {
        int have_read = fread(buf, sizeof(buf[0]), sizeof(buf), file_post_py);
        fwrite(buf, 1, have_read, yyout);
    } while(!feof(file_post_py));
}

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

    writeyyout_post_py();

    do
    {
        yyparse();
    }while (!feof(yyin));

    deferred_defs_writeyyout();

    writeyyout("if __name__ == \"__main__\":\n    main()");

    return 0;
}

char* struct_create_defstr(char* name, char* list) {
    char* defstr = malloc(1024);
    writestr(defstr, "gstructdefs__.account_new_structure_def(\"%s\", %s)", name, list);
    return defstr;
}

void indir_add(IndirectionArray* arr, IndirectionLink link) {
    if(arr->count + 1 > arr->cap) {
        if(arr->cap == 0) { arr->cap = 16; }

        arr->items = realloc(arr->items, sizeof(arr->items[0]) * arr->cap * 2);
        if(arr->items == NULL) {
            fprintf(stderr, "out of memory\n");
            abort();
        }

        arr->cap *= 2;
    }

    int array_bottom = -1;

    // if we have several array elems at the top, we append the new
    // one at the bottom of the sequence
    if(!link.is_pointer 
        && arr->count != 0 
        && !arr->items[arr->count - 1].is_pointer
    ) {
        array_bottom = 0;
        for(int bottom = arr->count - 1; bottom >= 0; --bottom) {
            if(arr->items[bottom].is_pointer) { 
                array_bottom = bottom + 1;
                break;
            }
        }
    }

    IndirectionLink* new_at = NULL;
    if(array_bottom != -1) {
        new_at = arr->items + array_bottom;
        memmove(new_at + 1, new_at, 
            sizeof(arr->items[0]) * (arr->count - array_bottom));
    } else {
        new_at = arr->items + arr->count;
    }

    printf("DEBUG: pushing size %d\n", link.array_size);
    *new_at = link;
    arr->count++;
}

IndirectionArray indir_copy(const IndirectionArray* arr, int limit) {
    IndirectionArray newarr = *arr;

    if(limit == 0 || arr->cap == 0) { return newarr; }

    if(limit == -1 || arr->count < limit) { limit = arr->count; }
    newarr.items = malloc(sizeof(arr->items[0]) * arr->cap);
    memcpy(newarr.items, arr->items, sizeof(arr->items[0]) * limit);
    return newarr;
}

int declinfo_is_array(const DeclInfo* info) {
    const IndirectionArray* arr = &info->indirection;
    return arr->count != 0 
        && !arr->items[arr->count - 1].is_pointer;
}
int declinfo_is_pointer(const DeclInfo* info) {
    const IndirectionArray* arr = &info->indirection;
    return arr->count != 0 && arr->items[arr->count - 1].is_pointer;
}

int declinfo_array_size(const DeclInfo* info) {
    if(!declinfo_is_array(info)) {
        fprintf(stderr, 
            "ERROR: attempt to take array size of non-array");
        abort();
    }
    const IndirectionArray* arr = &info->indirection;
    return arr->items[arr->count - 1].array_size;
}

void declinfo_free(DeclInfo* info) {
    free(info->text);
    free(info->typename_text);
    free(info->indirection.items);
    *info = (DeclInfo){0};
}
