### 白癡題目 如果再凌晨-8會變負的
import datetime
def GMT(time, gmt=8):
    print(f"台灣時間 {time.hour}:{time.minute}:{time.second}")
    print(f"GMT時間 {time.hour - gmt}:{time.minute}:{time.second}")

time = datetime.datetime.now()

GMT(time)
###