%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "symboltable.c"
	#include "tree.h"
	extern int yylex(void);
	int yyerror(const char *s);
	int line_num = 1;

	struct symnode *temp_symtable = NULL;
%}

%token ID
%token NUM
%token END
%token RETURN
%token GOTO
%token IF
%token VAR
%token AND
%token NOT
%token UNEQ

@attributes { struct symnode *Ihead; treenode *optree; int argCounter; } argList
@attributes { struct symnode *Ihead; } Lexpr
@attributes { struct symnode *Ihead; struct symnode *Shead; } Stat Stats
@attributes { struct symnode *Shead; } Labeldefs Labeldef Pars Funcdef
@attributes { treenode *optree; struct symnode *Ihead; } Expr Term addList multList
@attributes { treenode *optree; treenode *termOptree; struct symnode *Ihead; int minusCounter; } minusList
@attributes { int value; } NUM
@attributes { char *Sname; } ID
@attributes { struct symnode *Ihead; char *T_lab; char *F_lab; int notCounter; } CtermList Cterm Cond

//left-to-right preorder traversal
@traversal @preorder LRPre
//left-to-right preorder traversal
@traversal @preorder codegen

%start Program

%{
%}

%%
Program : Program Funcdef ';'
		@{
		@}
        | /* empty */
        ;


Funcdef : ID '(' ')' Stats END /* Funktionsdefinition */
		@{
			@i @Stats.Ihead@ = NULL;
			@i @Funcdef.Shead@ = @Stats.Shead@;
			@LRPre temp_symtable = @Stats.Shead@;
			@codegen printf(".globl %s\n%s:\n", @ID.Sname@, @ID.Sname@);
			@codegen setParList(@Funcdef.Shead@);		
		@}
		| ID '(' Pars ')' Stats END
		@{
			@i @Stats.Ihead@ = @Pars.Shead@;
			@i @Funcdef.Shead@ = merge_symboltable(@Pars.Shead@,@Stats.Shead@);
			@LRPre temp_symtable = @Stats.Shead@;
			@codegen printf(".globl %s\n%s:\n", @ID.Sname@, @ID.Sname@);
			@codegen setParList(@Funcdef.Shead@);		
		@}
		| ID '(' Pars ',' ')' Stats END /* with dangling comma */
		@{
			@i @Stats.Ihead@ = @Pars.Shead@;
			@i @Funcdef.Shead@ = merge_symboltable(@Pars.Shead@,@Stats.Shead@);
			@LRPre temp_symtable = @Stats.Shead@;
			@codegen printf(".globl %s\n%s:\n", @ID.Sname@, @ID.Sname@);
			@codegen setParList(@Funcdef.Shead@);			
		@}
        ;

Pars    : Pars ',' ID
		@{
			@i @Pars.0.Shead@ = merge_symboltable(@Pars.1.Shead@, newNode(@ID.Sname@,1));
		@}
        | ID
		@{
			@i @Pars.0.Shead@ = newNode(@ID.Sname@,1);
		@}
        ;

Stats   : Stats Labeldefs Stat ';'
		@{
			/* set inherited attributes */
			@i @Stat.Ihead@ = merge_symboltable(
				@Stats.0.Ihead@,
				merge_symboltable(@Labeldefs.Shead@, @Stats.1.Shead@)
			);

			@i @Stats.1.Ihead@ = @Stats.0.Ihead@;
			/* set return value */
			@i @Stats.0.Shead@ = merge_symboltable(
				@Stats.1.Shead@,
				merge_symboltable(@Stat.Shead@, @Labeldefs.Shead@)
			);
			
			//@LRPre fprintf(stdout, "lrpre LD.Shead: "); print_symboltable(@Labeldefs.Shead@);
		@}
        | /* empty */
		@{
			@i @Stats.0.Shead@ = NULL;
		@}
        ;

Labeldefs   : Labeldefs Labeldef
			@{
				@i @Labeldefs.0.Shead@ = merge_symboltable(@Labeldefs.1.Shead@,@Labeldef.Shead@);
			@}
            | /* empty */
			@{
				@i @Labeldefs.0.Shead@ = NULL;
			@}
            ;

