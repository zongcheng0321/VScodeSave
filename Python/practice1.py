#info = ["admin", 12345,"中山大學人科學程",3]
#print(info[: : -1]) #step -1 => 反轉 = reverse()
lst= [2, 3, 5, 7, 11]
lst.append(4)
print('sum = ', sum(lst))
print('average = ', sum(lst)/len(lst))
lst.append(0)
s = sorted(lst)
print(lst)
print(s)
info={"姓名":"admin","學號":12345,"就瀟的學校科系":"中山大學人科學程","年級":3}
print(info)
new_grade = 5566
print(info["年級"])
info.update({"年級":new_grade})
print(info)
info = ("admin", 12345,"中山大學人科學程",3)
s1 = {2, 4, 6, 8, 10, 12} 
s2 = {3, 6, 9, 12}
print(s1&s2)
print(s1|s2)
print(s1^s2)
print("交集最大值= ",max(s1&s2),"最小值= ",min(s1&s2))#交集
print("聯集最大值= ",max(s1|s2),"最小值= ",min(s1|s2))#聯集
print("差集最大值= ",max(s1^s2),"最小值= ",min(s1^s2))#差集
