#include <stdio.h>
#include <stdint.h>
#include <malloc.h>

uintptr_t __stack_chk_guard = 0xdeadbeef;
extern char __end[] __attribute__ ((aligned (4)));

void __stack_chk_fail(void) {
    while (1) {
        // infinite loop of death
    }
}

void* sbrk(intptr_t increment) {
    return (void*) -1;
}

int main () {
    //char str[128];
    //void *foo = malloc(128);
    //snprintf(str, sizeof str, "Hello, world!\n");
    return 0;
}
