while(True):
    n = int(input("請輸入正整數n:"))
    flag1 = 0 # 紀錄 n 目前的狀態，例如：n為2的倍數及5的倍數時，2+5 = 7 所以 flag1 = 7，以此類推。
    flag2 = 0 # flag1當 n 是2的倍數或3的倍數時，會變成輸出5的倍數，所以需要多一個旗標紀錄此特別情況。
    for i in range(2,6): # 判斷n是否能跟2或3或5整除
        if i == 4:
            continue
        if i == 5:
            if flag1 == 5:
                flag2 = 1
        if n % i == 0:
            flag1 = flag1 + i
    match flag1:
        case 0:
            print(f"{n} 不是 2、3 或 5 的倍數")
        case 2:
            print(f"{n} 是 2 的倍數")
        case 3:
            print(f"{n} 是 3 的倍數")
        case 5:
            if flag2 == 1:
                print(f"{n} 是 2 和 3 的倍數")
            else:
                print(f"{n} 是 5 的倍數")
        case 7:
            print(f"{n} 是 2 和 5 的倍數")
        case 8:
            print(f"{n} 是 3 和 5 的倍數")
        case 10:
            print(f"{n} 是 2、3 和 5 的倍數")