#ifndef ED25519_H
#define ED25519_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Ed25519 key pair
typedef struct {
    unsigned char secret_key[64];
    unsigned char public_key[32];
} ed25519_keypair;

// Ed25519 signature
typedef struct {
    unsigned char signature[64];
} ed25519_signature;

// Generate a new key pair
void ed25519_create_keypair(unsigned char *public_key, unsigned char *private_key, const unsigned char *seed);

// Sign a message
void ed25519_sign(unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key, const unsigned char *private_key);

// Verify a signature
int ed25519_verify(const unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key);

// Create a key pair from a seed
void ed25519_create_seed_keypair(unsigned char *public_key, unsigned char *private_key, const unsigned char *seed);

#ifdef __cplusplus
}
#endif

#endif // ED25519_H
