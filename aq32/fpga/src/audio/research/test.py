#!/usr/bin/env python3
import math
import matplotlib.pyplot as plt

lut_logsin = [
    round(-256 * math.log2(math.sin((x + 0.5) / 256 * (math.pi / 2))))
    for x in range(256)
]

lut_exp = [round((math.pow(2, x / 256) - 1) * 1024) for x in range(256)]


def logsin_lookup(phase):
    idx = phase & 255
    if phase & 256 != 0:
        idx ^= 255
    val = lut_logsin[idx]
    if phase & 512 != 0:
        val |= 0x8000
    return val


def sp(x):
    invert = x & 0x8000 != 0
    x &= 0x1FFF

    # idx = (x & 255) ^ 255
    val = ((1024 + lut_exp[(x & 0xFF) ^ 0xFF]) << 1) >> (x >> 8)
    if invert and val != 0:
        val = -val - 1

    return val


print("lut_exp", lut_exp)
print("lut_logsin", lut_logsin)

# bla = [math.sin(((x + 0.5) * math.pi) / 512) for x in range(256)]


plt.figure()
plt.subplot(3, 1, 1)
plt.title("lut_logsin")
plt.plot(lut_logsin)

plt.subplot(3, 1, 2)
plt.title("lut_exp")
plt.plot(lut_exp)

# plt.figure()
# plt.plot(bla)

plt.subplot(3, 1, 3)
plt.title("sine")

for j in range(0, 511, 16):
    dinges = [sp(logsin_lookup(i) + (j << 3)) for i in range(1024)]
    # print(dinges)
    plt.plot(dinges)

# print(logsin_lookup(0) + 260 << 3)

plt.show()
