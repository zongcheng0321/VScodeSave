import random

list1 = [49, 54, 13, 25, 2, 88, 18, 71, 64, 83]
list2 = [81, 54, 87, 68, 67, 97, 85, 16, 37, 69]
a = random.choice(list1)  # 從list裡選一個元素
b = random.choice(list2)
if a > b:
    print(f"list1 元素 =  {a}\nlist2 元素 =  {b}\n{a} 大於 {b} ")
elif a < b:
    print(f"list1 元素 =  {a}\nlist2 元素 =  {b}\n{a} 小於 {b} ")
else:
    print(f"list1 元素 =  {a}\nlist2 元素 =  {b}\n{a} 等於 {b} ")