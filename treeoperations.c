#include "tree.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

treenode *newOperatorNode(int op, treenode *left, treenode *right){
	treenode *node = malloc(sizeof(treenode));
	
	if(node == NULL) {
		fprintf(stderr,"malloc failed\n");
		exit(NO_MEMORY_ERROR);
	}

	node->op = op;
	node->kids[0] = left;
	node->kids[1] = right;
	node->reg_no = 0;
	node->number = 0;
	node->minusCounter = 0;
	node->id = NULL;
	node->l_expr_optree = NULL;
	node->r_expr_optree = NULL;

	node->argCount = 0;
	
	return node;
}

treenode *newNumberNode(int number){
	treenode *node = newOperatorNode(NUMBER, NULL, NULL);
	node->number = number;
	return node;
}

treenode *newIdReadNode(char *name){
	treenode *node = newOperatorNode(ID_READ, NULL, NULL);
	node->id = name;
	return node;
}

treenode *newMinusLastNode(treenode *optree, int minusCounter){
	treenode *node = newOperatorNode(MINUSLAST, optree, NULL);
	node->minusCounter = minusCounter;
	return node;
}

treenode *newFuncCallNode(char *name, int argCount, treenode* argTree){
	treenode *node = newOperatorNode(FUNC_CALL, argTree, NULL);
	node->id = name;
	node->argCount = argCount;
	return node;
}

treenode *newSaveRegNode(void){
	treenode *node = newOperatorNode(SAVE_REG, NULL, NULL);
	return node;
}



treenode* printINOrderImpl(treenode *node, int count) {
        if(node == NULL){
                printf("warning: node is null - can not print info\n");
                return node;
        }

        printf("id: %i, node: op: %i, number: %i, id: %s, reg_no: %i\n", count, node->op, node->number, node->id, node->reg_no);
        if(node->kids[0] != NULL){
                printf("left_child of %i: \n", count);
                printINOrderImpl(node->kids[0], count+1);
        }
        if(node->kids[1] != NULL){
                printf("right_child of %i: \n", count);
                printINOrderImpl(node->kids[1], count+2);
        }
        return node;
}

void printINOrder(treenode *node){
	printINOrderImpl(node,0);
	/*
	
	if(node == NULL){
		printf("warning: node is null - can not print info\n");
		return;
	}

	if(node->kids[0] != NULL){
		printINOrder(node->kids[0]);
	}
	printf("node: op: %i, number: %i, id: %s, reg_no: %i\n", node->op, node->number, node->id, node->reg_no);
	if(node->kids[1] != NULL){
		printINOrder(node->kids[1]);
	}
	
	*/
}

static int currentReg = R11; 

int getFreeRegister(void){
	if(currentReg <= fixedUntilReg){
		currentReg = R11; //start again with R11;
	}
	if(currentReg == 0 || currentReg > 8){
		fprintf(stderr, "das sollte nicht passieren - problem mit der register belegung \n");
		exit(STRANGE_ERROR);
	}
	return currentReg--;
}

char *getRegNameToRegNo(int reg_no){
	switch(reg_no){
		case RDI: return "%rdi";
		case RSI: return "%rsi";
		case RDX: return "%rdx";
		case RCX: return "%rcx";
		case R8: return "%r8";
		case R9: return "%r9";
		case R10: return "%r10";
		case R11: return "%r11";
		default: fprintf(stderr, "error, zu register nummer %i existert kein registername\n", reg_no); exit(STRANGE_ERROR);
	}
}

struct symnode *parList = NULL;
void setParList(struct symnode *pars){
	parList = pars;

	//set fixed register
	struct symnode *p = parList;
	int counter = 0;
	while(p != NULL){
		if(p->type == 1){
			//only count the variables/parameters
			counter++;
		}
		p = p->next;
	}
	fixedUntilReg = counter;
	currentReg = R11;
}

int getRegisterNoToVar(char *id){
	struct symnode *p = parList;
	int counter = 1;
	if(parList == NULL){
		fprintf(stderr, "Achtung. parList == NULL\n");
	}
	while(p != NULL){
		if(strcmp(id,p->name) == 0){
			return counter;
		}
		if(p->type == 1){
			//only count the variables/parameters
			counter++;
		}
		p = p->next;
		if(counter > 6){
			fprintf(stderr, "error: more than 6 args -> exiting\n");
			exit(TO_MANY_ARGS_ERROR);
		}
	}
	return -1;
}

static int labelCounter = 0;

char *createJumpLabel(void){
	char *name = malloc(sizeof(char)*5);
	if(name == NULL){
		exit(NO_MEMORY_ERROR);
	}
	sprintf(name, "gen%i", labelCounter);
	labelCounter++;
	return name;
}

void printLabel(char *labelName){
	fprintf(stdout, "\tLABEL_%s:\n", labelName);
}

/* 
* we know both expr results are on top of the stack -> pop and compare them
* use highest register for comparing: 
* I chose %r10 for left Expr and %r11 for right Expr
* jg a, b = jump if b > a
* I will never understand this again..
*/
void evalCterm(char *op, int notCounter, char *T_lab, char *F_lab){
	//stack operations
	printf("\tpop %%r11\n\tpop %%r10\n");
	//temp jumper label
	char *J_lab = createJumpLabel();
	
	
	if(notCounter == 0){
		printf("\tcmp %%r11, %%r10\n\n\t###\n\t%s LABEL_%s\n\tjmp LABEL_%s\n", op, J_lab, F_lab);
		printLabel(J_lab);
	} else {
		printf("\tcmp %%r11, %%r10\n\n\t###\n\t%s LABEL_%s\n\tjmp LABEL_%s\n", op, J_lab, T_lab);
		printLabel(J_lab);
	}
	printf("\t###\n\n");
	printf("\n\n");
}

void saveRegisterOnStack(void){
	int regCount = 8;
	printf("\t#saving first %i register in reverse order onto stack\n", regCount);
	for(int i = regCount; 0 < i; i--){
		printf("\tpushq %s\n", getRegNameToRegNo(i));
	}
	printf("\t#saving finished\n");
}

void restoreRegisterFromStack(void){
	int regCount = 8;
	printf("\t#restoring first %i register from stack\n", regCount);	
	for(int i = 0; i < regCount; i++){
		printf("\tpop %s\n", getRegNameToRegNo(i+1));
	}
	printf("\t#restoring finished\n");
}

void loadPreparedArgumentsFromStack(int argCount){
	printf("\t#loading first %i arguments from stack in reverse order\n", argCount);
	for(int i = argCount; 0 < i; i--){
		printf("\tpop %s\n", getRegNameToRegNo(i));
	}
	printf("\t#loading finished\n");
}

