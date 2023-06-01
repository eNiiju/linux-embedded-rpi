#include <stdio.h>

#ifndef TARGET
#define TARGET "World"
#endif

int main(void)
{
    printf("Hello %s\n", TARGET);

    return 0;
}
