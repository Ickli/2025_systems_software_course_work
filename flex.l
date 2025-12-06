%{

#include "Parser.h"

int type_info_find(const char* name);
int typedefed_find(const char* nick);

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
operand "&"

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
kwtrue "true"
kwfalse "false"
kwbreak "break"
kwcontinue "continue"

paropen "("
parclose ")"
brackopen "["
brackclose "]"
curlyopen "{"
curlyclose "}"
operless "<"
opergreater ">"
operlesseq "<="
opergreatereq ">="
opereq "=="
operneq "!="
operandlogic "&&"
operorlogic "||"
operandbit "&"
operorbit "|"

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
{kwtrue} { return KWTRUE; }
{kwfalse} { return KWFALSE; }
{kwbreak} { return KWBREAK; }
{kwcontinue} { return KWCONTINUE; }

{paropen} { return PAROPEN; }
{parclose} { return PARCLOSE; }
{brackopen} { return BRACKOPEN; }
{brackclose} { return BRACKCLOSE; }
{curlyopen} { return CURLYOPEN; }
{curlyclose} { return CURLYCLOSE; }


{commentline} { return COMMENTLINE; }
{multicommentline} { return MULTICOMMENTLINE; }
{directiveline} { return DIRECTIVELINE; }
{id} { 
    yylval.text = strdup(yytext);
    int typedef_at = -1;
    if((typedef_at = typedefed_find(yylval.text)) >= 0) {
        yylval.num = typedef_at;
        return TYPEDEFED_TYPENAME;
    } else if(type_info_find(yylval.text) >= 0) {
        return TYPENAME;
    } else {
        return ID;
    }
}

{string_literal} {
    size_t len = strlen(yytext);
    len--; // subtract to remove final quote

    yylval.text = malloc(1024);
    memcpy(yylval.text, yytext, len);
    const char term[] = "\\0\"";
    memcpy(yylval.text + len, term, sizeof(term));

    return STRING_LITERAL; 
}
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
{operand} { yylval.text = strdup(yytext); return OPERAND; }
{operless} { return OPERLESS; }
{opergreater} { return OPERGREATER; }
{operlesseq} { return OPERLESSEQ; }
{opergreatereq} { return OPERGREATEREQ; }
{opereq} { return OPEREQ; }
{operneq} { return OPERNEQ; }
{operandlogic} { return OPERANDLOGIC; }
{operorlogic} { return OPERORLOGIC; } 
{operandbit} { return OPERANDBIT; } 
{operorbit} { return OPERORBIT; } 

{semicolon} { return SEMICOLON; }
{comma} { yylval.text = strdup(yytext); return COMMA; }

. {}

%%

int yywrap() { return 1; }
