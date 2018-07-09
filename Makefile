CC = gcc
CFLAGS = -lfl -std=gnu99

OBJECTFILES = scanner.yy.c parser.c parser.h oxout.y oxout.l parser.output codegen.brg codegen.c codegen.o gesamt

.PHONY: all clean

all: gesamt

gesamt: scanner.yy.c parser.c codegen.o treeoperations.c
	$(CC) -o $@ $^ $(CFLAGS)

scanner.yy.c: oxout.l
	flex -o $@ $<
	
parser.c: oxout.y
	bison -v -d -o $@ $< 

oxout.l: ag.y scanner.flex
	ox $^

oxout.y: ag.y scanner.flex
	ox $^

codegen.brg: codegen.bfe
	bfe codegen.bfe > codegen.brg

codegen.c: codegen.brg
	iburg codegen.brg > codegen.c

codegen.o: codegen.c
	$(CC) -c codegen.c

clean:
	rm -f $(OBJECTFILES)
