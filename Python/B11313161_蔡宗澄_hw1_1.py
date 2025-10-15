while(True):
    a = input()
    a1 = list(reversed(a))
    if "".join(a1) == a: # list轉成string然後比較
        print(f"{a} 是迴文")
    else:
        print(f"{a} 不是迴文")