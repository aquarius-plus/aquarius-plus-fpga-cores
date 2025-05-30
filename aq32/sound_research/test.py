#!/usr/bin/env python3
import math
# import matplotlib.pyplot as plt

bsl = [
    round(-256 * math.log2(math.sin((x + 0.5) / 256 * (math.pi / 2))))
    for x in range(256)
]

bsp = [round((math.pow(2, x / 256) - 1) * 1024) for x in range(256)]


def sl(x):
    idx = x & 255
    if x & 256 != 0:
        idx ^= 255
    val = bsl[idx]
    if x & 512 != 0:
        val |= 0x8000
    return val


def sp(x):
    invert = x & 0x8000 != 0
    x &= 0x1FFF

    # idx = (x & 255) ^ 255
    val = ((1024 + bsp[(x & 0xFF) ^ 0xFF]) << 1) >> (x >> 8)
    if invert and val != 0:
        val = -val - 1

    return val


print("bsp", bsp)
print("bsl", bsl)

# bla = [math.sin(((x + 0.5) * math.pi) / 512) for x in range(256)]


# plt.figure()
# plt.subplot(3, 1, 1)
# plt.title("bsl")
# plt.plot(bsl)

# plt.subplot(3, 1, 2)
# plt.title("bsp")
# plt.plot(bsp)

# # plt.figure()
# # plt.plot(bla)

# plt.subplot(3, 1, 3)
# plt.title("sine")

# for j in range(0, 511, 16):
#     dinges = [sp(sl(i) + (j << 3)) for i in range(1024)]
#     # print(dinges)
#     plt.plot(dinges)

# # print(sl(0) + 260 << 3)

# plt.show()

for i in range(256):
    print(bsp[i])
