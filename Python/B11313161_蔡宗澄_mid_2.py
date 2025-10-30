import random
import statistics as st
while(True):
    a = input().split(' ') #a為輸入
    if(len(a) != 2): #輸入不是兩個
        print("輸入錯誤")
        break
    elif(not a[0].isdigit() or not a[1].isdigit()): #排除輸入非非負整數
        print("輸入錯誤")
        break

    intlist = list(map(int, a))

    if (intlist[0] >= intlist[1]): #第一個輸入的數字必須小於第二個數字
        print("輸入錯誤")
        break
    else:
        r = []
        for i in range(6):
            r1 = random.randint(intlist[0],intlist[1])
            r.append(r1)
        m = round(st.mean(r), 2)
        s = round(st.stdev(r), 2)
        print("隨機生成的 6 個整數：",r)
        print("平均數：", m)
        print("標準差：", s)
        break