Labeldef: ID ':' /* Labeldefinition */
		@{
			@i @Labeldef.Shead@ = newNode(@ID.Sname@, 2);
			
			@codegen printLabel(@ID.Sname@);
		@}
        ;

Stat    : RETURN Expr
		@{
			@i @Stat.Shead@ = NULL;
			@i @Expr.Ihead@ = @Stat.Ihead@;
			//@codegen printINOrder(@Expr.optree@);
			@codegen invoke_burm(@Expr.optree@);
			@codegen printf("\tpop %%rax\n");
			@codegen printf("\tret\n");
			//@codegen printf("tree after reducing:\n"); printINOrder(@Expr.optree@);
		@}
        | GOTO ID
		@{ 
			@i @Stat.Shead@ = NULL;
			@LRPre assert_contains(temp_symtable, @ID.Sname@, 2);
			
			@codegen printf("\tjmp LABEL_%s\n", @ID.Sname@);
		@}
        | IF Cond GOTO ID
		@{ 
			@i @Stat.Shead@ = NULL;
			@i @Cond.Ihead@ = @Stat.Ihead@;
			@LRPre assert_contains(temp_symtable, @ID.Sname@, 2);
			
			//labels for overall true / overall false
			@i @Cond.T_lab@ = @ID.Sname@;
			@i @Cond.F_lab@ = createJumpLabel();
			@i @Cond.notCounter@ = 0;
			@codegen @revorder (1) printf("\t#final true jump\n\tjmp LABEL_%s\n\n", @ID.Sname@);
			@codegen @revorder (1) printLabel(@Cond.F_lab@);
		@}
        | VAR ID '=' Expr /* Variablendefinition */
		@{
			/* add var definition to symbol table */
			@i @Expr.Ihead@ = @Stat.Ihead@;
			@i @Stat.Shead@ = newNode(@ID.Sname@,1);
			//@codegen printINOrder(@Expr.optree@);
			@codegen invoke_burm(@Expr.optree@);
			/* we have the variable in the parList - we can just lookup the register number */
			@codegen printf("\tpop %s\n", getRegNameToRegNo(getRegisterNoToVar(@ID.Sname@)));
		@}
        | Lexpr '=' Expr /* Zuweisung */
		@{ 
			@i @Expr.Ihead@ = @Stat.Ihead@;
			@i @Lexpr.Ihead@ = @Stat.Ihead@;
			@i @Stat.Shead@ = NULL;
			
			/* write the Expr value onto the stack, it will be used it in Lexpr afterwards */
			@codegen invoke_burm(@Expr.optree@);
		@}
        | Term
		@{
			@i @Term.Ihead@ = @Stat.Ihead@;
			@i @Stat.Shead@ = NULL;
			
			@codegen invoke_burm(@Term.optree@);
			//delete the result from the stack
			@codegen printf("\taddq $ 8, %%rsp\n");
		@}
        ;


Cond    : Cterm CtermList
		@{ 
			@i @Cterm.Ihead@ = @Cond.Ihead@;
			@i @CtermList.Ihead@ = @Cond.Ihead@;
			
			@i @Cterm.T_lab@ = @Cond.T_lab@;
			@i @Cterm.F_lab@ = @Cond.F_lab@;
			@i @CtermList.T_lab@ = @Cond.T_lab@;
			@i @CtermList.F_lab@ = @Cond.F_lab@;

			@i @Cterm.notCounter@ = @Cond.notCounter@;
			@i @CtermList.notCounter@ = @Cond.notCounter@;
		@}
        | NOT Cterm
		@{
			@i @Cterm.Ihead@ = @Cond.Ihead@;
			
			//no SWAP!
			@i @Cterm.T_lab@ = createJumpLabel();
			@i @Cterm.F_lab@ = @Cond.F_lab@;
			@i @Cterm.notCounter@ = (@Cond.notCounter@ + 1);
			
			@codegen @revorder (1) printf("\t#if all in not(B) are true (false point):\n");
			@codegen @revorder (1) printf("\tjmp LABEL_%s", (@Cond.notCounter@ > 0 ? @Cond.T_lab@ : @Cond.F_lab@));
			@codegen @revorder (1) printf("\n\t#if one in not(B) is false (true point):\n");
			@codegen @revorder (1) printLabel(@Cterm.T_lab@);
		@}
        ;

