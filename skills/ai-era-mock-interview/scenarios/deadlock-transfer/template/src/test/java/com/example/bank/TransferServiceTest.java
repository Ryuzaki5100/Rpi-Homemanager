package com.example.bank;

import org.junit.jupiter.api.Test;

class TransferServiceTest {

    @Test
    void concurrentOppositeTransfersComplete() {
        Checks.runAll();
    }
}
