%option noyywrap
%{
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "parser.h"
#include "tree.h"
extern int line_num;
%}

ID          [a-zA-Z][a-zA-Z0-9]*
LEXEM       ";"|"("|")"|","|":"|"="|">"|"["|"]"|"-"|"+"|"*"
digit       [0-9_]
number      {digit}+
comment     \(\*([^*]+|\*[^)*])*\*+\)
whitespace	[ \t\r]+ 
newline		[\n]

%%

end         { return END; }

return      { return RETURN; }

goto        { return GOTO; }

if          { return IF; }

var         { return VAR; }

and         { return AND; }

not         { return NOT; }

";"			{ return ';'; }
"("			{ return '('; }
")"			{ return ')'; }
","			{ return ','; }
":"			{ return ':'; }
"="			{ return '='; }
">"			{ return '>'; }
"["			{ return '['; }
"]"			{ return ']'; }
"-"			{ return '-'; }
"+"			{ return '+'; }
"*"			{ return '*'; }


"!="		{ return UNEQ; }

{number}    {
                char output[yyleng+1];
                memset(output,' ',yyleng+1);
                int output_counter = 0;
                int i = 0;
                int non_zero_seen = 0;

                for(i = 0; i < yyleng; i++){
                   //skip first zeros and underscores
                    if(!non_zero_seen){
                        if(yytext[i] == '0' || yytext[i] == '_'){
                            continue;
                        } else {
                            non_zero_seen = 1;
                        }
                    }
                    
                    //copy all valid chars
                    if(isdigit(yytext[i])){
                        output[output_counter] = yytext[i];
                        output_counter++;
                    }
                }
                if(output_counter == 0){
                    output[output_counter] = '0';
                    output_counter++;
                }
				output[output_counter] = '\0';
                //printf("num %s\n", output);
                return NUM;

				@{ @NUM.value@ = strtol(output, NULL, 10);  @}
            }

{ID}        { return ID; @{ @ID.Sname@ = strdup(yytext); @} };

{comment}   /* eat the (* *) comments */

{whitespace}	/* eat up whitespace */

{newline}	{ line_num++; }

.           { printf("Unrecognized character: %s\n", yytext);  exit(LEXICAL_ERROR); }

%%

