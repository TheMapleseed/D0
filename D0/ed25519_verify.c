#include <stddef.h>
#include <stdint.h>

#ifdef HAVE_ORLP_ED25519
#include "third_party/ed25519/ed25519.h"
#endif

// Wrapper with simple prototype for assembly caller
int ed25519_verify_wrapper(const void* msg, size_t msglen,
                           const void* sig, const void* pubkey) {
    if (!msg || !sig || !pubkey || msglen == 0) return 0;
#ifdef HAVE_ORLP_ED25519
    // Call the actual Ed25519 verification function
    return ed25519_verify((const unsigned char*)sig,
                          (const unsigned char*)msg, msglen,
                          (const unsigned char*)pubkey);
#else
    // Placeholder until ed25519 is vendored: reject by default
    return 0;
#endif
}
