#include "fatBinaryCtl.h"
#define __CUDAFATBINSECTION  ".nvFatBinSegment"
#define __CUDAFATBINDATASECTION  ".nv_fatbin"
asm(
".section .nv_fatbin, \"a\"\n"
".align 8\n"
"fatbinData:\n"
".quad 0x00100001ba55ed50,0x0000000000000960,0x0000004001010002,0x00000000000005c8\n"
".quad 0x0000000000000000,0x0000001400010007,0x0000000000000000,0x0000000000000015\n"
".quad 0x0000000000000000,0x0000000000000000,0x33010102464c457f,0x0000000000000007\n"
".quad 0x0000005000be0002,0x0000000000000000,0x0000000000000520,0x0000000000000320\n"
".quad 0x0038004000140514,0x0001000800400003,0x7472747368732e00,0x747274732e006261\n"
".quad 0x746d79732e006261,0x746d79732e006261,0x78646e68735f6261,0x666e692e766e2e00\n"
".quad 0x2e747865742e006f,0x6950746f64335a5f,0x766e2e005f535f53,0x5a5f2e6f666e692e\n"
".quad 0x5f536950746f6433,0x732e766e2e005f53,0x5a5f2e6465726168,0x5f536950746f6433\n"
".quad 0x632e766e2e005f53,0x30746e6174736e6f,0x50746f64335a5f2e,0x2e00005f535f5369\n"
".quad 0x6261747274736873,0x6261747274732e00,0x6261746d79732e00,0x6261746d79732e00\n"
".quad 0x2e0078646e68735f,0x006f666e692e766e,0x6950746f64335a5f,0x65742e005f535f53\n"
".quad 0x6f64335a5f2e7478,0x005f535f53695074,0x6f666e692e766e2e,0x50746f64335a5f2e\n"
".quad 0x6e2e005f535f5369,0x6465726168732e76,0x50746f64335a5f2e,0x6e2e005f535f5369\n"
".quad 0x6174736e6f632e76,0x64335a5f2e30746e,0x5f535f536950746f,0x006d617261705f00\n"
".quad 0x0000000000000000,0x0000000000000000,0x0000000000000000,0x000700030000003f\n"
".quad 0x0000000000000000,0x0000000000000000,0x0006000300000080,0x0000000000000000\n"
".quad 0x0000000000000000,0x0007101200000032,0x0000000000000000,0x00000000000000a8\n"
".quad 0x0000000300082304,0x0008120400000000,0x0000000000000003,0x0000000300081104\n"
".quad 0x00080a0400000000,0x0018002000000002,0x000c170400181903,0x0010000200000000\n"
".quad 0x000c17040021f000,0x0008000100000000,0x000c17040021f000,0x0000000000000000\n"
".quad 0x00041e040021f000,0x0000000000000018,0x0000000000000000,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000000,0x0000000000000000,0x0000000000000000\n"
".quad 0x00005de400000000,0x94001c0428004404,0x84009c042c000000,0x10025de22c000000\n"
".quad 0x0c019de218000000,0x2001dca318000000,0x00029de220044000,0xfc001de418000002\n"
".quad 0x80711ca328000000,0xfc71dc2320138000,0x90715ce31a8e0000,0xa0709ca320928000\n"
".quad 0x1001a1e220138000,0xfc0021e218000000,0xb070dce31bffffff,0xc0721ca320928000\n"
".quad 0x00419c8520138000,0x00229c8594000000,0xd0725ce394000000,0x00801c8520928000\n"
".quad 0x00001de794000000,0x0000000080000000,0x0000000000000000,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000000,0x0000000000000000,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000000,0x0000000300000001,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000040,0x000000000000008e,0x0000000000000000\n"
".quad 0x0000000000000001,0x0000000000000000,0x000000030000000b,0x0000000000000000\n"
".quad 0x0000000000000000,0x00000000000000ce,0x00000000000000a2,0x0000000000000000\n"
".quad 0x0000000000000001,0x0000000000000000,0x0000000200000013,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000170,0x0000000000000060,0x0000000200000002\n"
".quad 0x0000000000000008,0x0000000000000018,0x7000000000000029,0x0000000000000000\n"
".quad 0x0000000000000000,0x00000000000001d0,0x0000000000000024,0x0000000000000003\n"
".quad 0x0000000000000004,0x0000000000000000,0x7000000000000045,0x0000000000000000\n"
".quad 0x0000000000000000,0x00000000000001f4,0x0000000000000048,0x0000000700000003\n"
".quad 0x0000000000000004,0x0000000000000000,0x0000000100000073,0x0000000000000002\n"
".quad 0x0000000000000000,0x000000000000023c,0x0000000000000038,0x0000000700000000\n"
".quad 0x0000000000000004,0x0000000000000000,0x0000000100000032,0x0000000000000006\n"
".quad 0x0000000000000000,0x0000000000000274,0x00000000000000a8,0x0b00000300000003\n"
".quad 0x0000000000000004,0x0000000000000000,0x0000000500000006,0x0000000000000520\n"
".quad 0x0000000000000000,0x0000000000000000,0x00000000000000a8,0x00000000000000a8\n"
".quad 0x0000000000000008,0x0000000500000001,0x000000000000023c,0x0000000000000000\n"
".quad 0x0000000000000000,0x00000000000000e0,0x00000000000000e0,0x0000000000000008\n"
".quad 0x0000000600000001,0x0000000000000000,0x0000000000000000,0x0000000000000000\n"
".quad 0x0000000000000000,0x0000000000000000,0x0000000000000008,0x0000004801010001\n"
".quad 0x0000000000000310,0x000000400000030b,0x0000001400050000,0x0000000000000000\n"
".quad 0x0000000000002015,0x0000000000000000,0x00000000000006a4,0x0000000000000000\n"
".quad 0x762e1cf200010a13,0x35206e6f69737265,0x677261742e0a302e,0x30325f6d73207465\n"
".quad 0x7365726464612e0a,0x3620657a69735f73,0x69736918f9002f34,0x746e652e20656c62\n"
".quad 0x6f64335a5f207972,0x285f535f53695074,0x206d617261702e0a,0x5f11001a3436752e\n"
".quad 0x00222c305f3f0018,0x09f30e0022311f0d,0x722e0a7b0a290a32,0x646572702e206765\n"
".quad 0x3b3e31313c702520,0x2520323362960013,0x3662001235323c72,0x4200256472252034\n"
".quad 0x2e220061646c0a0a,0x5b202c344f001875,0x002b3b5d2d0100ab,0x2b311f03002b351f\n"
".quad 0xf403002b361f0000,0x7476630a3b5d3203,0x6f6c672e6f742e61,0x2c372100316c6162\n"
".quad 0x766f6d0a3b710037,0x2c3431b900c5752e,0x782e6469746e2520,0x6325202c357d0017\n"
".quad 0x202c364400186174,0x6c2e646172002e25,0x2c37240019732e6f,0x31723f003d02004e\n"
".quad 0x0087381105008736,0x2e6c756d0a3b34b3,0x6433004465646977,0x0a3b3482004a2c39\n"
".quad 0x260030732e646461,0x0107391100362c31,0x2c30007b02005004,0x0600f70f00265b20\n"
".quad 0x553519003b303121,0x560f001b2c322700,0x2900573332220000,0x492c332600375d32\n"
".quad 0x3634120100360f01,0x2c4601365d332900,0x005b00000f3b3320,0x34d1001238323138\n"
".quad 0x65730a203b30202c,0x094401106e2e7074,0x4d3018010f317025,0x3105f200ba321100\n"
".quad 0x6220317025400a3b,0x315f304242206172,0x716523003f0a3b30,0x003e0b002802003f\n"
".quad 0x004f31202c38315f,0x50321f0050381100,0x7b02005033130900,0x3b38a1002b331500\n"
".quad 0x696e752e6172620a,0x170a0a3b3341000f,0x2c392500cf3a1b00,0x391f0500800f00ea\n"
".quad 0x3d0201ac02090080,0x0150050195371301,0x65730a3b60001903,0x005b091203a1706c\n"
".quad 0x703a0061202c3330,0x01833411001b3031,0xc308001d30202c34,0x332b00c430312300\n"
".quad 0x110104341300843a,0x1a00af341500af32,0x1c00403413004137,0x02002c3827004037\n"
".quad 0x008e381f0500ac0f,0x2c3524004e341c04,0x8e3515008e00025d,0x4035130041361a00\n"
".quad 0x9237140040361c00,0x173414014f311901,0x2c333501502d1b00,0xc73770253c018420\n"
".quad 0x351c0400b8341f01,0x341d00b836130078,0x2533001a30130103,0x3a303168003d3670\n"
".quad 0x03ed02036674730a,0x001c3b322f008801,0x1c331f001c321200,0x34c0001c33120100\n"
".quad 0x7d0a3b7465720a3b,0x00000000000a0a0a\n"
".text\n");
#ifdef __cplusplus
extern "C" {
#endif
extern const unsigned long long fatbinData[302];
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
static const __fatBinC_Wrapper_t __fatDeviceText __attribute__ ((aligned (8))) __attribute__ ((section (__CUDAFATBINSECTION)))= 
	{ 0x466243b1, 1, fatbinData, 0 };
#ifdef __cplusplus
}
#endif
