// modulus.cu — 无假设折叠模数测量
// 填 N 块(各256MB)独有pattern → 只重写最后一块 → 全量回查 → 被踩块下标直接给出alias距离
// 用法: ./modulus <块数>   (如 160 = 40G)
#include <cuda.h>
#include <cstdio>
#include <cstdlib>

#define CHK(x,m) do{CUresult r_=(x); if(r_!=CUDA_SUCCESS){const char*s_;cuGetErrorString(r_,&s_);printf("FAIL %s(%s)\n",m,s_?s_:"?");return 1;}}while(0)
__global__ void fillk(unsigned int*p,unsigned long long n,unsigned int v){unsigned long long i=(unsigned long long)blockIdx.x*blockDim.x+threadIdx.x,s=(unsigned long long)gridDim.x*blockDim.x;for(;i<n;i+=s)p[i]=v;}
__global__ void countk(const unsigned int*p,unsigned long long n,unsigned int v,unsigned long long*c){unsigned long long i=(unsigned long long)blockIdx.x*blockDim.x+threadIdx.x,s=(unsigned long long)gridDim.x*blockDim.x;for(;i<n;i+=s)if(p[i]!=v)atomicAdd((unsigned long long*)c,1ULL);}

int main(int argc,char**argv){
  int NC = argc>1?atoi(argv[1]):160;
  const size_t SZ=256ULL<<20,N=SZ/4;
  CHK(cuInit(0),"i");CUdevice d;CHK(cuDeviceGet(&d,0),"d");
  CUcontext c;cuDevicePrimaryCtxRetain(&c,d);CHK(cuCtxSetCurrent(c),"c");
  CUmemAllocationProp pr={};pr.type=CU_MEM_ALLOCATION_TYPE_PINNED;pr.location.type=CU_MEM_LOCATION_TYPE_DEVICE;pr.location.id=0;
  size_t g;CHK(cuMemGetAllocationGranularity(&g,&pr,CU_MEM_ALLOC_GRANULARITY_MINIMUM),"g");
  CUmemAccessDesc ac={};ac.location.type=CU_MEM_LOCATION_TYPE_DEVICE;ac.location.id=0;ac.flags=CU_MEM_ACCESS_FLAGS_PROT_READWRITE;
  static CUdeviceptr va[400];static CUmemGenericAllocationHandle hh[400];
  for(int i=0;i<NC;i++){CHK(cuMemAddressReserve(&va[i],SZ,g,0,0),"r");CHK(cuMemCreate(&hh[i],SZ,&pr,0),"c");CHK(cuMemMap(va[i],SZ,0,hh[i],0),"m");CHK(cuMemSetAccess(va[i],SZ,&ac,1),"s");}
  printf("%d chunks mapped (%.1fG)\n",NC,NC*0.25);
  for(int i=0;i<NC;i++){fillk<<<2048,256>>>((unsigned int*)va[i],N,(unsigned int)(0x1000+i));CHK(cuCtxSynchronize(),"f");}
  printf("filled unique patterns\n");
  CUdeviceptr bad;CHK(cuMemAlloc(&bad,8),"b");
  // 重写最后一块为独有新值
  fillk<<<2048,256>>>((unsigned int*)va[NC-1],N,0x7E7E7E7E);CHK(cuCtxSynchronize(),"w");
  printf("rewrote chunk %d only\n",NC-1);
  for(int i=0;i<NC;i++){
    CHK(cuMemsetD8(bad,0,8),"z");
    countk<<<2048,256>>>((const unsigned int*)va[i],N,(unsigned int)(0x1000+i),(unsigned long long*)bad);
    CHK(cuCtxSynchronize(),"v");
    unsigned long long h;CHK(cuMemcpyDtoH(&h,bad,8),"cp");
    if(h)printf("STOMPED: chunk %d (alloc-rank %d, %llu bad words)\n",i,i,h);
  }
  printf("done (no STOMPED line above = no alias at this size)\n");
  return 0;
}
