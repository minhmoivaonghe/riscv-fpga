int main() {
    volatile int cnt = 0;                 
    for (int i = 0; i < 15; i ++)
        if (i > 5 && i < 12)
            cnt += i;
    return cnt;                       
}