CtermList   : AND Cterm CtermList
			@{ 
				@i @CtermList.1.Ihead@ = @CtermList.0.Ihead@;
				@i @Cterm.Ihead@ = @CtermList.0.Ihead@;

				//Kontrollfluss-Methode (siehe VO-Skriptum)
				@i @Cterm.T_lab@ = @CtermList.0.T_lab@;
				@i @Cterm.F_lab@ = @CtermList.0.F_lab@;
				@i @CtermList.1.T_lab@ = @CtermList.0.T_lab@;
				@i @CtermList.1.F_lab@ = @CtermList.0.F_lab@;

				@i @Cterm.notCounter@ = @CtermList.0.notCounter@;
				@i @CtermList.1.notCounter@ = @CtermList.0.notCounter@;
			@}
            | /* empty */
            ;

Cterm   : '(' Cond ')'
		@{ 
			@i @Cond.Ihead@ = @Cterm.Ihead@;
			
			@i @Cond.T_lab@ = @Cterm.T_lab@;
			@i @Cond.F_lab@ = @Cterm.F_lab@;

			@i @Cond.notCounter@ = @Cterm.notCounter@;
		@}
        | Expr UNEQ Expr
		@{
			@i @Expr.0.Ihead@ = @Cterm.Ihead@;
			@i @Expr.1.Ihead@ = @Cterm.Ihead@;

			@codegen invoke_burm(@Expr.0.optree@);
			@codegen invoke_burm(@Expr.1.optree@);
			
			//similar to Expr '>' Expr
			@codegen evalCterm("jne", @Cterm.notCounter@, @Cterm.T_lab@, @Cterm.F_lab@);
		@}
        | Expr '>' Expr
		@{
			@i @Expr.0.Ihead@ = @Cterm.Ihead@;
			@i @Expr.1.Ihead@ = @Cterm.Ihead@;
			
			@codegen invoke_burm(@Expr.0.optree@);
			@codegen invoke_burm(@Expr.1.optree@);
			
			@codegen evalCterm("jg", @Cterm.notCounter@, @Cterm.T_lab@, @Cterm.F_lab@);
		@}
        ;

Lexpr   : ID /* schreibender Variablenzugriff */
		@{ 
			@LRPre assert_contains(@Lexpr.Ihead@, @ID.Sname@,1);

			/* we know the Expr we want to assign to the ID is onto the stack 
			* => pop the item into the right register (symtable lookup)
			* (same as VAR definition) */
			@codegen printf("\tpop %s\n", getRegNameToRegNo(getRegisterNoToVar(@ID.Sname@)));
		@}
        | Term '[' Expr ']' /* schreibender Arrayzugriff */
		@{
			@i @Term.Ihead@ = @Lexpr.Ihead@;
			@i @Expr.Ihead@ = @Lexpr.Ihead@;
			
			@codegen invoke_burm(@Term.optree@);
			@codegen invoke_burm(@Expr.optree@);
			/* stack now looks like this: > R_Expr > Term > L_Expr
			* pop into highest register => r11 = L_Expr, r10 = Term, r9 = R_Expr 
			* Array = Term + 8*Expr
			*/
			@codegen printf("\t#array write access\n");
			@codegen printf("\tpop %%r11\n\tpop %%r10\n\tpop %%r9\n");
			@codegen printf("\tmovq %%r9, (%%r10,%%r11,8)\n\n");
		@}
        ;

Expr    : Term /* single term without any lists */ 
		@{
			@i @Term.Ihead@ = @Expr.Ihead@;
			@i @Expr.optree@ = @Term.optree@;
		@}
		| Term addList
		@{
			@i @addList.Ihead@ = @Expr.Ihead@;
			@i @Term.Ihead@ = @Expr.Ihead@;
			@i @Expr.optree@ = newOperatorNode(PLUS, @addList.optree@, @Term.optree@);
		@}
        | Term multList
		@{
			@i @multList.Ihead@ = @Expr.Ihead@;
			@i @Term.Ihead@ = @Expr.Ihead@;
			@i @Expr.optree@ = newOperatorNode(MULT, @multList.optree@, @Term.optree@);
		@}
        | minusList Term
		@{
			@i @minusList.Ihead@ = @Expr.Ihead@;
			@i @Term.Ihead@ = @Expr.Ihead@;
			@i @minusList.termOptree@ = @Term.optree@;
			@i @Expr.optree@ = @minusList.optree@;
			@i @minusList.minusCounter@ = 0;
		@}
        ;

