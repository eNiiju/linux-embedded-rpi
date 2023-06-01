CFLAGS=-Wall -Wextra -Wno-unused-parameter

all:
	echo "Choisir hello_pc ou hello_pi"

clean:
	rm -f hello_pc hello_pi

hello_pc: hello.c
	gcc $(CFLAGS) $^ -o $@ -D 'TARGET="pc"'

hello_pi: hello.c
	$(CC) $(CFLAGS) $^ -o $@ -D 'TARGET="pi"'
