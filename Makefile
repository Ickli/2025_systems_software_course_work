a.out: Parser.c Lexer.c
	gcc Parser.c Lexer.c -I. -g

Parser.c: bison.y
	bison bison.y -Wconflicts-sr -Wcounterexamples -v

Lexer.c: flex.l
	flex flex.l