addList : addList '+' Term
		@{ 
			@i @addList.1.Ihead@ = @addList.0.Ihead@;
			@i @Term.Ihead@ = @addList.0.Ihead@;
			@i @addList.0.optree@ = newOperatorNode(PLUS, @addList.1.optree@, @Term.optree@);
		@}
        | '+' Term
		@{
			@i @Term.Ihead@ = @addList.Ihead@;
			@i @addList.optree@ = @Term.optree@;
		@}
        ;

multList: multList '*' Term
		@{ 
			@i @multList.1.Ihead@ = @multList.0.Ihead@;
			@i @Term.Ihead@ = @multList.0.Ihead@;
			@i @multList.optree@ = newOperatorNode(MULT, @multList.1.optree@, @Term.optree@);
		@}
        | '*' Term
		@{
			@i @Term.Ihead@ = @multList.Ihead@;
			@i @multList.optree@ = @Term.optree@;
		@}
        ;

minusList   : minusList '-'
			@{ 
				@i @minusList.1.Ihead@ = @minusList.0.Ihead@;
				@i @minusList.1.termOptree@ = @minusList.0.termOptree@;
				@i @minusList.0.optree@ = newOperatorNode(MINUS, @minusList.1.optree@, NULL);
				@i @minusList.1.minusCounter@ = @minusList.0.minusCounter@ + 1;
			@}
            | '-'
			@{
				@i @minusList.optree@ = newMinusLastNode(@minusList.termOptree@, @minusList.0.minusCounter@ + 1);
			@}
            ;

Term    : '(' Expr ')'
		@{
			@i @Expr.Ihead@ = @Term.Ihead@;
			@i @Term.optree@ = newOperatorNode(BRACKET, @Expr.optree@, NULL);
		@}
        | NUM
		@{
			@i @Term.optree@ = newNumberNode(@NUM.value@);
		@}
        | Term '[' Expr ']' /* lesender Arrayzugriff */
		@{
			@i @Term.1.Ihead@ = @Term.0.Ihead@;
			@i @Expr.Ihead@ = @Term.0.Ihead@;
			@i @Term.0.optree@ = newOperatorNode(ARRAY_READ, @Term.1.optree@, @Expr.optree@);
		@}
        | ID /* lesender Variablenzugriff */
		@{
			@LRPre assert_contains(@Term.Ihead@,@ID.Sname@,1);
			@i @Term.optree@ = newIdReadNode(@ID.Sname@);
		@}
        | ID '(' argList ')' /* Funktionsaufruf */
		@{ 
			@i @argList.Ihead@ = @Term.Ihead@;
			@i @Term.optree@ = newFuncCallNode(@ID.Sname@, @argList.argCounter@, @argList.optree@);
		@}
        | ID '(' argList ',' ')' /* with dangling comma */
		@{ 
			@i @argList.Ihead@ = @Term.Ihead@;
			@i @Term.optree@ = newFuncCallNode(@ID.Sname@, @argList.argCounter@, @argList.optree@);
		@}
        | ID '(' ')' /* empty */
		@{
			@i @Term.optree@ = newFuncCallNode(@ID.Sname@, 0, newSaveRegNode());
		@}
        ;

argList : argList ',' Expr
		@{ 
			@i @argList.1.Ihead@ = @argList.0.Ihead@;
			@i @Expr.Ihead@ = @argList.0.Ihead@;

			@i @argList.0.argCounter@ = @argList.1.argCounter@ + 1;
			@i @argList.0.optree@ = newOperatorNode(ARG, @argList.1.optree@, @Expr.optree@);
		@}
        | Expr
		@{
			@i @Expr.Ihead@ = @argList.0.Ihead@;
			
			@i @argList.0.argCounter@ = 1;
			@i @argList.0.optree@ = newOperatorNode(ARG, 
				newSaveRegNode() , @Expr.optree@);
		@}
        ;

%%

int main(int argc, char **argv) {
	return yyparse();
}

int yyerror(const char *s) {
	printf("%s at line %i\n", s, line_num);
	exit(SYNTAX_ERROR);
}
