# for num in [1, 3, 5, 4, 6, 7, 8, 9, 10, 2]:
#     #if(num>5):
#     #    print(num)
#     if(num%2 ==0):
#         print(num)
num = [1, 3, 5, 4, 6, 7, 8, 9, 10, 2]
for i in [0,2,3,5]:
    print(num[i])
lst = [0, 1, 4, 6, 12, 5, 18, 7, 24, 9, 10]
for i in range(len(lst)):
    print(f"索引 {i} =",lst[i])
movie = {"名稱" : "阿凡達：水之道", "排名" : 1 , "得票率" :9.3 , "得票數": 2384}
for key,value in movie.items(): #印出dic的方法
    print(key, value)
n = 32
while(n>= 1):
    print(n)
    n = n/2
import random
r = random.randint(1,11)
while r!=6:
    print(r,"不等於6")
    r = random.randint(1,11)
#a = input()
#while a != "exit":
#    a = input()
r = random.randint(1,11)
n = int(input("n = "))
while n<r:
    print(r,"大於",n)
    r = random.randint(1,11)
r1 = random.randint(1,6)
r2 = random.randint(1,6)
while r1 != r2:
    print(r1,r2)
    r1 = random.randint(1,6)
    r2 = random.randint(1,6)