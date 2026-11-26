using System;
using Delwaqty.Pos.Core.Protection;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// Reversible protector simulating DPAPI's machine binding in tests:
    /// blobs only unprotect with the same key, so a "copied to another PC"
    /// file (different key) fails to decode like a real DPAPI blob would.
    /// </summary>
    internal sealed class TestProtector : ILocalProtector
    {
        private readonly byte[] _key;

        public TestProtector(byte[] key) { _key = key; }

        public static TestProtector New()
        {
            var key = new byte[32];
            new Random().NextBytes(key);
            return new TestProtector(key);
        }

        public string Name { get { return "test-xor"; } }

        public byte[] Protect(byte[] plain)
        {
            var b = (byte[])plain.Clone();
            for (var i = 0; i < b.Length; i++) b[i] ^= _key[i % _key.Length];
            return b;
        }

        public byte[] Unprotect(byte[] blob)
        {
            // XOR "unprotect" with the wrong key yields garbage UTF-8 that the
            // callers reject; with the right key it roundtrips.
            return Protect(blob);
        }
    }
}
