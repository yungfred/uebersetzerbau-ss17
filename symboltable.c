#include <stdio.h>
#include "tree.h"

void print_symboltable(struct symnode *head){
	struct symnode *p = head;
	while(p != NULL){
		fprintf(stdout, "(%s,%i), ", p->name, p->type);
		p = p->next;
	}
	fprintf(stdout, "\n");
}

struct symnode *deepCopy_symboltable(struct symnode *head){
	if (head == NULL){
		return NULL;
	}

    struct symnode* result = malloc(sizeof(struct symnode));
	if(result == NULL){
		fprintf(stderr, "error with malloc\n");
		exit(NO_MEMORY_ERROR);
	}
    //result->value = list->value;
	strcpy(result->name,head->name);
	result->type = head->type;
    result->next = deepCopy_symboltable(head->next);
    return result;

}

void assert_noNameDup(struct symnode *head1, struct symnode *head2){
	if(head1 == NULL || head2 == NULL){
		return;
	}

	struct symnode *p1 = head1;
	struct symnode *p2 = head2;

	while(p1 != NULL){
		while(p2 != NULL){
			if(strcmp(p1->name,p2->name) == 0){
				fprintf(stderr, "double defined name: %s\n", p2->name);
				exit(SEMANTIC_ERROR);
			}
			p2 = p2->next;
		}
		//set p2 back to head
		p2 = head2;
		p1 = p1->next;
	}
}

struct symnode *merge_symboltable(struct symnode *head1, struct symnode *head2){
	struct symnode *head1_copy = deepCopy_symboltable(head1);
	struct symnode *head2_copy = deepCopy_symboltable(head2);

	//fprintf(stdout, "\n\n");
	if(head1 == NULL){
		//fprintf(stdout, "head1 == null: merge_result = ");
		//print_symboltable(head2);
		return head2;
	}
	if(head2 == NULL){
		//fprintf(stdout, "head2 == null: merge_result = ");
		//print_symboltable(head1);
		return head1;
	}
	//fprintf(stdout, "\n\n");

	assert_noNameDup(head1,head2);
	

	//goto last element of head1 list
	struct symnode *p = head1_copy;
	while(p->next != NULL){
		p = p->next;
	}
	//link the lists
	p->next = head2_copy;

	//fprintf(stdout, "\n\n====\n");
	//fprintf(stdout, "merged\n");
	//print_symboltable(head1);
	//fprintf(stdout, "and\n");
	//print_symboltable(head2);
	//fprintf(stdout, "to:\n");
	//print_symboltable(head1_copy);
	//fprintf(stdout, "====\n");
	return head1_copy;
}

struct symnode *newNode(char name[255], int type){
	struct symnode *node = malloc(sizeof(struct symnode));
	if(node == NULL){
		fprintf(stderr, "no memory for malloc -> exiting\n");
		exit(NO_MEMORY_ERROR);
	}
	strcpy(node->name, name);
	node->type = type;
	
	//fprintf(stdout, "created node %s\n",node->name);
	return node;
}


int assert_contains(struct symnode *head, char name[255], int type){
	struct symnode *p = head;
	//fprintf(stdout, "check if the following symtable contains %s\n", name);
	//fprintf(stdout, "symtable : ");
	//print_symboltable(head);

	if(head == NULL){
		fprintf(stderr, "access to undefined variable: %s\n", name);
		exit(SEMANTIC_ERROR);
	}

	while(p->next != NULL){
		if((strcmp(p->name, name) == 0) && (p->type == type)){
			return 1;
		}
		p = p->next;
	}
	//check the last item here
	if((strcmp(p->name, name) == 0) && (p->type == type)){
		return 1;
	}
	fprintf(stderr, "access to undefined name: %s, type: %i\n", name, type);
	exit(SEMANTIC_ERROR);
}

int sizeOfSymboltable(struct symnode *head){
	struct symnode *p = head;
	int counter = 0;
	while(p != NULL){
		counter++;
		p = p->next;
	}
	return counter;
}
