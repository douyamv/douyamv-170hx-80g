// vmmchunk.cu — 分块VA预留的全量写读校验 (绕开单次大额连续VA reserve限制)
// 用法: ./vmmchunk <总GB>
// 每块: cuMemAddressReserve(256MB) + cuMemCreate(256MB) + cuMemMap + SetAccess
// 然后整块写满 -> 全量回读校验 -> churn
#include <cuda.h>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cstring>

#define CHK(x, msg) do { CUresult r_=(x); if(r_!=CUDA_SUCCESS){ const char* s_; cuGetErrorString(r_,&s_); printf("FAIL %s (%s)\n", msg, s_?s_:"?"); return 1;} } while(0)

__global__ void fillk(unsigned int* p, unsigned long long n, unsigned int base, unsigned int mode){
  unsigned long long i = (unsigned long long)blockIdx.x*blockDim.x + threadIdx.x;
  unsigned long long s = (unsigned long long)gridDim.x*blockDim.x;
  unsigned int expected;
  for(; i<n; i+=s){
    if(mode==0){ expected = base + (unsigned int)(i*2654435761u); p[i]=expected; }
  }
}
__global__ void verifyk(const unsigned int* p, unsigned long long n, unsigned int base, unsigned long long* bad){
  unsigned long long i = (unsigned long long)blockIdx.x*blockDim.x + threadIdx.x;
  unsigned long long s = (unsigned long long)gridDim.x*blockDim.x;
  for(; i<n; i+=s){
    unsigned int expected = base + (unsigned int)(i*2654435761u);
    if(p[i]!=expected) atomicAdd((unsigned long long*)bad, 1ULL);
  }
}

int main(int argc, char** argv){
  if(argc<2){ printf("usage: %s <GB>\n", argv[0]); return 2; }
  int GB = atoi(argv[1]);
  if(GB<=0 || GB>77){ printf("GB 1..77\n"); return 2; }
  const unsigned long long CHUNK = 256ULL<<20;         // 256MB
  const size_t CHUNK_U32 = CHUNK/4;
  int nchunks = (int)((GB*1ULL<<30) / CHUNK);
  printf("VMM chunked test: %d GB in %d chunks of 256MB\n", GB, nchunks);

  CHK(cuInit(0), "cuInit");
  CUdevice d; CHK(cuDeviceGet(&d,0), "cuDeviceGet");
  CUcontext ctx; cuDevicePrimaryCtxRetain(&ctx,d); CHK(cuCtxSetCurrent(ctx), "cuCtxSetCurrent");

  size_t gran=0; CUmemAllocationProp prop={};
  prop.type=CU_MEM_ALLOCATION_TYPE_PINNED; prop.location.type=CU_MEM_LOCATION_TYPE_DEVICE; prop.location.id=0;
  CHK(cuMemGetAllocationGranularity(&gran,&prop,CU_MEM_ALLOC_GRANULARITY_MINIMUM), "gran");
  printf("granularity=%zu\n", gran);

  std::vector<CUdeviceptr> va(nchunks);
  std::vector<CUmemGenericAllocationHandle> h(nchunks);

  CUmemAccessDesc acc={}; acc.location.type=CU_MEM_LOCATION_TYPE_DEVICE; acc.location.id=0; acc.flags=CU_MEM_ACCESS_FLAGS_PROT_READWRITE;

  for(int c=0;c<nchunks;c++){
    CHK(cuMemAddressReserve(&va[c], CHUNK, gran, 0, 0), "reserve");
    CHK(cuMemCreate(&h[c], CHUNK, &prop, 0), "create");
    CHK(cuMemMap(va[c], CHUNK, 0, h[c], 0), "map");
    CHK(cuMemSetAccess(va[c], CHUNK, &acc, 1), "setaccess");
    if((c&15)==0) printf("mapped %d/%d\n", c+1, nchunks);
  }
  printf("MAPPED TOTAL %d GB\n", GB);

  // phase1: 全量写满(每块互异pattern)
  for(int c=0;c<nchunks;c++){
    fillk<<<4096,256>>>((unsigned int*)va[c], CHUNK_U32, (unsigned int)(c*0x9E3779B9u), 0);
    CUresult r = cuCtxSynchronize();
    if(r!=CUDA_SUCCESS){ printf("FAIL fill sync chunk%d (err %d)\n", c, r); return 1; }
    if((c&15)==0) printf("filled %d/%d\n", c+1, nchunks);
  }
  printf("fill done\n");

  // phase2: 全量回读校验
  CUdeviceptr badbuf; CHK(cuMemAlloc(&badbuf, 8), "badbuf");
  unsigned long long hbad=0;
  int firstbad=-1, lastbad=-1, nbadchunks=0;
  for(int c=0;c<nchunks;c++){
    CHK(cuMemsetD8(badbuf,0,8), "badmemset");
    verifyk<<<4096,256>>>((const unsigned int*)va[c], CHUNK_U32, (unsigned int)(c*0x9E3779B9u), (unsigned long long*)badbuf);
    CUresult r = cuCtxSynchronize();
    if(r!=CUDA_SUCCESS){ printf("FAIL verify sync chunk%d (err %d)\n", c, r); return 1; }
    unsigned long long cb=0; CHK(cuMemcpyDtoH(&cb, badbuf, 8), "badcopy");
    if(cb){ if(firstbad<0) firstbad=c; lastbad=c; nbadchunks++; hbad+=cb; }
  }
  printf("VERIFY: bad_u32=%llu / %d GB -> %s\n", hbad, GB, hbad==0?"ALL CLEAN":"CORRUPT");
  if(hbad){
    printf("BADMAP: chunks %d..%d affected (%d/%d chunks, %.1f%%)\n",
           firstbad, lastbad, nbadchunks, nchunks, 100.0*nbadchunks/nchunks);
    printf("BADMAP: bad range = %.1fG..%.1fG\n", firstbad*0.25, (lastbad+1)*0.25);
  }

  // phase3: churn 60s (随机块重写+抽查)
  time_t t0=time(0); unsigned long long passes=0;
  while(time(0)-t0 < 60){
    int c = rand()%nchunks;
    fillk<<<1024,256>>>((unsigned int*)va[c], CHUNK_U32, (unsigned int)(c*0x9E3779B9u), 0);
    if(cuCtxSynchronize()!=CUDA_SUCCESS){ printf("FAIL churn chunk%d\n", c); return 1; }
    passes++;
  }
  printf("churn done passes=%llu\n", passes);
  printf("=== VMMCHUNK %s ===\n", hbad==0?"PASSED":"FAILED");
  // 释放全部(否则PMA累积耗尽, 影响下次运行)
  for(int c=0;c<nchunks;c++){ cuMemUnmap(va[c],CHUNK); cuMemRelease(h[c]); cuMemAddressFree(va[c],CHUNK); }
  return hbad==0?0:1;
}
