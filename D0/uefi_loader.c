#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/BaseMemoryLib.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>

#define D0_HANDOFF_MAGIC 0x44484F30u /* 'D0HD' */
#define D0_HANDOFF_VERSION 0x00010000u

#define D0_HANDOFF_PA 0x0000000000070000ULL

static EFI_STATUS ReadFileToPool(EFI_HANDLE ImageHandle, CHAR16 *Path, VOID **Buffer, UINTN *Size) {
  EFI_STATUS Status;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Sfsp = NULL;
  EFI_FILE_PROTOCOL *Root = NULL;
  EFI_FILE_PROTOCOL *File = NULL;
  EFI_FILE_INFO *FileInfo = NULL;
  UINTN FileInfoSize = 0;

  *Buffer = NULL;
  *Size = 0;

  Status = gBS->OpenProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid, (VOID **)&LoadedImage, ImageHandle, NULL, EFI_OPEN_PROTOCOL_GET_PROTOCOL);
  if (EFI_ERROR(Status)) return Status;

  Status = gBS->OpenProtocol(LoadedImage->DeviceHandle, &gEfiSimpleFileSystemProtocolGuid, (VOID **)&Sfsp, ImageHandle, NULL, EFI_OPEN_PROTOCOL_GET_PROTOCOL);
  if (EFI_ERROR(Status)) return Status;

  Status = Sfsp->OpenVolume(Sfsp, &Root);
  if (EFI_ERROR(Status)) return Status;

  Status = Root->Open(Root, &File, Path, EFI_FILE_MODE_READ, 0);
  if (EFI_ERROR(Status)) return Status;

  // Query file size
  Status = File->GetInfo(File, &gEfiFileInfoGuid, &FileInfoSize, NULL);
  if (Status != EFI_BUFFER_TOO_SMALL) {
    File->Close(File);
    return Status;
  }
  FileInfo = (EFI_FILE_INFO *)AllocatePool(FileInfoSize);
  if (!FileInfo) {
    File->Close(File);
    return EFI_OUT_OF_RESOURCES;
  }
  Status = File->GetInfo(File, &gEfiFileInfoGuid, &FileInfoSize, FileInfo);
  if (EFI_ERROR(Status)) {
    FreePool(FileInfo);
    File->Close(File);
    return Status;
  }
  UINTN Len = (UINTN)FileInfo->FileSize;
  FreePool(FileInfo);

  VOID *Buf = AllocatePool(Len);
  if (!Buf) {
    File->Close(File);
    return EFI_OUT_OF_RESOURCES;
  }
  UINTN ToRead = Len;
  Status = File->Read(File, &ToRead, Buf);
  File->Close(File);
  if (EFI_ERROR(Status)) {
    FreePool(Buf);
    return Status;
  }
  *Buffer = Buf;
  *Size = ToRead;
  return EFI_SUCCESS;
}

typedef struct __attribute__((packed)) {
  UINT32 magic;
  UINT32 version;
  UINT64 manifest_addr;
  UINT64 manifest_len;
  UINT64 manifest_sig_addr;
  UINT64 manifest_sig_len;
} d0_handoff_t;

EFI_STATUS EFIAPI UefiMain(IN EFI_HANDLE ImageHandle, IN EFI_SYSTEM_TABLE *SystemTable) {
  EFI_STATUS Status;
  VOID *Manifest = NULL;
  UINTN ManifestLen = 0;
  VOID *Sig = NULL;
  UINTN SigLen = 0;

  // Read manifest and signature from the ESP root
  Status = ReadFileToPool(ImageHandle, L"\\manifest.tlv", &Manifest, &ManifestLen);
  if (EFI_ERROR(Status)) return Status;

  Status = ReadFileToPool(ImageHandle, L"\\manifest.sig", &Sig, &SigLen);
  if (EFI_ERROR(Status)) return Status;

  // Allocate pages for manifest and signature and copy
  EFI_PHYSICAL_ADDRESS ManPa = 0;
  EFI_PHYSICAL_ADDRESS SigPa = 0;
  UINTN ManPages = EFI_SIZE_TO_PAGES(ManifestLen);
  UINTN SigPages = EFI_SIZE_TO_PAGES(SigLen);

  Status = gBS->AllocatePages(AllocateAnyPages, EfiLoaderData, ManPages, &ManPa);
  if (EFI_ERROR(Status)) return Status;
  Status = gBS->AllocatePages(AllocateAnyPages, EfiLoaderData, SigPages, &SigPa);
  if (EFI_ERROR(Status)) return Status;

  CopyMem((VOID *)(UINTN)ManPa, Manifest, ManifestLen);
  CopyMem((VOID *)(UINTN)SigPa, Sig, SigLen);

  // Write D0 handoff structure at fixed physical address
  EFI_PHYSICAL_ADDRESS HandoffPa = D0_HANDOFF_PA;
  Status = gBS->AllocatePages(AllocateAddress, EfiLoaderData, 1 /* one 4K page is enough */, &HandoffPa);
  if (EFI_ERROR(Status)) return Status;

  d0_handoff_t *H = (d0_handoff_t *)(UINTN)HandoffPa;
  H->magic = D0_HANDOFF_MAGIC;
  H->version = D0_HANDOFF_VERSION;
  H->manifest_addr = (UINT64)ManPa;
  H->manifest_len = (UINT64)ManifestLen;
  H->manifest_sig_addr = (UINT64)SigPa;
  H->manifest_sig_len = (UINT64)SigLen;

  // Done. A separate loader stage should now load and jump to the kernel.
  return EFI_SUCCESS;
}


