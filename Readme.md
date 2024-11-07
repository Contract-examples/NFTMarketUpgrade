# NFTMarketUpgrade

## Test
```
forge test --match-test=testListWithSignatureV2 -vv
```

## Logs
```
Ran 1 test for test/NFTMarket.t.sol:NFTMarketTest
[PASS] testListWithSignatureV2() (gas: 1764703)
Logs:
  Predicted proxy address: 0x3d01B948928d2F60D40b0B480cB7eb6892Bb47B6
  Deployed proxy address: 0x3d01B948928d2F60D40b0B480cB7eb6892Bb47B6
  Index: 0, Minted NFT with ID: 0
  NFT owner: unlabeled:0x904e4f26a5dA61EE4BC538Fbb5EBa80c3EEe8ea5
  Index: 0, Minted NFT with ID: 1
  NFT owner: seller2
  Index: 0, Minted NFT with ID: 2
  NFT owner: seller3

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.24ms (750.90µs CPU time)

Ran 1 test suite in 8.98ms (3.24ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```
