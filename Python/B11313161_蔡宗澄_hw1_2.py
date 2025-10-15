import random
while(True):
    n = int(input("請輸入正整數n:"))
    a = random.randint(0,n) 
    b = random.randint(0,n)
    print(f"a = {a}, b = {b}\na + b = {a+b}")