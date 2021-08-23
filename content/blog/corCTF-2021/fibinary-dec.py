fib = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

def f2c(f):
    n = 0
    for i in range(len(f)):
        if f[i] == '1':
            n += fib[len(fib)-i-1]
    print(n)
    return chr(n)

enc = open('flag.enc', 'r').read()
dec = ''
for f in enc.split():
	dec += f2c(f)

print(dec)