# OpenWrt package repository for Intel C2558 and C2758 on Supermicro A1SRi-2558F and A1SRi-2758F

## Introduction

Then Intel Atom C2000 is a low power 22nm SoC formerly known as Rangely, based on the Silvermont architecture and specially optimized for communication and cryptographic functions. The C2558 is a four core and the C2578 is an eight core processor. Both CPUs contain specific instructions and technology for cryptographic and communications acceleration. These technologies include Intel Quick Assist (QAT), AES-NI, PCLMULQDQ (used in GCM and EC algorithms) and Secure Key (formerly Bull Mountain) for hardware generated random numbers. The integrated hardware acceleration includes support for AES, DES/3DES, Kasumi, RC4, Snow3G, MD5, SHA1, SHA2, AES-XCBC, Diffie-Hellman, RSA, DSA, ECC. The SoC has four gigabit ethernet ports and is capable of sustaining around 3 - 4 Gbps of IPsec throughput (equipped with a 10Gbps card).

This repository contains packages for the target build that can be [found at GitHub](https://github.com/dl12345/openwrt-c2xxx-subtarget).

It also contains the bondlink driver for bonding two internet links together. Please review to the [BONDING.md](https://github.com/dl12345/openwrt-packages/blob/master/BONDING.md)

