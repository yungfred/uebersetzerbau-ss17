#ifndef __TREE_H__
#define __TREE_H__

/* status codes */
#define LEXICAL_ERROR 1
#define SYNTAX_ERROR 2
#define SEMANTIC_ERROR 3
#define NO_MEMORY_ERROR 8
#define LABELING_ERROR 9
#define NO_FREE_REG_ERROR 10
#define TO_MANY_ARGS_ERROR 11
#define STRANGE_ERROR 99

#define PLUS 1
#define MINUS 2
#define MULT 3
#define NUMBER 4 
#define ID_READ 5
#define ARRAY_READ 6
#define BRACKET 7
#define MINUSLAST 8
#define FUNC_CALL 9
#define ARG 10
#define SAVE_REG 11

#define RDI 1
#define RSI 2
#define RDX 3
#define RCX 4
#define R8 5
#define R9 6
#define R10 7
#define R11 8

static int fixedUntilReg = 0;

struct symnode {
	char name[255];
	/* 1 = var, 2 = label */ 
	int type;

	/* pointer to the next symnode in list */
	struct symnode *next;
};

typedef struct node {
	int op;							/* node type */
	struct node *kids[2];			/* successor nodes */
									
	/* attributes of node (depending on type) */
    int reg_no;						/* register number for reg */    
	int number;						/* constant value for con */ 
	int minusCounter;
    char *id;						/* variable name */
	struct burm_state* state;		/* state variable for BURG */

	//attributes for cond
	struct node *l_expr_optree;
	struct node *r_expr_optree;

	//attributes for function calls
	int argCount;

} treenode;

typedef treenode *treenodep;
#define NODEPTR_TYPE treenodep

#define LEFT_CHILD(p) ((p)->kids[0])
#define RIGHT_CHILD(p) ((p)->kids[1])
#define STATE_LABEL(p) ((p)->state)
#define OP_LABEL(p) ((p)->op)
#define PANIC printf

treenode *newOperatorNode(int op, treenode *left, treenode *right);
treenode *newNumberNode(int number);
treenode *newIdReadNode(char *name);
treenode *newMinusLastNode(treenode *optree, int minusCounter);
treenode *newFuncCallNode(char *name, int argCount, treenode* argTree);
treenode *newSaveRegNode(void);
void printINOrder(treenode *node);
void invoke_burm(NODEPTR_TYPE root);
int getRegisterNoToVar(char *id);
int getFreeRegister(void);
char *getRegNameToRegNo(int reg_no);
void print_symboltable(struct symnode *head);
int sizeOfSymboltable(struct symnode *head);
void setParList(struct symnode *pars);

char *createJumpLabel(void);
void printLabel(char *labelName);
void evalCterm(char *op, int notCounter, char *T_lab, char *F_lab);
void saveRegisterOnStack(void);
void restoreRegisterFromStack(void);
void loadPreparedArgumentsFromStack(int argCount);

#endif
