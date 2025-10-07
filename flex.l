%{

/*
enum {
COMMENTLINE,
MULTICOMMENTLINE,
DIRECTIVELINE,
IDLETTER,
ID,

STRING_LITERAL,
NUM_LITERAL,
FLOAT_LITERAL,

OPERARROW,
OPERASSIGN,
OPERPLUS,
OPERMINUS,
OPERSTART,
OPERDIV,
OPERCOMMA,
OPERUPARROW,
OPERDOT,

SEMICOLON,
COMMA,

KWIF,
KWDO,
KWELSE,
KWSIZEOF,
KWSWITCH,
KWCASE,
KWSTRUCT,
KWTYPEDEF,
KWRETURN,
KWSTATIC,
KWEXTERN,
KWCONST,
KWUNSIGNED,
KWWHILE,
KWFOR,
KWINT,
KWCHAR,
KWLONG,
KWSHORT,
KWFLOAT,
KWDOUBLE,

PAROPEN,
PARCLOSE,
BRACKOPEN,
BRACKCLOSE,
CURLYOPEN,
CURLYCLOSE,
};
*/

#include "Parser.h"

char localtext[4096];

%}

%option outfile= "Lexer.c" header-file="Lexer.h"

commentline \/\/.*$
multicommentline \/\*.*\*\/
directiveline #.*$
idletter [a-zA-Z]|_
digit [0-9]
printf "printf"
id {idletter}({idletter}|{digit})*

string_literal \"((\\\")|[^\n\"])*?\"
num_literal [0-9]+
float_literal ([0-9])?\.[0-9]+f?

opermod "%"
operarrow "->"
operassign "="
operplus "+"
operminus "-"
operstar "*"
operdiv "/"
operuparrow "^"
operdot "."

semicolon ";"
comma ","

kwif "if"
kwdo "do"
kwelse "else"
kwsizeof "sizeof"
kwswitch "switch"
kwcase "case"
kwstruct "struct"
kwunion "union"
kwtypedef "typedef"
kwreturn "return"
kwstatic "static"
kwextern "extern"
kwconst "const"
kwvolatile "volatile"
kwunsigned "unsigned"
kwwhile "while"
kwfor "for"
kwint "int"
kwchar "char"
kwlong "long"
kwshort "short"
kwfloat "float"
kwdouble "double"

paropen "("
parclose ")"
brackopen "["
brackclose "]"
curlyopen "{"
curlyclose "}"

%%

{kwif} { return KWIF; }
{kwdo} { return KWDO; }
{kwelse} { return KWELSE; }
{kwsizeof} { return KWSIZEOF; }
{kwswitch} { return KWSWITCH; }
{kwcase} { return KWCASE; }
{kwstruct} { return KWSTRUCT; }
{kwunion} { return KWUNION; }
{kwtypedef} { return KWTYPEDEF; }
{kwreturn} { return KWRETURN; }
{kwstatic} { return KWSTATIC; }
{kwextern} { return KWEXTERN; }
{kwconst} { yylval.text = strdup(yytext); return KWCONST; }
{kwvolatile} { yylval.text = strdup(yytext); return KWVOLATILE; }
{kwunsigned} { return KWUNSIGNED; }
{kwwhile} { return KWWHILE; }
{kwfor} { return KWFOR; }
{kwint} { yylval.text = strdup(yytext); return KWINT; }
{kwchar} { yylval.text = strdup(yytext); return KWCHAR; }
{kwlong} { yylval.text = strdup(yytext); return KWLONG; }
{kwshort} { yylval.text = strdup(yytext); return KWSHORT; }
{kwfloat} { yylval.text = strdup(yytext); return KWFLOAT; }
{kwdouble} { yylval.text = strdup(yytext); return KWDOUBLE; }

{paropen} { return PAROPEN; }
{parclose} { return PARCLOSE; }
{brackopen} { return BRACKOPEN; }
{brackclose} { return BRACKCLOSE; }
{curlyopen} { return CURLYOPEN; }
{curlyclose} { return CURLYCLOSE; }


{commentline} { return COMMENTLINE; }
{multicommentline} { return MULTICOMMENTLINE; }
{directiveline} { return DIRECTIVELINE; }
{id} { yylval.text = strdup(yytext); return ID; }

{string_literal} { printf("%s\nLITTT!!!\n", yytext); strcpy(yylval.text, yytext); return STRING_LITERAL; }
{num_literal} { yylval.num = atoi(yytext); return NUM_LITERAL; }
{float_literal} { yylval.floatnum = atof(yytext); return FLOAT_LITERAL; }

{opermod} { yylval.text = strdup(yytext); return OPERMOD; }
{operarrow} { yylval.text = strdup(yytext); return OPERARROW; }
{operassign} { yylval.text = strdup(yytext); return OPERASSIGN; }
{operplus} { yylval.text = strdup(yytext); return OPERPLUS; }
{operminus} { yylval.text = strdup(yytext); return OPERMINUS; }
{operstar} { yylval.text = strdup(yytext); return OPERSTAR; }
{operdiv} { yylval.text = strdup(yytext); return OPERDIV; }
{operuparrow} { yylval.text = strdup(yytext); return OPERUPARROW; }
{operdot} { yylval.text = strdup(yytext); return OPERDOT; }

{semicolon} { return SEMICOLON; }
{comma} { yylval.text = strdup(yytext); return COMMA; }

. {}

%%

int yywrap() { return 1; }
