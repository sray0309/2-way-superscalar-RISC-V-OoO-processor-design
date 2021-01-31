#include <stdlib.h>

int main()
{
    int a[6];
    a[0] = 1;
    a[1] = 1;
    for(int i=0;i<5;i++)
    {
        a[i+2] = a[i+1] + a[i];
    }

    return 0;
}