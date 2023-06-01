all: ncurses_hello_pc ncurses_hello_pi

ncurses_hello_pc: hello.c
	gcc $^ -o $@ -lncurses -L$(TARGET_PC)/lib

ncurses_hello_pi: hello.c
	$(CC) $^ -o $@ -lncurses -L$(TARGET_PI)/lib -I$(TARGET_PI)/include -I$(TARGET_PI)/include/ncurses

clean:
	rm -rf ncurses_hello_pc ncurses_hello_pi
