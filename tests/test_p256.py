import hashlib
import unittest

from python.p256 import (
    G, N, P, deterministic_nonces, jacobian_add, jacobian_double,
    jacobian_to_affine, point_add, point_is_on_curve, public_key, scalar_mult,
    sign_digest, verify_digest,
)


class P256ReferenceTests(unittest.TestCase):
    PRIVATE_KEY = int(
        "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721", 16
    )
    EXPECTED_Q = (
        int("60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6", 16),
        int("7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299", 16),
    )
    EXPECTED_K = int(
        "A6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60", 16
    )
    EXPECTED_SIGNATURE = (
        int("EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716", 16),
        int("F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8", 16),
    )

    def setUp(self):
        self.digest = hashlib.sha256(b"sample").digest()

    def test_curve_parameters_and_group_edges(self):
        self.assertEqual(P.bit_length(), 256)
        self.assertEqual(N.bit_length(), 256)
        self.assertTrue(point_is_on_curve(G))
        self.assertEqual(point_add(G, None), G)
        self.assertIsNone(point_add(G, (G[0], (-G[1]) % P)))
        self.assertIsNone(scalar_mult(N, G))

    def test_jacobian_point_operation_vectors(self):
        p_g = (G[0], G[1], 1)
        p_2g = jacobian_double(p_g)
        self.assertEqual(jacobian_to_affine(p_2g), scalar_mult(2, G))
        self.assertEqual(jacobian_add(p_g, p_g), p_2g)
        p_3g = jacobian_add(p_g, (scalar_mult(2, G)[0], scalar_mult(2, G)[1], 1))
        self.assertEqual(jacobian_to_affine(p_3g), scalar_mult(3, G))
        self.assertIsNone(jacobian_to_affine(jacobian_add(p_g, (G[0], P-G[1], 1))))

    def test_rfc6979_p256_sha256_nonce(self):
        self.assertEqual(
            next(deterministic_nonces(self.PRIVATE_KEY, self.digest)), self.EXPECTED_K
        )

    def test_rfc6979_p256_public_key_and_signature(self):
        self.assertEqual(public_key(self.PRIVATE_KEY), self.EXPECTED_Q)
        signature = sign_digest(self.PRIVATE_KEY, self.digest)
        self.assertEqual(signature, self.EXPECTED_SIGNATURE)
        self.assertTrue(verify_digest(self.EXPECTED_Q, signature, self.digest))

    def test_verifier_rejects_modified_digest_and_invalid_signature(self):
        r, s = self.EXPECTED_SIGNATURE
        modified = self.digest[:-1] + bytes([self.digest[-1] ^ 1])
        self.assertFalse(verify_digest(self.EXPECTED_Q, (r, s), modified))
        self.assertFalse(verify_digest(self.EXPECTED_Q, (0, s), self.digest))
        self.assertFalse(verify_digest(self.EXPECTED_Q, (r, N), self.digest))
        self.assertFalse(verify_digest((0, 0), (r, s), self.digest))

    def test_bad_inputs_are_rejected(self):
        with self.assertRaises(ValueError):
            public_key(0)
        with self.assertRaises(ValueError):
            sign_digest(N, self.digest)
        with self.assertRaises(ValueError):
            sign_digest(1, b"short")


if __name__ == "__main__":
    unittest.main()
